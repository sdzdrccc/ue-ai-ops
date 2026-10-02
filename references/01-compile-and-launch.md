# 01 · 启动与编译

> ★ 全部结论来自**实测**（引擎 5.8 · Windows），★ 不是抄文档。
> ★ 凡具体路径都是**实例** ⇒ 换机器请用「怎么找」代替。

---

## 1. 找引擎

| 平台 | 位置 | 怎么确认版本 |
|---|---|---|
| Windows | `<安装根>/Engine/Binaries/Win64/UnrealEditor.exe` | 文件属性 / 启动后看标题栏 |
| macOS | `<安装根>/Engine/Binaries/Mac/UnrealEditor.app` | 同上 |

★ **认准「引擎根」的特征**：下面有 `Engine/Binaries/` 与 `Engine/Source/`。

★ **有没有 Launcher 是两回事**：
| 情况 | 表现 | 怎么办 |
|---|---|---|
| ★ **有 Launcher** | 能在界面里选工程 | 照常用 |
| ★ **只有引擎二进制**（无 Launcher / 无版本选择器） | ★ 双击 exe 会开★ **项目浏览器**，进不了工程 | ★ **必须命令行直启**（见下） |

★ **判别法**：★★ **双击 exe 后如果出现「选择工程」的窗口，说明没有 Launcher** ⇒ 以后都用命令行。

---

## 2. 启动

```bash
# ★ 通用形式（无 Launcher 时唯一可靠的路）
"<EngineRoot>/Engine/Binaries/Win64/UnrealEditor.exe" "<Project>/<Project>.uproject"
```

### 2.1 ★ 启动参数

| 参数 | 作用 |
|---|---|
| `-ModelContextProtocolStartServer` | ★ **让编辑器内的 MCP 服务自启**（见 `02-editor-mcp-channel.md`）· ★ **不带的代价见该篇** |

★ **其它可能有用的**（按需查引擎文档）：
| 参数 | 用途 |
|---|---|
| `-game` | 直接进游戏模式（跳过编辑器界面） |
| `-nullrhi` | 不渲染（省资源，用于纯逻辑跑测） |
| `-log` | 打开日志窗口 |
| `-nosplash` | 跳过启动画面 |

### 2.2 ★ 启动要等多久 / 怎么知道加载完了

| 阶段 | 现象 |
|---|---|
| 0–30 秒 | 进程起来，内存小 |
| ★ 30–180 秒 | ★ **内存持续上涨**（★ 着色器编译占大头）· ★ **这是正常的，别以为卡死** |
| 加载完 | 内存稳定在 GB 级 · 窗口可交互 |

★ **判据**：★ **看内存是否稳定**（Windows：`tasklist | findstr UnrealEditor` 看内存列）。

★ **首次启动某工程会更久**（要编译该工程的着色器），第二次起就快。

---

## 3. ★ 编译：三条路，先选对再动手

### 3.1 决策表

| 改动 | 走哪条路 |
|---|---|
| ★ **只改 `.cpp` 函数体** | ★ **热重载**（§3.2）—— 不关编辑器 |
| ★★ **改 `.h` 的反射**（`UPROPERTY` / `UCLASS` / `USTRUCT` / `UENUM`，★ **哪怕只改名**） | ★ **命令行全量编译**（§3.3）—— **必须关编辑器** |
| 改 `Build.cs` | 同上 |
| 改引擎源码 | 同上（且耗时显著变长） |

★ **一句话判据**：★ **这改动会不会让引擎需要重新生成反射信息（`.generated.h`）？会 ⇒ 全量编译。**

### 3.2 热重载（Live Coding）

| 项 | 值 |
|---|---|
| 快捷键 | ★ **`Ctrl+Alt+F11`**（★ 引擎硬编码的 "Compile shortcut"） |
| 出处（可自查） | `<Engine>/Source/Developer/Windows/LiveCodingServer/Private/External/LC_AppSettings.cpp` ★ 搜 `0x37A`（★ 0x37A = Ctrl+Alt+F11） |
| 自动编译开关 | ★ 同文件有 `continuous_compilation_enabled` |
| 启动日志 | ★ `Saved/Logs/<Project>.log` 里搜 `LogLiveCoding` ⇒ 出现 `Successfully initialized` 说明**已就绪** |

★ **怎么用**
```
1) 编辑器开着，改 .cpp
2) 焦点回到编辑器窗口 → Ctrl+Alt+F11
3) 看编辑器输出/右下角的编译状态
```

★ **它做不到的**：★ **任何让反射系统变化的改动** —— ★ 表现为「热重载报错 / 提示需要重启 / 改完不生效」。

