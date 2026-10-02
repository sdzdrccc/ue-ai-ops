# 证据：编译方式与热重载的实测原始记录

> ★ **本目录（`docs/evidence/`）放「原始证据」，不是手册。**
> ★ **手册在 `references/`** —— ★ 两条内容会重叠，★ 这是**有意的分工**：
>   · `references/` = **怎么做**（结论 + 做法，精炼）
>   · `docs/evidence/` = **当时怎么测的**（原始记录 + 可复跑命令，可追溯）
> ★ **冲突时以 `references/` 为准**（它是提炼后的最新结论）；★ 证据篇保留原始版本以便回溯。

---

> ★ **关于路径**：★ 本文原为**作者本机的原始记录**，其中的盘符路径与人名已做**脱敏**
> （`<EngineRoot>` / `<ProjectRoot>` / `<repo>` 等占位）。
> ★ 指向作者私有仓库的记录编号也已移除 —— ★ **它们对读者是死链接**。
> ★ **脱敏不影响证据价值**：★ 关键在于「怎么发现的」，不在于「在哪个盘」。

---


# UE 编译方式：什么时候能热重载、什么时候必须重启

> ★ **来源**：2026-10-02 **实测**（不是抄文档）—— 启动编辑器 → 试各种改法 → 看引擎日志与编译输出。
> **配套**：`docs/UE-PROJECT-SETUP.md`（怎么启动）· `docs/UE-MCP.md`（编辑器通道）

---

## 0. 一句话

★ **不是「编译就要关编辑器」** —— UE 自带 **Live Coding（热重载）**，**只改 `.cpp` 函数体时可以不关**。
★ **但改反射（`.h` 里的 `UPROPERTY` / `UCLASS` / 枚举）必须重启** —— ★ 那次关编辑器是**对的**，只是我没说清为什么。

---

## 1. ★ 实测记录（本机 UE 5.8 · `<EngineRoot>`）

| 步骤 | 结果 |
|---|---|
| 启动编辑器（带 `-ModelContextProtocolStartServer`） | 日志：`LogLiveCoding: Starting LiveCoding` → `Successfully initialized` ⇒ ★ **热重载本来就可用** |
| 编辑器开着时跑 `Build.bat`（★ **只改了 `.cpp` 一句文案**） | ✗ `Unable to build while Live Coding is active` · `Result: Failed` |
| 查引擎源码确认快捷键 | ★ `Engine/Source/Developer/Windows/LiveCodingServer/Private/External/LC_AppSettings.cpp:264` ★ **`0x37A // Ctrl+Alt+F11`**（引擎硬编码的 `Compile shortcut`） |
| 同一文件还有 | ★ `continuous_compilation_enabled`（**可开自动编译**） |

★ **结论**：★ **命令行 `Build.bat` 与 Live Coding 是两条互斥的路** ——
★ 编辑器一开就走 Live Coding 模式，此时命令行编译必被挡。
⇒ ★ **想在不关编辑器的情况下编译，要用编辑器自己的入口（`Ctrl+Alt+F11`），不是命令行。**

---

## 2. ★★ 什么时候能不关编辑器（Live Coding 能干）

| 改动 | 能否热重载 | 原因 |
|---|---|---|
| ★ **只改 `.cpp` 的函数体**（逻辑、文案、数值） | ✅ **能** | 不涉及反射，编译产物可直接打补丁 |
| ★ 改**私有成员变量**的初始值 | ✅ 能 | 同上 |
| ★ 加一个新的**普通函数** | ⚠️ 大体能 | 不进反射 |

---

## 3. ★★ 什么时候**必须**关编辑器重启

| 改动 | 为什么不行 |
|---|---|
| ★★ **改 `.h` 里的 `UPROPERTY`**（哪怕只是**改名字**） | ★ **反射系统要变** ⇒ **UHT（头文件生成器）必须重跑** ⇒ 新增/删除反射成员无法热重载 |
| ★★ 增删 `UCLASS` / `USTRUCT` / `UENUM` | 同上 |
| ★ 改 `Build.cs`（加模块依赖） | 编译单元变了 ⇒ 整个 DLL 要重编 |
| ★ 加新的 `UPROPERTY` 控件（**改 WBP 绑定那种**） | ★ 同「反射要变」—— ★ **登录屏那次改名 20 处就属这类** |

★ **一句话判据**：
> ★ **动 `.cpp` 函数体 ⇒ Live Coding；动 `.h` 的反射 ⇒ 关编辑器重编。**
> ★ 拿不准就问：「这个改动会不会让 UE 需要重新生成反射信息（`.generated.h`）？」会 ⇒ 重启。

---

## 4. ★ 两种方式的操作规程

### A. 日常小改（只动 `.cpp`）—— 不用关编辑器

```
1) 编辑器开着，改 .cpp
2) 回到编辑器窗口按 Ctrl+Alt+F11（或菜单 Tools → Live Coding → Compile）
3) 等编译完，改动当场生效（不必重启编辑器、不必重开 PIE 之外的任何东西）
```

★ **可选**：开 `continuous_compilation_enabled` ⇒ **存盘即自动编译**。

### B. 改反射（动 `.h`）—— 必须重启

```
1) 停编辑器：taskkill /PID <pid> /F
2) 编译：Build.bat QiuyuanDaluEditor Win64 Development -Project=<uproject> -WaitMutex
3) 重开：UnrealEditor.exe <uproject> -ModelContextProtocolStartServer
   ★ 启动参数 -ModelContextProtocolStartServer 不能省，否则 MCP 通道不起
   ★ 约 150 秒才加载完（着色器）
```

★ **判据**：编译输出出现 `Unable to build while Live Coding is active` ⇒ **编辑器还开着** ⇒ 走 B。

---

## 5. ★★ 三个容易踩的坑

| 坑 | 说明 |
|---|---|
| ★ **以为「编译失败」= 代码写错了** | ★ `Unable to build while Live Coding is active` **不是代码错** ⇒ ★ **一个 `error C` 都没有**。★ 看 `Result:` 那行的措辞区分 |
| ★ 忘了带 `-ModelContextProtocolStartServer` | 编辑器能开，但 **MCP 通道不起** ⇒ 「端口 0/无服务」 |
| ★ **以为改了 `.cpp` 就能命令行编译** | ★ 实测：编辑器开着时**改 `.cpp` 跑 `Build.bat` 一样被挡** ⇒ ★ **要走编辑器内的 `Ctrl+Alt+F11`** |

---

## 6. 出处（可复跑）

```bash
# ① Live Coding 是否已启动
grep "LogLiveCoding" ue-client/Saved/Logs/QiuyuanDalu.log | tail -5

# ② 快捷键的权威出处（引擎硬编码）
grep -n "0x37A" "<EngineRoot>/Engine/Source/Developer/Windows/LiveCodingServer/Private/External/LC_AppSettings.cpp"
#   → 264:  0x37A  // Ctrl+Alt+F11   （标注为 "Compile shortcut"）

# ③ 编辑器开着时命令行编译会被挡（实测报错原文）
#   Unable to build while Live Coding is active. Exit the editor and game,
#   or press Ctrl+Alt+F11 if iterating on code in the editor or game
```

★ 相关记录：`records/（本项目记录）.md` §6（当时只写了「要关编辑器」，★ **没写清 Live Coding 这条路**）
