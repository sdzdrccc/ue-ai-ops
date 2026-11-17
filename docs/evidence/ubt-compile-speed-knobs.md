# UBT 编译速度相关默认值 —— 源码出处

> ★ **这份是什么**：`references/01-compile-and-launch.md` §3·5「编得慢怎么办」里**每一条默认值断言的出处**。
> ★ **为什么单独存**：★ 那些默认值**凭记忆全错**（见下方「纠错记录」），
> ★ 不记来源就会在下一次「凭印象改规则」时被推翻。
> ★ **怎么复核**：★ 下表每条都给了 `<Engine>/Engine/Source/Programs/UnrealBuildTool/` 下的相对路径与行号，
> ★ 换引擎版本后**行号会漂**，★ 用「文件名 + 符号名」grep，别信行号。

---

## 1. 断言与出处

| # | 断言 | 出处（相对 `UnrealBuildTool/`） | 形式 |
|---|---|---|---|
| 1 | `MinGameModuleSourceFilesForUnityBuild` 默认 **32**（★ **少于**该数 ⇒ **强行关** Unity） | `Configuration/Rules/TargetRules.cs` · `= 32` ＋ 注释 `The number of source files … before unity build will be activated`；消费点 `Configuration/UEBuildModuleCPP.cs` · `else if (FileCount < MinSourceFilesForUnityBuild) { bModuleUsesUnityBuild = false; }` | ★ 源码原值 + 逻辑 |
| 1b | ★★ **计数口径 = 你写的 cpp ＋ UHT 生成的 `.gen.cpp`**（`bMergeUnityFiles` 时） | `Configuration/UEBuildModuleCPP.cs` · `int FileCount = CPPFiles.Count; if (bMergeUnityFiles) { FileCount += GeneratedFileItems.Count; }` | ★ 源码逻辑 |
| 1c | ★★ **Unity 合并单元的文件名是 `Module.<ModuleName>.cpp`**，★ **不叫** `Unity_*.cpp` | 实测产物：`Intermediate/Build/<Platform>/<Arch>/<Target>/Development/<Module>/Module.<Module>.cpp` | ★ 实测（见 §2） |
| 2 | `bUseUnityBuild` 默认**生效**（Default 环境） | `Configuration/Rules/TargetRules.cs` · `get => bUseUnityBuildOverride ?? IntermediateEnvironment.IsUnity() && !bEnableCppModules`<br>`Configuration/UEBuildTarget.cs` · `static bool IsUnity(this UnrealIntermediateEnvironment)` | ★ 源码逻辑 |
| 3 | `IsUnity()` 只对 **IWYU / GenerateClangDatabase / NonUnity** 返回 false | 同上（`switch` 三 case 后 `return true`） | ★ 源码原值 |
| 4 | `bUseAdaptiveUnityBuild` 默认 **true** | `Configuration/Rules/TargetRules.cs` · `public bool bUseAdaptiveUnityBuild { get; set; } = true;` | ★ 源码原值 |
| 5 | `MinFilesUsingPrecompiledHeader` 默认 **6**（源文件少于 6 个不生成 PCH） | `Configuration/Rules/TargetRules.cs` · `= 6`；消费点 `Configuration/UEBuildModuleCPP.cs` | ★ 源码原值 |
| 6 | `bUseIncrementalLinking` 默认 **false**，官方注释说某些机器有 PDB 相关 bug | `Configuration/Rules/TargetRules.cs` · 属性无初始值 ＋ 注释 `Currently disabled by default because it tends to behave a bit buggy` | ★ 源码原值 |
| 7 | UBA 是**默认执行器**，不是可选项 | `Executors/ExecutorFactory.cs` · `GetExecutor` 末尾 `return GetUBAExecutor(...)`；注释 `We always use the UBA executor` | ★ 源码逻辑 |
| 8 | `-MaxParallelActions` 是官方命令行参数，默认 `0`（自动） | `Configuration/BuildConfiguration.cs` · `[CommandLine("-MaxParallelActions")]` | ★ 源码原值 |
| 9 | ★★ **默认 `0` = 按「核数 ＋ 可用内存」自动算**，手设会覆盖它 | `Configuration/BuildConfiguration.cs` 注释 `If 0 then code will pick a default based on the number of cores and memory available`；`Executors/UnrealBuildAccelerator/UBAExecutor.cs` · `GetDefaultNumParallelProcesses` → `Utils.GetMaxActionsToExecuteInParallel(..., bAllCores, MemoryPerActionBytes)` | ★ 源码逻辑 |
| 10 | `bAllCores` 默认 **false** ⇒ 默认**只按物理核**，不算超线程 | `Configuration/BuildConfiguration.cs` · `public bool bAllCores { get; set; } = false;` | ★ 源码原值 |
| 11 | ★ `-NoUBA` **只禁 UBA 的 detour（劫持）**，执行器仍是 `Unreal Build Accelerator local executor` | 实测日志：每个动作后标 `[NoUba]`，而抬头仍打 `Using Unreal Build Accelerator local executor to run N action(s)` | ★ 实测 |

