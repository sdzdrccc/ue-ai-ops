# 07 · 运行时崩溃的 headless 变异体二分（含 UE Python 取证姿势）

> ★ 场景：`-game` / PIE 启动即崩（如渲染期 AV），静态检查（类型对表 · 结构 dump）已排除嫌疑，
> 需要**零编译**找出「哪个控件/哪段代码」是必要条件。
> ★ 实战案例：渲染期 `AV writing 0x0000000100000009` @ Prepass，7 轮收敛到
> `EditableTextBox` + `SetWidgetStyle` 悬空样式指针（项目侧留有专文档）。

## 1. 核心思路：让「资产变异」当二分探针

C++ 改动要编译（本机 ~6 分钟），**改 WBP 资产只要 40 秒 commandlet** ⇒ 把二分做在资产侧：

```
git checkout 还原 WBP
  → headless commandlet 跑编辑脚本（删/隐藏控件，存盘）
  → timeout 100 <game> 跑 -game 复现
  → exit 3 = 崩（查最新崩溃包 ErrorMessage）· exit 124 = 存活 100s 无崩
  → 记台账，下一轮
```

复现命令（以本项目为准，从 `CrashContext.runtime-xml` 的 `CommandLine>` 里抄，保证同姿势）：

```bash
# ★ exe 用引擎 Binaries/Win64 下的 UnrealEditor-Cmd.exe（怎么查引擎路径 → references/01）
timeout 100 "<引擎Binaries>/UnrealEditor-Cmd.exe" \
  "<proj>.uproject" -game -windowed -ResX=1280 -ResY=720 -nosound
```

### 两种变异的分工（★ 判据设计）

| 变异 | 问的问题 | 结果含义 |
|---|---|---|
| **delete_widget**（删控件） | 这个子树是**必要条件**吗 | 删了不崩 ⇒ 凶手在被删集合里 |
| **set Collapsed**（保控件不渲染） | 凶手是 **C++ 写坏内存** 还是 **渲染路径** | Collapsed 不崩 ⇒ C++ 操作无辜、崩在渲染（`SWidget.cpp` `Prepass_ChildLoop` 对 Collapsed 整支跳过，`CacheDesiredSize` 都不跑） |

★ **多 culprit 陷阱**：两半各删各崩、全删才不崩 ⇒ 不是「某一个」而是「两半各有一个同类」
（当时靠「每半各含一个 EditableTextBox」的共同特征猜中下一轮）。

### 台账纪律

- 每轮 `git checkout -- <wbp>` 还原再变异（**别在上一轮结果上叠**，除非故意做累积实验）
- 认准**原案签名**才算崩（本案 `AV writing 0x0000000100000009`）；
  变异可能引入**新形态噪音** —— 如 `delete_widget` 留蓝图残留 ⇒ 加载重编译刷
  `WidgetBlueprintCompiler.cpp:815` ensure（`SeenVariableNames`）连刷数个崩溃包，**不致命、不是原案**
- 崩溃包时间戳 + `ErrorMessage` 一起看；「存活」的硬证据是**崩溃包零新增**而不是日志最后一行

## 2. headless UE Python 的四个坑（commandlet `-run=pythonscript`）

1. **`sys.stdout` 不落盘**：`print`/自写的 `p()` 看不到 ⇒ 一律 `unreal.log_warning("[标记] ...")`，
   外面 `grep "[标记]"`；**多行字符串只有首行带日志前缀** ⇒ 截段用 `awk '/BEGIN/,/END/'` 打原始日志文件。
2. **`WidgetBlueprint.WidgetTree` 是 protected**：`get_editor_property("WidgetTree")` 直接报错。
   正门：`unreal.get_editor_subsystem(unreal.UmgGetSubsystem).get_widget_tree(bp)` ——
   **传 bp 对象**（传路径报 convert parameter 失败），返回树形文本 `Name [Class]`（不含槽位类）。
   （第三方 UmgMcp 插件的子系统在 commandlet 里可用；其 MCP 桥端口只在编辑器活着时监听。）
3. **`set_widget_properties(bp, name, properties)` 的 properties 是 JSON 字符串**不是 dict：
   `sub.set_widget_properties(bp, "X", '{"Visibility": "Collapsed"}')`。
4. **保存是 `save_asset(bp)`（单数 · 传对象）**，没有 `save_assets(path)`；
   存完**看 mtime** 确认，没动就是没存上（静默失败最坑）。

## 3. 变异脚本模板

项目侧已沉淀：`qiuyuan-dalu/tools/edit-wbp.py`（MODE=delete/collapse + 复核树）、
`tools/dump-wbp-tree.py`（树 dump + 重名检查）。要点：

```python
sub = unreal.get_editor_subsystem(unreal.UmgSetSubsystem)
bp  = unreal.load_object(None, ASSET)          # 资产路径 /Game/...
sub.delete_widget(bp, "TabRow")                # 或 set_widget_properties 塞 JSON
sub.save_asset(bp)                             # ★ 必须真执行，失败要报 ★★★
tree = unreal.get_editor_subsystem(unreal.UmgGetSubsystem).get_widget_tree(bp)  # 复核
```

## 4. 什么时候从「变异体二分」升级到「编译验证」

变异体只能给**必要性**（改它 ⇒ 不崩），不能给机制。机制靠**引擎源码证据链**收口：
本仓案例三环 —— 存裸指针（`SEditableTextBox.h:456`）→ 传调用者引用（`EditableTextBox.cpp:397`）
→ 我方传局部变量 —— 三环对上后，**一次编译验证**（exit 124 + 崩溃包零新增）即可结案。

★ 搜索同类的姿势：拿**精确签名**去搜（`函数名 + 阶段 + 地址形态`，
如 `SEditableTextBox DetermineFont Prepass writing`），命中率远高于泛搜
「UE5 crash AV」——前者一击命中 Epic 论坛逐帧同款栈。