### 3.3 命令行全量编译

```bash
# Windows
"<EngineRoot>/Engine/Build/BatchFiles/Build.bat" <TargetName> <Platform> <Config> -Project="<Project>/<Project>.uproject" -WaitMutex
```

| 参数位 | 常见值（★ 以你的 `.Target.cs` 为准） |
|---|---|
| TargetName | ★ 通常是 `<ProjectName>Editor`（编辑器目标）或 `<ProjectName>`（游戏目标） |
| Platform | ★ `Win64` / `Linux` / `Mac` |
| Config | ★ `Development` / `Debug` / `Shipping`（★ **`DebugGame` 也常见**） |

★ **常见坑**：
| 现象 | 原因 | 正解 |
|---|---|---|
| ★ 报 `Unable to build while Live Coding is active` | ★ **编辑器还开着** | ★ **关掉编辑器**（★ 消息里那句 "or press Ctrl+Alt+F11" 就是另一条路） |
| ★ 一个 `error C` 都没有但 `Result: Failed` | ★ **不是代码错** | ★ **看 `Result:` 那行措辞** |
| 输出被吞 / 看不到报错 | 管道用法问题 | ★ **重定向到文件再看**：`... > build.log 2>&1` |

★ **怎么找你的 TargetName**：
```bash
ls <Project>/Source/*.Target.cs
# 文件名去掉 .Target.cs 就是 TargetName（Editor / Game / Server 等变体）
```

### 3.4 ★★ 怎么确认「真的编过了」

★ **别只看「没报错」** —— 要看两样：
```bash
# ① 结果行
grep "Result:" build.log
#   期望：Result: Succeeded

# ② 产物时间戳比源码新（判据：比 .cpp 的修改时间新）
ls -la <Project>/Binaries/<Platform>/<Project>.dll
ls -la <Project>/Source/<Module>/<File>.cpp
```

★ **为什么**：★ **「命令跑了」≠「编过了」** —— ★ 内存/并发不足时可能中途失败而退出码仍是 0。

---

## 4. 完整流程（★ 改反射时的标准动作）

```
1) 停编辑器
2) 编译：Build.bat ... > build.log 2>&1
3) 验：grep "Result:" build.log   ⇒ 必须 Succeeded
4) 重开：UnrealEditor.exe <uproject> -ModelContextProtocolStartServer
5) 等加载完（看内存稳定）
```

★ **第 3 步不要省** —— ★ 省了就会在「跑起来才发现是旧 dll」上浪费更多时间。

---

## 5. ★ 本文件的实测记录（★ 结论从哪来）

> ★ 这一节是**证据**，不是手册 —— ★ 它的作用是让上面每条结论**可追溯、可复跑**。

★ **实测环境**：UE 5.8 · Windows · 编辑器与工程见 `<工程>/<工程>.uproject`

### 5.1 实测发现（原样记录）

| 步骤 | 结果 |
|---|---|
| 启动编辑器后查日志 | ★ `LogLiveCoding: Starting LiveCoding` → `Successfully initialized` ⇒ ★ **热重载本来就可用** |
| ★ 编辑器开着时跑命令行编译（★ 只改 `.cpp` 一句文案） | ✗ `Unable to build while Live Coding is active` · `Result: Failed` |
| 查引擎源码找快捷键 | ★ 硬编码按键码 `0x37A` = **Ctrl+Alt+F11**（文件内注释标为 "Compile shortcut"） |
| 同一处还有 | ★ `continuous_compilation_enabled`（★ 可开「存盘即自动编译」） |

★★ **关键认识**：★ **命令行编译与热重载是两条互斥的路** ——
编辑器一开就进热重载模式，此时命令行编译**必被挡**
⇒ ★ **想不关编辑器，要用编辑器内的快捷键，不是命令行。**

### 5.2 可复跑的验证命令

```bash
# ① 看热重载是否已就绪
grep "LogLiveCoding" <Project>/Saved/Logs/<Project>.log | tail -5

# ② 找快捷键的权威出处（★ 引擎源码里硬编码）
grep -n "0x37A" <Engine>/Source/Developer/Windows/LiveCodingServer/Private/External/LC_AppSettings.cpp

# ③ 若编译器报「被 Live Coding 占用」⇒ ★ 说明编辑器还开着（★ 这不是代码错）
```

### 5.3 ★ 本文件与「工程实测」的分工

★ 本文件是**手册**（怎么做）；★ 若要看**逐条证据与源码行号**，见仓库的 `docs/evidence/` 目录。

---
