# rime-wubi986

986 五笔 Rime 输入法方案（小狼毫 Weasel / 鼠须管 Squirrel 通用），基于吟枫舞墨 986 五笔 v21.142 码表深度定制。

## 特性

- **四码定长输入**：四码唯一自动上屏，`enable_user_dict: false` 固定词序，符合五笔用户习惯
- **分号快符**：`;` + 字母两键直出常用标点（映射取自虎码官方码表），如 `;a`→！ `;d`→、`;i`→——
- **拆分注解**：候选旁显示 `〔 字根拆分 · 编码 · 拼音 · (频序) 〕` 三重注解，`Ctrl+Shift+H/J/K` 独立开关（需安装「通用字根」字体渲染字根图）
- **双路反查**：`` ` `` 引导，纯笔画键（h横 s竖 p撇 n捺 z折，≥2 笔）自动走笔画反查，其余走拼音反查，正则互斥分流
- **万象快捷输入**（移植自 [amzxyz/rime_wanxiang](https://github.com/amzxyz/rime_wanxiang)，零依赖 Lua）：
  - `/rq` `/sj` `/dt` `/tt` 日期 / 时间 / 日期时间 / 时间戳
  - `/nl` `/xq` `/ww` `/jq` `/jr` 农历 / 星期 / 周数 / 节气 / 节日
  - `/dz1234.56` → 壹仟贰佰叁拾肆元伍角陆分（金额大写）
  - `/rc26p` 日期差等，详见[使用说明](使用说明.md)
- **合并符号表**：预设 symbols ⊕ 万象 1,851 键符号表（含 `/'e`→é `/12`→½ `/->`→→ `/(1)`→① 等 LaTeX 式组合键）
- **生僻字过滤**：`enable_charset_filter` 已启用，`Ctrl+Shift+5` 切换常用/扩展字符集
- **macOS 适配**：附 Squirrel 配置（横排、深浅色自动切换）

## 安装

1. 安装 [小狼毫](https://rime.im/download/)（Windows）或 [鼠须管](https://rime.im/download/)（macOS）
2. 将本仓库全部文件复制到用户目录：
   - Windows：`%APPDATA%\Rime`
   - macOS：`~/Library/Rime`
3. 重新部署（Windows：系统托盘右键 → 重新部署；macOS：菜单栏 → 重新部署）

详细说明（文件清单、快捷键表、字体前提、自定义方法）见 [使用说明.md](使用说明.md)。

## 目录结构

```
├── wubi986.schema.yaml        # 主方案：引擎链、反查分流、符号、Lua 接线
├── wubi986.dict.yaml          # 五笔码表（101,853 条）
├── wubi986.punct.dict.yaml    # 分号快符表
├── wubi986_symbols.yaml       # 合并符号表（脚本生成）
├── wubi986_spelling.*         # 拆分注解伪词典（供 Lua 查询）
├── wubi986_stroke.*           # 笔画反查词典
├── pinyin_simp.*              # 拼音反查依赖
├── lua/                       # Lua 过滤器与翻译器
├── weasel.custom.yaml         # Windows 外观
└── squirrel.custom.yaml       # macOS 外观
```

## 来源与许可

| 内容 | 来源 | 许可 |
|---|---|---|
| 986 五笔码表 v21.142 | 吟枫舞墨（制作）／亮亮亮（Rime 打包） | 随原包分发 |
| 拆分注解伪词典 | 权御五笔（qxwubi986）配套 | 随原包分发 |
| `lua/wanxiang/shijian.lua`<br>`lua/wanxiang/number_conversion.lua` | [amzxyz/rime_wanxiang](https://github.com/amzxyz/rime_wanxiang) | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/deed.zh)（有改动：金额触发引导 R→/dz） |
| `wubi986_stroke.dict.yaml` | [rime/rime-stroke](https://github.com/rime/rime-stroke) | [LGPL-3.0](https://www.gnu.org/licenses/lgpl-3.0.html)（有重命名） |
| 分号快符映射 | 虎码官方码表 | 随原包分发 |
| `weasel.custom.yaml` / `squirrel.custom.yaml`<br>中的五个配色（黑水鸭、碧月青、蓝水鸭、碧皓青、純粹的形式） | [Mintimate/oh-my-rime](https://github.com/Mintimate/oh-my-rime)（薄荷拼音） | [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html)（有适配改动：横排布局、删除 candidate_list_layout、mac 字体栈） |

其余方案配置为本项目整理与修改，按仓库整体以 CC-BY-4.0 提供。
