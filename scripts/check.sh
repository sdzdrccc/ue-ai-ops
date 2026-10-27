#!/usr/bin/env bash
# check.sh —— 本仓库的两条门禁
#
# ★★ 判据（★ 都带反向用例的思路）：
#   ① **通用性**：不许出现具体项目痕迹（盘符路径 / 项目名 / 具体端口 / 记录卡号）
#       ★ 为什么：本仓库要能「换项目/换机器照样成立」⇒ 写「怎么查」而不是「查到的值」
#   ② **结构**：关键文件在不在 · Markdown 表格列数对不对
#
# ★ 用法：bash scripts/check.sh
#
# ★★ 设计说明（★ 一条实测教训）：
#   本脚本的判据① 必须**真的能拦** —— ★ 它的反向用例是「往文件里塞一个盘符路径，
#   检查器应报错」。★ 若你改了判据，务必重跑一次反向用例（见文件末尾注释）。

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

echo "============================================================"
echo " ue-ai-ops 自检"
echo "   根: $ROOT"
echo "============================================================"
echo

# ── 判据① 通用性：不含具体项目痕迹 ──
# ★★ 扫描范围沿革（★ 一次自己造出来的漏洞）：
#   初版只扫 `SKILL.md` 与 `references/` —— ★ **结果 `docs/evidence/` 里的
#   本机路径与私有仓卡号全漏了**（那些是「从项目直接拷来的」）。
#   ⇒ ★ 修正为**扫全仓**（排除 `scripts/`：★ 检查器自身必然含判据的模式串）。
#
# ★★ 教训：★ **「检查范围」本身也是判据的一部分** ——
#   ★ 一个只覆盖一半文件的检查器，会让人误以为「全仓已检查」。
echo "[1] 通用性（★ 全仓扫描 · 排除 scripts/ 自身）"

