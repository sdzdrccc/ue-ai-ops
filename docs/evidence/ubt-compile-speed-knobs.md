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
| 1 | `MinGameModuleSourceFilesForUnityBuild` 默认 **32** | `Configuration/Rules/TargetRules.cs` · `= 32` | ★ 源码原值 |
| 2 | `bUseUnityBuild` 默认**生效**（Default 环境） | `Configuration/Rules/TargetRules.cs` · `get => bUseUnityBuildOverride ?? IntermediateEnvironment.IsUnity() && !bEnableCppModules`<br>`Configuration/UEBuildTarget.cs` · `static bool IsUnity(this UnrealIntermediateEnvironment)` | ★ 源码逻辑 |
| 3 | `IsUnity()` 只对 **IWYU / GenerateClangDatabase / NonUnity** 返回 false | 同上（`switch` 三 case 后 `return true`） | ★ 源码原值 |
| 4 | `bUseAdaptiveUnityBuild` 默认 **true** | `Configuration/Rules/TargetRules.cs` · `public bool bUseAdaptiveUnityBuild { get; set; } = true;` | ★ 源码原值 |
| 5 | `MinFilesUsingPrecompiledHeader` 默认 **6**（源文件少于 6 个不生成 PCH） | `Configuration/Rules/TargetRules.cs` · `= 6`；消费点 `Configuration/UEBuildModuleCPP.cs` | ★ 源码原值 |
| 6 | `bUseIncrementalLinking` 默认 **false**，官方注释说某些机器有 PDB 相关 bug | `Configuration/Rules/TargetRules.cs` · 属性无初始值 ＋ 注释 `Currently disabled by default because it tends to behave a bit buggy` | ★ 源码原值 |
| 7 | UBA 是**默认执行器**，不是可选项 | `Executors/ExecutorFactory.cs` · `GetExecutor` 末尾 `return GetUBAExecutor(...)`；注释 `We always use the UBA executor` | ★ 源码逻辑 |
| 8 | `-MaxParallelActions` 是官方命令行参数，默认 `0`（自动） | `Configuration/BuildConfiguration.cs` · `[CommandLine("-MaxParallelActions")]` | ★ 源码原值 |

★ **版本**：UE 5.9（`TargetRules.cs` 里 `MinGameModuleSourceFilesForUnityBuild` 仍在 `TargetRules` 上，
★ 而 `IncludeOrderVersion` 已用 `Unreal5_9` 枚举值）。★ **换版本必须重查第 1、2、3、7 条**。

---

## 2. 实测（本机，非源码）

| 观察 | 判据 | 结论 |
|---|---|---|
| 引擎共享 PCH 的缓存文件**单个可达 GB 级** | 在某工程 `Intermediate/Build/<Platform>/.../UnrealEd/` 下 `du` 一份 `SharedPCH.*.h.pch` | ★ 实测一份为 **2.5 GB** ⇒ ★ 删 `Intermediate` 的真实代价是「重编引擎 PCH」，不是「重编自己的模块」 |
| 小模块**不产生** `Unity_*.cpp` | `find Intermediate -name "Unity_*.cpp"` | ★ 与第 1 条（阈值 32）**互相印证** —— 源文件数低于阈值就不合并 |
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

★ **教训**：★ **「引擎默认值」是最容易被记忆腐蚀的一类断言** ——
★ 它不是「通用规律」（那种稳定），而是**版本内的事实**，★ 必须落到源码行。
