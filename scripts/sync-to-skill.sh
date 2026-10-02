#!/usr/bin/env bash
# sync-to-skill.sh —— 把本仓库（源）同步到 WorkBuddy skill 目录（安装副本）
#
# ★ 为什么需要它：
#   本仓库 `ue-ai-ops` 是**源**（给人和 git 用），
#   而 WorkBuddy 按**目录名**加载 skill ⇒ 安装副本必须叫 `ue-ai-ops`。
#   ★ 两边一旦不同步，就会出现「改了源但 AI 还是旧知识」这种最难查的问题。
#
# ★ 用法：
#   bash scripts/sync-to-skill.sh              # 同步到默认位置
#   bash scripts/sync-to-skill.sh /path/to/skills/ue-ai-ops   # 指定目标
#
# ★ 设计约束：
#   · 只同步「该给 Agent 看的」内容（SKILL.md + references/ + scripts/）
#   · ★ **不同步** docs/evidence/（那是给人查的证据，塞进 skill 会让上下文臃肿）
#   · 同步前先跑 check.sh（★ 防止把带项目痕迹的内容发出去）

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$HOME/.workbuddy/skills/ue-ai-ops}"

echo "============================================================"
echo " sync: ue-ai-ops  →  skill 目录"
echo "   源:   $SRC"
echo "   目标: $DEST"
echo "============================================================"
echo

# ── 0. 先跑检查（★ 带项目痕迹的内容不该进 skill）──
if [ -f "$SRC/scripts/check.sh" ]; then
    echo "[0] 先跑通用性检查 …"
    if ! bash "$SRC/scripts/check.sh"; then
        echo
        echo "  ✗ 检查未通过 ⇒ ★ 已中止同步（修好再来）"
        exit 1
    fi
    echo
fi

# ── 1. 建目标 ──
mkdir -p "$DEST/references" "$DEST/scripts"

# ── 2. 同步（★ 只同步该给 Agent 的）──
echo "[1] 同步 SKILL.md …"
cp "$SRC/SKILL.md" "$DEST/SKILL.md"

echo "[2] 同步 references/ …"
rm -f "$DEST"/references/*.md 2>/dev/null
cp "$SRC"/references/*.md "$DEST/references/" 2>/dev/null

echo "[3] 同步 scripts/ …"
cp "$SRC"/scripts/*.sh "$DEST/scripts/" 2>/dev/null
chmod +x "$DEST"/scripts/*.sh 2>/dev/null

# ── 3. 记一份来源标记（★ 让「副本从哪来」可查）──
cat > "$DEST/SYNC-ORIGIN.txt" <<EOF
★ 本目录是同步副本，请勿直接编辑 —— 改动会被下次同步覆盖。
★ 源仓库: $SRC
★ 同步时间: $(date '+%Y-%m-%d %H:%M:%S')
★ 同步方式: bash scripts/sync-to-skill.sh
EOF

# ── 4. 报告 ──
echo
echo "[4] 结果"
n_ref=$(ls -1 "$DEST"/references/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "    SKILL.md      $(wc -c < "$DEST/SKILL.md" | tr -d ' ') 字节"
echo "    references/   $n_ref 篇"
echo "    scripts/      $(ls -1 "$DEST"/scripts/*.sh 2>/dev/null | wc -l | tr -d ' ') 个"
echo
echo "    ★ 提示：★ 下次要改内容，改【源仓库】再跑本脚本 —— 别直接改副本。"
echo "============================================================"
