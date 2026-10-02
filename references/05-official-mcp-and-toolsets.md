# 05 · UE 官方 MCP 与工具集（★ 优先用官方）

> ★ **本文的定位**：★ **官方已经提供了完整的「AI 操控 UE」能力**，
> ★ 本文讲★ **怎么开、怎么发现、怎么用、有什么限制**。
> ★ **凡本文与其它来源冲突，以本文（官方文档 + 本机实测）为准。**

---

## 1. ★★ 先建立正确认知：官方**已经做完了**

★ 很多人（包括 AI）会以为「要让 AI 操控 UE 得自己写插件」—— ★ **不用，官方有一整套**。

| 组件 | 作用 | 规模（实测） |
|---|---|---|
| ★ **Unreal MCP**（插件标识符 `ModelContextProtocol`） | ★ MCP 服务端（协议层） | 105 文件 · 13k 行 |
| ★ **Toolset Registry** | ★ 工具集注册中心（★ 含 `AICallable`/`AIIgnore` 标记协议） | 145 文件 · 20k 行 |
| ★ **All Toolsets** | ★ **一键启用全部工具集的聚合插件** | 依赖 20+ 工具集 |
| ★ **27 个工具集插件** | ★ 具体能力（UMG / GAS / Niagara / PCG / Sequencer / 编辑器 / 自动化测试…） | 258 文件 · 43k 行 |
| ★ **AIAssistant** | ★ AI 助手本体 | 102 文件 · 16k 行 |
| ★ **合计** | —— | ★ **610 文件 · 92k 行** |

★★ **结论**：★ **自己另写一套工具集，不但重复，而且追不上官方迭代**。
★ **唯一值得投入的是「怎么用」这一层**（启用 + 发现 + 避坑）。

---

## 2. ★★ 启用（★ 官方默认一个都不开）

★ **这是最大的门槛** —— ★ **27 个工具集插件全部 `EnabledByDefault=false`** ⇒
★ **装完引擎，一个都没开** ⇒ ★ **这就是「官方有 9 万行、却容易被漏掉」的根因。**

### 2.1 两种启用方式

| 方式 | 做法 | 取舍 |
|---|---|---|
| ★ **一键全开（推荐起步）** | 启用 **`AllToolsets`** 聚合插件 | ★ 省事；★ 但会拉起 20+ 个依赖 ⇒ 首次编译变慢 |
| ★ **按需单开** | 只启用你要的那几个（如 `UMGToolSet`、`EditorToolset`） | ★ 启动快；★ 但要知道自己要什么 |

★ **`ToolsetRegistry` 会被自动带起来**（它是依赖）。

### 2.2 三种启用途径

| 途径 | 做法 |
|---|---|
| ★ **编辑器界面** | Edit → Plugins → 勾选 → 按提示**重启编辑器** |
| ★ **改 `.uproject`**（可提交、可复现 · 推荐） | 在 `Plugins` 数组里加 `{"Name":"AllToolsets","Enabled":true}` |
| ★ 命令行 | `-EnablePlugins=AllToolsets`（临时试的时候用） |

★ **推荐 `.uproject`** —— ★ **它能进版本库，别人 clone 下来就是对的**。

### 2.3 启用后必做

| # | 动作 | 说明 |
|---|---|---|
| 1 | ★ **重启编辑器** | ★ 插件加载只在启动时发生 |
| 2 | ★ **开 Auto Start Server** | Edit → Editor Preferences → General → **Model Context Protocol** → ★ **Auto Start Server** |
| 3 | ★ 或每次启动带参数 | ★ `-ModelContextProtocolStartServer`（★ **无视设置，强制启动**） |
| 4 | ★ **刷新工具**（改了工具集之后） | 控制台：`ModelContextProtocol.RefreshTools` |

★ **第 2 与第 3 二选一** —— ★ **推荐第 3**（命令行参数不受「设置有没有读到」影响）。

---

## 3. ★★ MCP 服务端：端口 · 传输 · 客户端配置

### 3.1 默认参数（★ 官方文档明确）

