-- wubi986_spelling.lua — 三重注解过滤器（拆分字根 + 全码 + 拼音）
-- 依赖：wubi986_spelling 伪词典（schema/dependencies 触发编译反向库）
-- 开关：show_spelling（显拆/隐拆）show_code（显编/隐编）show_pinyin（显音/隐音）
-- 接线：engine/filters 下挂 lua_filter@*wubi986_spelling（模块模式）
-- 兼容：librime-lua（Weasel 0.15+ 内置），标准 Weasel 与 RimeUI 通用
-- 性能：查表结果按字缓存（memo），三开关全关时直通零查询

local M = {}

-- 解析注解串，兼容两种数据格式：
--   [字集,拆分,编码,拼音,(频序)]   （GB2312 字，含拼音列）
--   [字集,拆分,编码,(频序)]        （GBK 生僻字，无拼音列）
-- 畸形多字段行（如「筕」拆分,码,码,拼音）取末字段为拼音（含非 a-z 字符者）
-- 返回 { split=, code=, pinyin=, freq= } 或 nil
local function parse(s)
  local body = s:match("^%[(.*)%]$")
  if not body then return nil end
  local freq = body:match("%(([0-9]+)%)$") or ""
  body = body:gsub(",?%([0-9]+%)$", "")       -- 去尾部频序
  local f = {}
  for field in body:gmatch("[^,]+") do
    f[#f + 1] = field
  end
  -- f[1]=字集 f[2]=拆分 f[3]=编码 f[4+]=拼音（可能缺省）
  if #f < 3 then return nil end
  local pinyin = ""
  if #f >= 4 then
    local last = f[#f]
    if not last:match("^[a-z]+$") then pinyin = last end
  end
  return { split = f[2] or "", code = f[3] or "", pinyin = pinyin, freq = freq }
end

-- 带缓存的查表：命中缓存零 lookup/正则开销；缓存键集有界（≤2.7 万字）
local function get(env, ch)
  local c = env.cache[ch]
  if c == nil then
    local ok, s = pcall(function() return env.rv:lookup(ch) end)
    c = (ok and s and s ~= "") and parse(s) or false
    env.cache[ch] = c
  end
  return c or nil
end

-- 词组每位置取根数（模块级常量，避免每候选重建小表产生 GC 压力）
local TAKE2, TAKE3, TAKE4 = {2, 2}, {1, 1, 2}, {1, 1, 1, 1}

function M.init(env)
  local ok, result = pcall(function()
    return ReverseLookup("wubi986_spelling")
  end)
  env.rv = ok and result or nil
  env.cache = {}
  if not env.rv then
    pcall(function()
      log.warning("wubi986_spelling: 反向库未编译，注解过滤器退化为直通")
    end)
  end
end

function M.func(input, env)
  local ctx = env.engine.context
  local split_on = ctx:get_option("show_spelling")
  local code_on = ctx:get_option("show_code")
  local pinyin_on = ctx:get_option("show_pinyin")
  local active = split_on or code_on or pinyin_on   -- 全关 fast path：零查询直通
  local rv = env.rv
  for cand in input:iter() do
    local note = ""
    local text = cand.text
    local n = rv and active and utf8.len(text) or nil
    if n and n >= 1 and n <= 10 then
      if n == 1 then
        -- 单字：三重注解（按开关拼装），格式 〔 拆分 · 码 · 拼音 · (频序) 〕
        local p = get(env, text)
        if p then
          local seg = {}
          if split_on and p.split ~= "" then seg[#seg + 1] = p.split end
          if code_on and p.code ~= "" then seg[#seg + 1] = p.code end
          if pinyin_on and p.pinyin ~= "" then
            seg[#seg + 1] = p.pinyin:gsub("_", "/")
          end
          if #seg > 0 then
            if p.freq ~= "" then seg[#seg + 1] = "(" .. p.freq .. ")" end
            note = "〔 " .. table.concat(seg, " · ") .. " 〕"
          end
        end
      elseif split_on or code_on then
        -- 词组：按 986 打词规则取参与组词的字根/键位（实证 64,755 词组 100% 命中）
        -- 规则：2字=各字前2；3字=首1+次1+末字前2；4字=各字第1；5字以上=前三字第1+末字第1
        -- 拆分截取对应字根数，编码截取对应键位数，各凑四格显示
        -- 注：「不」(ill)「有」(ell) 等成字根的组词取码已内嵌于伪词典 code 列，无需特判
        local rs, cs, ok = {}, {}, true
        for _, cp in utf8.codes(text) do
          local p = get(env, utf8.char(cp))
          if not p then ok = false break end
          if split_on then
            if p.split == "" then ok = false break end
            rs[#rs + 1] = p.split
          end
          if code_on then
            if p.code == "" then ok = false break end
            cs[#cs + 1] = p.code
          end
        end
        if ok then
          local seg = {}
          if split_on and #rs >= 2 then
            local m = #rs
            -- 每字取根数：与打词规则键位数一一对应
            -- 2字词 {2,2}；3字词 {1,1,2}；4字词 {1,1,1,1}；5字以上前三字各1+末字1
            local take
            if m == 2 then
              take = TAKE2
            elseif m == 3 then
              take = TAKE3
            else
              take = TAKE4   -- 4 字及以上
            end
            local parts = {}
            local npos = m > 4 and 4 or m   -- 参与取码的位置数（3字词仅3位，防 rs[4]=nil）
            for i = 1, npos do
              local pick = rs[i]
              if m > 4 and i == 4 then pick = rs[m] end   -- 5 字以上末位取末字
              -- UTF-8 感知截取前 take[i] 个字根（字根为多字节 PUA 字符，不能用字节 sub）
              local cnt = 0
              local buf = {}
              for _, cpc in utf8.codes(pick) do
                cnt = cnt + 1
                if cnt > take[i] then break end
                buf[#buf + 1] = utf8.char(cpc)
              end
              parts[#parts + 1] = table.concat(buf)
            end
            seg[#seg + 1] = table.concat(parts, "·")
          end
          if code_on and #cs >= 2 then
            local m = #cs
            local wc
            if m == 2 then
              wc = cs[1]:sub(1, 2) .. cs[2]:sub(1, 2)
            elseif m == 3 then
              wc = cs[1]:sub(1, 1) .. cs[2]:sub(1, 1) .. cs[3]:sub(1, 2)
            elseif m == 4 then
              wc = cs[1]:sub(1, 1) .. cs[2]:sub(1, 1) .. cs[3]:sub(1, 1) .. cs[4]:sub(1, 1)
            else
              wc = cs[1]:sub(1, 1) .. cs[2]:sub(1, 1) .. cs[3]:sub(1, 1) .. cs[m]:sub(1, 1)
            end
            seg[#seg + 1] = wc
          end
          if #seg > 0 then note = "〔 " .. table.concat(seg, " · ") .. " 〕" end
        end
      end
    end
    if note ~= "" then
      yield(Candidate(cand.type, cand.start, cand._end, text, note))
    else
      yield(cand)
    end
  end
end

return M
