#!/bin/sh
#
# install-hooks.sh —— 启用本仓的 Git 钩子
# ========================================
#
# 把 `core.hooksPath` 指向仓内的 `scripts/hooks/`，让 pre-push 门禁生效
# （推送前自动跑 `bash scripts/check.sh`）。
#
# 为什么用 core.hooksPath 而不是往 `.git/hooks/` 拷文件：
#   —— `.git/` 不进版本库，钩子会被 clone 丢掉；`scripts/hooks/` 是受版本管理的。
#   —— ★ 与 `gbe-studio` / `gbe-assets` 用**同一套机制**（它们的 pre-push 校版本号）。
#
# ★ 来源：2026-10-13 —— 本仓门禁 `check.sh` 此前**只在手动跑时**才生效；
#   ★ 判据：**只在"有人记得手动跑"时才存在的门禁，等于没有门禁。**
#
# 用法：bash scripts/install-hooks.sh
# 撤销：git config --unset core.hooksPath
# 放行一次：UE_AIOPS_SKIP_CHECK=1 git push

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="scripts/hooks"

if [ ! -f "$ROOT/$HOOKS_DIR/pre-push" ]; then
    echo "✗ 找不到 $HOOKS_DIR/pre-push —— 本脚本需在仓库根目录下运行" >&2
    exit 1
fi

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "✗ 当前目录不是 git 仓库" >&2
    exit 1
fi

git -C "$ROOT" config core.hooksPath "$HOOKS_DIR"
chmod +x "$ROOT/$HOOKS_DIR/pre-push" 2>/dev/null

echo "✓ core.hooksPath = $HOOKS_DIR"
echo "  pre-push 门禁已生效（每次推送会先跑 scripts/check.sh）"
echo ""
echo "  撤销：git config --unset core.hooksPath"
echo "  放行一次：UE_AIOPS_SKIP_CHECK=1 git push"