| 项 | 默认值 |
|---|---|
| ★ 地址 | ★ **`http://127.0.0.1:8000/mcp`** |
| ★ 端口 | ★ **8000**（可用 `-ModelContextProtocolPort=N` 覆盖） |
| ★ URL 路径 | ★ **`/mcp`** |
| ★ `serverInfo.name` | ★ **`unreal-mcp`** |
| ★ 绑定范围 | ★ **仅本机回环（loopback）** |
| ★ 传输 | ★ **仅 HTTP / SSE** ⇒ ★ **不支持 `stdio`、不支持 WebSocket** |

★ **最后一条最容易踩**：★ **很多 MCP 客户端默认用 `stdio`** ⇒
★ **配不上的第一嫌疑就是「客户端在用 stdio 连一个 HTTP 服务」**。

### 3.2 ★★ 让编辑器自己生成客户端配置（★ 最省事）

★ **方式**：在编辑器控制台运行
```
ModelContextProtocol.GenerateClientConfig All
```
| 参数 | 说明 |
|---|---|
| `ClaudeCode` / `Cursor` / `VSCode` / `Gemini` / `Codex` | 生成对应客户端的配置 |
| ★ `All` | ★ 一次全生成 |

★ **它会把配置文件写到项目根目录**（如 `.mcp.json`），★ **指向正在运行的服务端**。

★ **生成的 JSON**（★ 原文形状）：
```json
{
  "mcpServers": {
    "unreal-mcp": {
      "type": "http",
      "url": "http://127.0.0.1:8000/mcp"
    }
  }
}
```

★ **注意**：
- ★ **JSON 类客户端（Claude Code / Cursor / VS Code / Gemini）会与已有条目「合并」** ⇒ 重复运行安全
- ★ **Codex CLI 用 TOML，且是一次性写入** ⇒ ★ **拒绝覆盖已存在文件，过期配置要手动删**
- ★ 未包含 Claude Desktop（★ 那类客户端要按它自己的文档配）

### 3.3 ★ 手动配置（任何 MCP 客户端通用）

★ 核心就三件事：

| 项 | 值 |
|---|---|
| 类型 | ★ **HTTP**（不是 stdio） |
| URL | ★ `http://127.0.0.1:8000/mcp` |
| 名字 | 任意（常见 `unreal-mcp`） |

★ **命令行客户端示例**（WorkBuddy / 其它支持 `mcp.json` 的）：
```json
{
  "mcpServers": {
    "unreal-mcp": { "type": "http", "url": "http://127.0.0.1:8000/mcp" }
  }
}
```

### 3.4 ★★ 从「哪个目录」启动客户端很重要

★ 官方明确：★ **要从「生成配置文件的那个项目/工作区根目录」启动 AI 客户端**，
★ 否则**客户端找不到配置**。

★ **排错顺序**：★ **先起编辑器（确保 MCP 已起）→ 再在正确目录起客户端**。

---

## 4. ★★ 工具怎么「发现」——Tool Search 机制

### 4.1 ★ 默认不是「一次列出所有工具」

★ 默认开启 **Tool Search**（`bEnableToolSearch = true`）⇒ ★ **`tools/list` 只返回 3 个「发现型元工具」**：

| 元工具 | 作用 |
|---|---|
| ★ `list_toolsets` | ★ **列出所有可用工具集**（名字 + 描述） |
| ★ `describe_toolset` | ★ **取某个工具集下所有工具的 schema** |
| ★ `call_tool` | ★ **用给定参数调用某个具名工具**（★ 同回合返回结果） |

★ **为什么要这样**：★ **注册表可能有数百个工具** ⇒ 一次全广告会让 schema 载荷爆炸。

★ **如果你想要「全部工具一次列出」**：★ 把 Tool Search 关掉 ⇒
★ **代价是初始 schema 载荷大幅变大**。

★★ **重要提示**：★ **工具作者不应假设「工具会被主动列出」** ——
★ **通过 Tool Search 路径发现，才是 agent 默认看到的形态。**

### 4.2 ★ 所以正确的用法是

