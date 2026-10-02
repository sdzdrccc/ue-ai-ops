#!/usr/bin/env bash
# ue-editor-info.sh —— 一键收集「UE 编辑器与 MCP 通道」的当前状态
#
# ★ 用途：AI 或人在动手前，先把「事实」查清楚，而不是猜。
#   —— ★ 端口是多少（**从插件日志读，不信文档**）
#   —— ★ 编辑器在不在、内存多少（判断加载完没）
#   —— ★ PID 对不对（防止连到别的服务）
#   —— ★ 热重载模块就绪没
#
# ★ 用法：
#   ./ue-editor-info.sh                 # 自动找工程（当前目录及上溯）
#   ./ue-editor-info.sh /path/to/Project   # 指定工程目录
#
# ★ 通用性：★ 不硬编码任何路径；★ 引擎位置靠「进程路径」反查。
# ★ 平台：Linux / macOS / Windows(Git Bash) 均可；Windows 优先用 PowerShell 版。

set -uo pipefail

# ── 定位工程目录（含 .uproject 的目录）──
find_project() {
    local d="$1"
    [ -d "$d" ] || return 1
    # 先看当前层，再上溯 4 层
    for _ in 1 2 3 4 5; do
        if ls "$d"/*.uproject >/dev/null 2>&1; then echo "$d"; return 0; fi
        d="$(dirname "$d")"
    done
    return 1
}

PROJECT=""
if [ $# -ge 1 ]; then
    PROJECT="$(find_project "$1" || true)"
else
    PROJECT="$(find_project "$(pwd)" || true)"
fi

echo "============================================================"
echo " UE 编辑器 / MCP 通道 状态"
[ -n "$PROJECT" ] && echo " 工程: $PROJECT" || echo " 工程: ★ 未找到 .uproject（请传路径）"
echo "============================================================"

# ── 1. 编辑器进程 ──
echo
echo "[1] 编辑器进程"
if command -v tasklist >/dev/null 2>&1; then
    tasklist 2>/dev/null | grep -i "UnrealEditor\|UE4Editor" | sed 's/^/    /' \
        || echo "    ✗ 编辑器未运行  ⇒ ★ MCP 通道不存在（编辑器内插件无宿主）"
else
    ps aux 2>/dev/null | grep -i "[U]nrealEditor\|[U]E4Editor" | awk '{print "    PID "$2"  MEM "$6"  "$11}' \
        || echo "    ✗ 编辑器未运行  ⇒ ★ MCP 通道不存在"
fi

# ── 2. 引擎位置（从进程反查，不硬编码）──
echo
echo "[2] 引擎位置（从进程路径反查）"
if command -v tasklist >/dev/null 2>&1; then
    tasklist /FI "IMAGENAME eq UnrealEditor.exe" 2>/dev/null | grep -i unreal \
        | sed 's/^/    /' || echo "    （进程不在，改为手动找）"
fi
cat <<'EOF'
    ★ 引擎根 = 含 Engine/Binaries/ 与 Engine/Source/ 的目录
    ★ 手动定位（Windows）:  where UnrealEditor.exe
    ★ 手动定位（macOS）:    mdfind -name UnrealEditor.app | head -1
EOF

# ── 3. ★ 端口：从插件日志读（★ 本节是重点）──
echo
echo "[3] ★ 端口发现（★ 从日志读，不信文档/配置）"
if [ -n "$PROJECT" ]; then
    LOGDIR="$PROJECT/Saved/Logs"
    if [ -d "$LOGDIR" ]; then
        LOG="$(ls -t "$LOGDIR"/*.log 2>/dev/null | head -1)"
        echo "    日志: ${LOG#*/}"
        echo "    ---- 端口相关行 ----"
        grep -iE "assigned unique listener port|listening on port|starting .*server.*port|McpServer.*port" "$LOG" 2>/dev/null \
            | tail -8 | sed 's/^/    /' || echo "    （日志里没有端口行 ⇒ 插件可能没起）"
        echo "    ---- 热重载（Live Coding）状态 ----"
        grep -iE "LogLiveCoding" "$LOG" 2>/dev/null | tail -4 | sed 's/^/    /' \
            || echo "    （无 Live Coding 日志 ⇒ 该构建可能没编入热重载模块）"
        echo "    ---- 插件加载情况 ----"
        grep -iE "ModelContextProtocol|InternalLoadLibrary: '.*[Mm]cp" "$LOG" 2>/dev/null | tail -4 | sed 's/^/    /'
    else
        echo "    ✗ 没有 $LOGDIR ⇒ ★ 编辑器从未在此工程跑过（先启动一次）"
    fi
else
    echo "    跳过（未找到工程目录）"
fi

# ── 4. 监听端口 + PID 核对 ──
echo
echo "[4] 监听中的端口（★ 核对 PID 是否等于编辑器）"
if command -v netstat >/dev/null 2>&1; then
    netstat -ano 2>/dev/null | grep -i LISTENING | sed 's/^/    /' | head -20
    echo "    ★ 把上面的 PID 与 [1] 的编辑器 PID 对照"
    echo "    ★ ★ PID 对不上 ⇒ 你可能连到了别的服务"
elif command -v lsof >/dev/null 2>&1; then
    lsof -i -P -n 2>/dev/null | grep LISTEN | awk '{print "    "$1" "$9}' | head -20
    echo "    ★ 用 lsof 找 UnrealEditor 的监听端口"
else
    echo "    （本机无 netstat / lsof）"
fi

# ── 5. 编译产物时间戳（★ 验证「真的编过了」）──
echo
echo "[5] 编译产物（★ 与源码比时间，确认产物是新的）"
if [ -n "$PROJECT" ]; then
    find "$PROJECT/Binaries" -maxdepth 3 -name "*.dll" -o -maxdepth 3 -name "*.dylib" -o -maxdepth 3 -name "*.so" 2>/dev/null \
        | head -6 | while read -r f; do
        printf "    %s  %s\n" "$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)" "${f#"$PROJECT"/}"
    done
    echo "    ★ 找最新的一个，和对应 .cpp 的修改时间比"
else
    echo "    跳过（未找到工程目录）"
fi

echo
echo "============================================================"
echo " ★ 结论先行的三条："
echo "   1) 编辑器没跑 ⇒ 任何 MCP 调用都不可能成功"
echo "   2) 端口以 ★插件日志★ 为准，文档/配置里的值可能过期"
echo "   3) ★ 改了资产/代码后，看时间戳有没有变 ⇒ 判断有没有真落盘"
echo "============================================================"