★ **版本**：UE 5.9（`TargetRules.cs` 里 `MinGameModuleSourceFilesForUnityBuild` 仍在 `TargetRules` 上，
★ 而 `IncludeOrderVersion` 已用 `Unreal5_9` 枚举值）。★ **换版本必须重查第 1、2、3、7 条**。

---

## 2. 实测（本机，非源码）

| 观察 | 判据 | 结论 |
|---|---|---|
| 引擎共享 PCH 的缓存文件**单个可达 GB 级** | 在某工程 `Intermediate/Build/<Platform>/.../UnrealEd/` 下 `du` 一份 `SharedPCH.*.h.pch` | ★ 实测一份为 **2.5 GB** ⇒ ★ 删 `Intermediate` 的真实代价是「重编引擎 PCH」，不是「重编自己的模块」 |
| ★★ 小模块**也可能启用** Unity —— 合并单元叫 `Module.<模块名>.cpp` | `find Intermediate -path "*<Module>/Module.*.cpp"`；或看日志有没有 `Excluded from <Module> unity file` | ★ 实测：**21 个自写 cpp ＋ 20 个 `.gen.cpp` ≈ 41** ⇒ 已过阈值 32 ⇒ 启用。★ **拿 `Unity_*.cpp` 去找是找不到的**（UE5 换了命名），★ 据此判「没启用 Unity」是**误判**（本次就误判过一轮） |
| ★★ **UBA detour 会卡死**：动作数已列出，之后日志再无输出 | 日志出现 `Using Unreal Build Accelerator local executor to run N action(s)` 后**十分钟无新行**，且产物时间戳不动 | ★ 实测**两次**（一次 17 分钟、一次 4 分钟零进展）⇒ 加 `-NoUBA` 后 **2 分 9 秒**编完、`Result: Succeeded` |
| `.old` 文件是 UBT 覆盖前留的备份 | `find . -name "*.old"` | ★ 可删、会自动再生成；★ 不是「垃圾堆积」，是**每次覆盖都会产生一份**，所以数量会随编译次数涨 |

★ **怎么复跑**：「改一个头 → 数日志里 `Compile` 的行数」是**唯一能量出「牵连几个编译单元」**的办法，
★ 比体感「全量重编」可靠。

---

## 3. ★ 纠错记录（★ 为什么这份文件必须存在）

★ 在写 §3·5 之前，有**两条**默认值被凭记忆写反：

| 曾以为 | 实际 | 后果（若写进手册） |
|---|---|---|
| `bUseIncrementalLinking` 默认开、别关它 | ★ **默认就是关的**，官方说它有 bug | ★ 会让人去手动开启，★ 撞上 PDB 报错 |
| `bUseUnityBuild` 在 5.9 改成了默认关 | ★ 仍默认生效（表达式换了写法，`IsUnity()` 对 Default 返回 true） | ★ 会让人白关一遍、且大模块关它反而更慢 |
| ★ 「手动设 `-MaxParallelActions` 比默认快，按物理核拍个数」 | ★ **默认 `0` 已按「核数 ＋ 可用内存」自动算**；`bAllCores` 默认 false ⇒ 只算物理核 | ★ **手设 = 覆盖**，可能比默认更差 —— ★ 会让人做一次**负收益**的「优化」 |
| ★ 「`find Intermediate -name "Unity_*.cpp"` 是空的 ⇒ 本模块没启用 Unity」 | ★★ **本模块启用着**，只是 UE5 把合并单元叫 `Module.<模块名>.cpp` | ★★ 整个分析框架会错位：★ 会以为「改头牵连 N 个编译单元」，实际是「**1 个合并单元整体重编**」（★ 本次就错了这一轮） |
| ★ 「21 个 cpp < 阈值 32 ⇒ 不该启用 Unity」 | ★ 计数口径是 **cpp ＋ 生成的 `.gen.cpp`**，20 个 UCLASS 就贡献 20 | ★ 同一条推理，★ 两个错叠在一起 ⇒ ★ 结论完全反 |

★ **教训**：★ **「引擎默认值」是最容易被记忆腐蚀的一类断言** ——
★ 它不是「通用规律」（那种稳定），而是**版本内的事实**，★ 必须落到源码行。
