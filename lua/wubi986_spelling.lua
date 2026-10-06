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
      elseif split_on then
        -- 词组：逐字拆分，用「·」连接；任一字无拆分则整个词不注解
        local parts = {}
        for _, cp in utf8.codes(text) do
          local p = get(env, utf8.char(cp))
          if not p or p.split == "" then parts = nil break end
          parts[#parts + 1] = p.split
        end
        if parts then note = "〔 " .. table.concat(parts, "·") .. " 〕" end
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
