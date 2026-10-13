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
#   · 只同步「该给 Agent 看的」内容（**AGENTS.md** + SKILL.md + references/ + scripts/）
#     ★ **AGENTS.md 必须在列**（2026-10-13 补）—— ★ 它的 §1 明写「改源、别改副本」，
#       而那条判据**只有在副本里也有一份时才读得到**（★ 否则自相矛盾）。
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
echo "[0] 同步 AGENTS.md …"
# ★★ 2026-10-13 补：此前**不同步** AGENTS.md —— ★ 而它的 §1 明写
#   「★ 若你手里是**同步副本**，改源、别改副本」⇒ ★ 那条判据**在副本里根本读不到** ⇒ **自相矛盾**。
#   ★ 判据：**纪律文件必须跟着"会用到它的那份拷贝"走** —— ★ 只放在源仓 = 副本场景等于没写。
cp "$SRC/AGENTS.md" "$DEST/AGENTS.md"

echo "[1] 同步 SKILL.md …"
cp "$SRC/SKILL.md" "$DEST/SKILL.md"

echo "[2] 同步 references/ …"
rm -f "$DEST"/references/*.md 2>/dev/null
cp "$SRC"/references/*.md "$DEST/references/" 2>/dev/null

echo "[3] 同步 scripts/ …"
# ★★ 这里踩过一次真实的静默失效（★ 亲手犯的，值得留档）：
#   初版写的是 `cp "$SRC"/scripts/*.sh` ⇒ ★ 新增一个 **.py** 脚本时被静默漏掉，
#   ★ 而末尾的报告照样打印「scripts/ 3 个」⇒ ★ **看起来完全正常**。
#   ⇒ 两处都得改：① 拷**全部**脚本（不限扩展名）；② 计数按**实际落地文件数**报。
#   ★ 元教训：★ 「拷贝用了带白名单的通配符」+「报告只统计成功的那部分」= ★ 假绿配方。
# ★★ 2026-10-13：**同一条教训的第三次**（★ 新增 `scripts/hooks/`（**目录**）时又踩了，
#   ★ 而且这次**两头同时坏**）：
#     · `cp`（不带 `-r`）对目录报错，而 `2>/dev/null` 把它**吞掉**；
#     · 计数 `ls -1 "$SRC"/scripts/*` ⇒ ★ 目录被**展开**、还多算一行表头 ⇒ **数出 8**（实际 5 个文件）
#     ⇒ ★ 报告"数量不一致 ⇒ 同步不完整"，★ **而真正坏的是计数本身**。
#   ⇒ 定稿：**拷与数都改用 `find … -maxdepth 1 -type f`** —— ★ 同源，不再各自漂移。
#   ★ 另：`hooks/` **本就不该同步给 skill**（★ 它是仓的机制，不是"给 Agent 看的内容"）。
#   ★★ 合起来的判据：★ **「拷什么」和「数什么」必须同源** ——
#      ★ 否则它们会各自漂移，然后**互相指责**（这次的"同步不完整"就是这么来的）。
rm -f "$DEST"/scripts/* 2>/dev/null
find "$SRC/scripts" -maxdepth 1 -type f -exec cp {} "$DEST/scripts/" \; 2>/dev/null
chmod +x "$DEST"/scripts/* 2>/dev/null

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
n_src_ref=$(ls -1 "$SRC"/references/*.md 2>/dev/null | wc -l | tr -d ' ')
# ★ 计数与拷贝**同源**（都用 `find … -type f`）—— ★ 见上面第 ③ 条教训
n_script=$(find "$DEST/scripts" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
n_src_script=$(find "$SRC/scripts" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
echo "    AGENTS.md     $(wc -c < "$DEST/AGENTS.md" | tr -d ' ') 字节"
echo "    SKILL.md      $(wc -c < "$DEST/SKILL.md" | tr -d ' ') 字节"
echo "    references/   $n_ref 篇（源 $n_src_ref）"
echo "    scripts/      $n_script 个（源 $n_src_script）"
# ★ 数量对不上 ⇒ ★ 同步不完整 ⇒ ★ 明确报出来，别让「少文件」静默过去
if [ "$n_ref" != "$n_src_ref" ] || [ "$n_script" != "$n_src_script" ]; then
    echo "    ★★ ★ 数量不一致 ⇒ 同步不完整（★ 别当成成功）"
    exit 1
fi
echo
echo "    ★ 提示：★ 下次要改内容，改【源仓库】再跑本脚本 —— 别直接改副本。"
echo "============================================================"