```
1) list_toolsets                → 看有哪些工具集（★ 真源，不是文档）
2) describe_toolset <名字>       → 看这个工具集有哪些工具、参数是什么
3) call_tool <名字> <参数>       → 调用
```

★★ **这套路径本身就是「源码即文档」的运行时版本** ——
★ **比任何静态文档都准**（★ 因为它读的是当前真实注册表）。

---

## 5. ★ 内置工具集（开箱即用的那批）

★ 官方文档点名的（★ **多为 Python 编写**）：

| 工具集 | 大致能力 |
|---|---|
| ★ `SceneTools` | 场景/关卡层面的操作 |
| ★ `ActorTools` | Actor 的增删改查 |
| ★ `MaterialInstanceTools` | 材质实例 |
| ★ `ObjectTools` | 通用对象操作 |

★ **C++ 写的官方示例**：★ `GASToolsets` 插件里的 `AttributeSetToolset`
（★ **该插件默认禁用** ⇒ ★ 要用得手动开）。

★ **看源码的真实位置**（★ 路径会随版本变，★ 用「找」而不是背）：
```bash
# Python 工具集
find <Engine>/Plugins/Experimental/ToolsetRegistry/Content -name "*.py" | head
# C++ 工具集
ls <Engine>/Plugins/Experimental/Toolsets/
```

★ **注意**：★ **自定义工具集的完整实现**（★ 想自己加工具时看）参考官方那两个：
★ Python 路径下的内置工具集 · C++ 的 `UAttributeSetToolset`。

---

## 6. ★★ 限制与坑（★ 官方明确的 + 实测的）

### 6.1 官方明确的限制

| 限制 | 影响 |
|---|---|
| ★ **Experimental** | ★ **功能不完整、API 随时可能变** ⇒ ★ **别当稳定接口依赖** |
| ★ 仅 UE 5.8 | ★ 其它版本不一定有这套 |
| ★ **仅 HTTP / SSE** | ★ **不支持 stdio / WebSocket** ⇒ ★ 客户端配错类型就连不上 |
| ★ **仅本机回环** | ★ 默认不允许外部机器连 |
| ★★ **无鉴权** | ★★ **绝对不能暴露到公网** —— ★ 它能让调用方**任意操作你的编辑器** |
| ★ **Resources / Prompts 未实现** | ★ 随附工具集**没有广告**这两类 ⇒ 别指望 |
| ★ Toolset Registry 适配器**仅编辑器** | ★ **打包后的构建里，这些工具不会自动发现**（须显式注册） |

### 6.2 ★★ 今天踩过/复核过的坑

| 坑 | 真相 | 怎么避 |
|---|---|---|
| ★★ **「两个插件名字像但不是同一个」** | ★ **官方 `unreal-mcp`（HTTP 8000）** 与**第三方插件（可能是原生 socket + 随机端口）** 是**两条独立通道** | ★ **看清 `serverInfo.name` / 端口** —— ★ 连不上时先确认「我连的是哪个」 |
| ★★ **新增 `UFUNCTION` 光靠热重载不行** | ★ **Live Coding 只传播「已有函数体的改动」，不传播新的 `UFUNCTION` 声明** | ★ **新增工具必须重启编辑器** |
| ★ 改了工具集不生效 | 注册表需要刷新 | ★ 控制台 `ModelContextProtocol.RefreshTools` |
| ★★ **不应发起重叠调用** | ★ 服务端把请求**串行地在游戏线程上执行** | ★ **客户端要串行调**，别并发 |
| ★ **端口 8000 可能与其它服务撞** | ★ 8000 是常见端口 | ★ 用 `-ModelContextProtocolPort=N` 改；★ **或让别的服务让路** |

### 6.3 ★ 一条容易被忽略的工程影响

★ **编辑器进程内跑服务** ⇒ ★ **关编辑器 = 服务停** ⇒
★ **所有「AI 自动化」的脚本/CI 都要考虑：编辑器必须是活的。**
★ 而官方又说明★ **打包构建里可以托管服务**（需自己调 `StartServer`）—— ★
★ **但工具集在那种环境不会自动发现** ⇒ ★ **别指望「打包版跑同一套工具」**。

---