# ★ 通用扫描函数：用法 scan_all "<模式>" "<标签>"
scan_all() {
    local pat="$1" label="$2" found=0
    while IFS= read -r f; do
        # ★ 排除：.git · scripts/（检查器自身）· 本脚本
        case "$f" in
            */.git/*|*/scripts/*) continue ;;
        esac
        if grep -qE "$pat" "$f" 2>/dev/null; then
            if [ "$found" -eq 0 ]; then
                echo "    ✗ 发现$label:"
                found=1
            fi
            # ★ 不截断：`head -3` 会让同一文件里的第 4 条起**静默消失**
            #   （2026-10-27 自测实测：项目名判据明明命中，却被前三条挤掉了）
            grep -nE "$pat" "$f" 2>/dev/null | sed "s|^|        ${f#$ROOT/}:|" | cut -c1-120
        fi
    done < <(find "$ROOT" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.txt' -o -name 'LICENSE' \) 2>/dev/null)
    [ "$found" -eq 1 ] && FAILED=1
    [ "$found" -eq 0 ] && echo "    ✓ 无$label"
}

# ★ 盘符路径：★ 正则要排除 URL（`http://` 里的 `p:/` 会被误判 —— 已踩过）
scan_all "[A-Za-z]:[\\/][^/\\ ]" "盘符路径"

# ★ 记录卡号：指向私有仓，对读者是死链接
# ★ 2026-10-27 补 `A**`：坑号也是项目侧编号（实测 `A59` 曾漏在模式外被放行）
scan_all "\b[T-X]-00[0-9]{2}\b|ADR-00[0-9]{2}|\bA[0-9]{2}\b" "记录卡号"

# ★ 项目名痕迹（2026-10-27 补 · 上游 `X-0053` U-1.2）：通用仓不许出现具体项目名
scan_all "\b(qiuyuan|Qiuyuan|dalu|Dalu|ue-client)\b" "项目名痕迹"

# ★ 本机特有端口（★ 8000 不算 —— 它是官方默认值，属通用）
scan_all "\b(64892|50664|3306|6379)\b" "本机特有端口"

# ★ 本机用户名 / 仓库主名
scan_all "Administrator" "本机用户名"
echo

# ── 判据② 结构：关键文件在不在 ──
echo "[2] 结构"
for f in SKILL.md README.md INSTALL.md references/01-compile-and-launch.md \
         references/04-avoiding-pitfalls.md references/05-official-mcp-and-toolsets.md \
         references/07-crash-bisection-headless.md \
         scripts/find-ue-editor-info.sh scripts/sync-to-skill.sh \
         scripts/mcp-session-probe.py; do
    if [ -f "$ROOT/$f" ]; then
        echo "    ✓ $f"
    else
        echo "    ✗ $f  ★ 缺失"
        FAILED=1
    fi
done
echo

# ── 判据② ·2：Markdown 表格列数 ──
# ★★ 2026-10-13 改（★ 本脚本自身的一处"假绿"）：
#   原实现是「**有 node 且存在 `scripts/check-md-tables.js` 就跑，否则打印"跳过"**」——
#   ★★ 而那个 `.js` **从来不存在** ⇒ ★ 这条判据**永远在"跳过"**。
#   ★ 判据：**★ "跳过"长得像绿灯** —— ★ 一个永远跳过的判据，比没有判据更坏
#     （★ 它让人以为"表格有人管"）。
#   ⇒ 处置：**用 awk 内联实现**（★ 顺带去掉了 node 依赖 —— 本仓其余检查都是 shell）。
#   ★ 口径：**同一张表里每一行的 `|` 个数必须相同**（表头 / 分隔行 / 数据行一起比）。
#     形如 `| a | b |` 与 `|---|---|` 与 `|:--|--:|` 的 `|` 数**都是 3** ⇒ 天然可比。
echo "[3] Markdown 表格列数"
tbl_bad=0
while IFS= read -r f; do
    # ★★ 两个坑（★ 都是**写完当场踩出来的**，都进了 `--selftest`）：
    #   ① 单元格内容里的**转义竖线 `\|`** 不算列分隔符 —— ★ 不先去掉会**误报**
    #      （★ 实测：本仓 `references/02` 与 `05` 各有一处这么写）。
    #   ② 「首尾都有 `|`」才算表格行 —— ★ 非表格行要**结束当前表**，否则跨表串号。
    bad=$(awk '
        {
            t = $0
            gsub(/\\\|/, "", t)                    # ① 去掉转义竖线
            if (t ~ /^\|.*\|[[:space:]]*$/) {      # ② 表格行
                n = split(t, a, "|") - 2
                if (!inblk) { hdr = n; inblk = 1; next }
                if (n != hdr) print NR ": 列数 " n " != 表头 " hdr
                next
            }
            inblk = 0
        }
    ' "$f" 2>/dev/null)
    if [ -n "$bad" ]; then
        echo "    ✗ ${f#$ROOT/}:"
        echo "$bad" | head -3 | sed 's/^/        /'
        tbl_bad=1
        FAILED=1
    fi
done < <(find "$ROOT" -type f -name '*.md' -not -path '*/.git/*' 2>/dev/null)
[ "$tbl_bad" -eq 0 ] && echo "    ✓ 表格列数一致"
echo

# ── 判据③：断言来源标注（★ 软提示，不失败）──
echo "[4] ★ 提示：带「阈值/机制/必然」字样的地方，应标来源"
# ★ 只找「断言语气最强」的少数词（★ 原用「必然|一定|总是」，噪音太大 ⇒ 收窄）
UNSOURCED=$(grep -rnE "必然会|一定不会|永远不会|必定" "$ROOT"/references/ 2>/dev/null | head -5)
if [ -n "$UNSOURCED" ]; then
    echo "    · 下列句子用了绝对化措辞 —— ★ 建议在旁边标「来源 + 是否核实」:"
    echo "$UNSOURCED" | sed 's/^/        /' | cut -c1-110
else
    echo "    ✓ 未发现明显绝对化措辞"
fi
echo

# ── 结果 ──
echo "============================================================"
if [ "$FAILED" -eq 0 ]; then
    echo "   结果: 全绿"
else
    echo "   结果: ★ 有检查未通过"
fi
echo "============================================================"
echo
if [ "${1:-}" = "--selftest" ]; then
    echo "★★ 反向用例自测（★ 改判据后必跑）"
    echo "   ★ 目的：证明本检查器**真的能拦**，而不是「永远报绿」。"
    echo
    echo "   ★ 沿革（★ 自测本身也出过两次 bug，值得记）:"
    echo "       · 初版用 \`bash \"\$0\"\` 递归调用 ⇒ ★ 路径不稳，测不出结果"
    echo "       · 初版测试用例写 \`T-9999\` ⇒ ★ 而判据要求 \`T-00xx\` ⇒ **根本没测到**"
    echo "     ⇒ ★ **测试用例必须符合判据的真实形状**，否则「测了等于没测」。"
    echo

    # ★ 用例放在 docs/evidence/ —— ★ 这正是初版漏扫的目录，用它才能测出范围问题
    TMP="$ROOT/docs/evidence/_selftest.tmp.md"
    # ★ 用例必须**符合判据的真实形状**：T-00xx（不是 T-9999）
    printf '# selftest\n\nF:/some/fake/path\nT-0099\nA59\nqiuyuan-dalu\n' > "$TMP"

    OUT_A="$(bash "$ROOT/scripts/check.sh" 2>&1 || true)"

    echo "   [A] 塞入盘符路径 ⇒ 判据① 应报错"
    if echo "$OUT_A" | grep -q "✗ 发现盘符路径"; then
        echo "       ✓ 已拦（符合预期）"
    else
        echo "       ✗ ★ 未拦 ⇒ 判据① 已失效！"
        FAILED=1
    fi

    echo "   [B] 塞入记录卡号 T-0099 ⇒ 判据① 应报错"
    if echo "$OUT_A" | grep -q "✗ 发现记录卡号"; then
        echo "       ✓ 已拦（符合预期）"
    else
        echo "       ✗ ★ 未拦 ⇒ 卡号判据已失效！"
        FAILED=1
    fi

    echo "   [B2] 塞入坑号 A59 ⇒ 判据① 应报错"
    if echo "$OUT_A" | grep -q "✗ 发现记录卡号"; then
        echo "       ✓ 已拦（符合预期）"
    else
        echo "       ✗ ★ 未拦 ⇒ 坑号（A**）仍在模式外！"
        FAILED=1
    fi

    echo "   [B3] 塞入项目名 qiuyuan-dalu ⇒ 判据① 应报错"
    if echo "$OUT_A" | grep -q "✗ 发现项目名痕迹"; then
        echo "       ✓ 已拦（符合预期）"
    else
        echo "       ✗ ★ 未拦 ⇒ 项目名判据已失效！"
        FAILED=1
    fi

    rm -f "$TMP"
    echo
    echo "   [C] 移除后应恢复全绿"
    OUT_B="$(bash "$ROOT/scripts/check.sh" 2>&1 || true)"
    if echo "$OUT_B" | grep -q "全绿"; then
        echo "       ✓ 已恢复（符合预期）"
    else
        echo "       ✗ ★ 未恢复"
        FAILED=1
    fi
    echo

    # ── 判据③（表格列数）的两条用例 —— ★★ 一正一反，缺一不可 ──
    # ★ 为什么必须两条：★ 只测"坏表被拦" ⇒ 若判据把**所有表**都判坏，照样全过；
    #   ★ 只测"好表通过" ⇒ 若判据**永远报绿**，也照样全过。
    #   ⇒ ★ 两条一起，才证明它**分得清好坏**。
    TBL="$ROOT/docs/evidence/_selftest.tbl.md"

    # [D] 坏表：表头 2 列、数据行 3 列 ⇒ ★ 必报
    printf '| A | B |\n|---|---|\n| 1 | 2 | 3 |\n' > "$TBL"
    OUT_D="$(bash "$ROOT/scripts/check.sh" 2>&1 || true)"
    echo "   [D] 塞入列数不一致的表 ⇒ 判据③ 应报错"
    if echo "$OUT_D" | grep -q "列数 3 != 表头 2"; then
        echo "       ✓ 已拦（符合预期）"
    else
        echo "       ✗ ★ 未拦 ⇒ 表格判据已失效！"
        FAILED=1
    fi

    # [E] ★★ 好表：单元格里有**转义竖线 `\|`** ⇒ ★ **不得误报**
    #   ★ 这条是**写完判据当场踩出来的坑**：`\|` 是表格里写竖线的规范写法，
    #     而初版 awk 把它当成了列分隔符 ⇒ ★ 把本仓两张**好表**误判成坏表。
    printf '| A | B |\n|---|---|\n| `a \\| b` | ok |\n' > "$TBL"
    OUT_E="$(bash "$ROOT/scripts/check.sh" 2>&1 || true)"
    echo "   [E] 塞入**带转义竖线**的好表 ⇒ ★ **不得误报**"
    if echo "$OUT_E" | grep -q "表格列数一致"; then
        echo "       ✓ 未误报（符合预期）"
    else
        echo "       ✗ ★ 误报了 ⇒ 判据把「转义竖线」当成了列分隔符！"
        FAILED=1
    fi

    rm -f "$TBL"
    echo

    if [ "$FAILED" -eq 0 ]; then
        echo "   ★ 结论：七条反向用例全过 ⇒ ★ **判据真的在干活**"
    else
        echo "   ★ 结论：★ **有反向用例未过 ⇒ 先修检查器，别信它的绿灯**"
    fi
    exit "$FAILED"
fi

echo "★ 想验证「本检查器真能拦」⇒ 跑：bash scripts/check.sh --selftest"
exit "$FAILED"