## 7. ★ 控制台命令 / 命令行参数速查

### 7.1 控制台命令

| 命令 | 作用 |
|---|---|
| ★ `ModelContextProtocol.StartServer [port]` | ★ 启动（可指定端口） |
| ★ `ModelContextProtocol.StopServer` | ★ 停止并关闭所有会话 |
| ★ `ModelContextProtocol.RefreshTools` | ★ 重新轮询已注册的工具提供方 |
| ★ `ModelContextProtocol.GenerateClientConfig <客户端\|All>` | ★ 生成客户端配置到项目根目录 |

### 7.2 命令行标志

| 标志 | 作用 |
|---|---|
| ★ `-ModelContextProtocolStartServer` | ★ **启动时启动服务，无视设置** |
| ★ `-ModelContextProtocolPort=N` | ★ 覆盖端口（无效时回退到设置值） |
| ★ `-EnablePlugins=<名字>` | ★ 临时启用插件（试的时候用） |

### 7.3 可调设置（Editor Preferences → General → Model Context Protocol）

| 属性 | 默认 | 说明 |
|---|---|---|
| ★ Auto Start Server | `false` | ★ 编辑器启动时自动起服务 |
| ★ Server Port Number | `8000` | ★ 监听端口 |
| ★ Server URL Path | `/mcp` | ★ URL 路径 |
| ★ Enable Tool Search | `true` | ★ 只返回 3 个元工具（见 §4） |

### 7.4 几个有用的控制台变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `ModelContextProtocol.WrapPODToolResultsInObject` | `true` | ★ 把结果包成 `{"result": …}` —— ★ **某些客户端要求对象形状** |
| `ModelContextProtocol.PaginationPageSize` | `0` | ★ 分页大小，`0` = 不分页 |
| `ModelContextProtocol.ProgressIntervalSeconds` | `1.0` | 进度通知最小间隔 |
| `ModelContextProtocol.AudioResultOggFormat` | `false` | 音频结果用 OGG 还是 WAV |

---

## 8. ★★ 与第三方插件怎么选（★ 优先官方）

> ★ **结论：优先用官方。** ★ 除非官方确实没有你要的能力。

| 维度 | ★ 官方 | 第三方 |
|---|---|---|
| 覆盖域 | ★ **27 个工具集**（UMG/GAS/Niagara/PCG/…） | 通常只覆盖一两个域 |
| 维护 | ★ **Epic** | 个人/小团队 |
| 随引擎升级 | ★ **会跟着演进** | ★ 可能停更 |
| 缺点 | ★ **Experimental**（API 可能变）· 默认不启用 | ★ 可能更贴合特定需求 |
| ★ 授权 | ★ **随引擎（EULA）** | ★ **可能是「无许可证」⇒ 不能改后再分发** |

★ **实操建议**：
1. ★ **先 `list_toolsets` 看官方有没有覆盖**
2. ★ **有 ⇒ 用官方**
3. ★ **没有 ⇒ 再考虑第三方，或自己按官方示例加一个工具集**
4. ★ **别同时上两套做同一件事** —— ★ 两套通道并存会让「连不上」的排查成本翻倍

★ **若确实要并存**：★ **在文档里明确写「两条通道 + 各自端口 + 各自职责」**，
★ 否则下一个人（或下一个 AI 会话）会把它当成一个东西。

---

## 9. 出处

- ★ **官方文档**：`https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor`
  （★ **重要**：★ **官方文档在文档站，★ 不随引擎目录分发** ⇒ ★ **别因为引擎目录里没有 .md 就断定「官方没文档」**）
- ★ **运行时真源**：`list_toolsets` / `describe_toolset`（★ **永远比静态文档准**）
- ★ **源码位置**：`<Engine>/Plugins/Experimental/{ModelContextProtocol,ToolsetRegistry,AIAssistant,Toolsets}`
- ★ **本机实测**：见 `06-sampling-test-report.md`

★ **版本提示**：★ 本文基于 **UE 5.8** 的实测与官方文档。
★ 该套件**明确标注 Experimental** ⇒ ★ **换版本请以「运行时真源」为准**。
