#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mcp-session-probe.py —— 官方 unreal-mcp 的**分层健康探针**（零依赖 · 标准库）。

★ 为什么需要它（★ 一次真实的排查结论）：
  官方 MCP 通道「AI 侧调不到工具」，绝大多数情况**不是故障**，而是三件事之一：
    ① 它**只暴露 3 个「元工具」**（list_toolsets / describe_toolset / call_tool）
       —— 这是 Tool Search 的设计（几百个工具塞进上下文会炸），不是「工具没加载」。
    ② 有些客户端连接器**在编辑器未启动时初始化并缓存了空工具列表** ⇒ 之后编辑器起来了也不刷新。
    ③ 真的是握手没做完（★ 最隐蔽的一种，见下）。
  ⇒ 前两种可以绕过（自己握手 + 走元工具）；第三种必须先修好。

★★ 本脚本最该记住的一条（★ 实测踩过）：
  > **`initialize` 回 200 不等于握手成功。**
  > ★ `Mcp-Session-Id` 是**会话态**：由 `initialize` 的**响应头**下发，**每个后续请求都要回带**；
  > ★ 漏带 ⇒ 服务端日志打 `Missing required Mcp-Session-Id header` 并回 **400**，
  > ★ 而**此时 `initialize` 本身照样是 200** ⇒ ★ 只看 initialize 的状态码 ⇒ **误判成「通了」**。
  ⇒ 所以判据是**分层**的，★ **判据 = 最后一层真拿到工具列表**，而不是第一层返回 200。

★ 判据分层（★ 每层都有「不该出现什么」⇒ 可证伪）：
    L1 裸探 GET       → 405（端点在应答）；★ 200 反而可疑（streamable HTTP 只收 POST）
    L2 initialize     → 200，★ 且响应头里有 Mcp-Session-Id
    L3 initialized    → 202
    L4 tools/list    → ★★★ 真拿到工具（通常 3 个元工具）★★★
    ★ 只到 L2 就判「通」⇒ 是本脚本要防的那类假绿。

用法：
  python mcp-session-probe.py                      # 探默认端口
  python mcp-session-probe.py --url http://127.0.0.1:12345/mcp
  python mcp-session-probe.py --expect-tools 3     # 工具数不符就非零退出（★ 适合进门禁）

★ 设计约束（★ 本仓纪律）：
  · **零依赖**（只用标准库）—— 换机器不用先装东西。
  · **端口从参数/环境变量来**，不写死在判断逻辑里（★ 端口是环境事实，不是代码事实）。
  · ★ **失败要能指出「下一步该干什么」**，而不只是报错码。
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_URL = os.environ.get("UE_MCP_URL", "http://127.0.0.1:8000/mcp")

# ★ Accept 必须同时给两种：只写 json 会被服务端拒（实测）。
HDR = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}

META_TOOLS = ("list_toolsets", "describe_toolset", "call_tool")


def post(url, body, sid=None, timeout=20):
    h = dict(HDR)
    if sid:
        h["Mcp-Session-Id"] = sid
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers=h, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.headers, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        # ★ 400/405 这类带响应体的也要拿到 —— 服务端的错误信息常是唯一线索。
        return e.code, e.headers, e.read().decode("utf-8", "replace")


def pick_session(headers):
    """★ 大小写不敏感地取 session id（http.client 会合并同名头，这里再兜一层）。"""
    for k, v in headers.items():
        if k.lower() == "mcp-session-id":
            return v
    return None


def probe(url, timeout):
    """返回 (ok, notes, tools)。★ notes 是逐层诊断行，直接可读。"""
    notes = []

    # ── L1 裸探：确认端点在（405 是「端点存在但方法不对」的正常应答）──
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            notes.append("L1 裸探 GET -> %d" % r.status)
    except urllib.error.HTTPError as e:
        notes.append("L1 裸探 GET -> %d（405 = 端点正常）" % e.code)
    except Exception as e:
        notes.append("L1 裸探 GET -> 连不上（%s）" % e)
        notes.append("  ★ 下一步：通道跑在**编辑器进程内** ⇒ 起编辑器并带启动参数"
                     "（如 -ModelContextProtocolStartServer），再重跑本脚本。")
        return False, notes, []

    # ── L2 initialize：★ 回 200 不代表握手成功 ──
    st, hd, _ = post(url, {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "mcp-session-probe", "version": "1.0"},
        },
    }, timeout=timeout)
    notes.append("L2 initialize -> %d" % st)
    if st != 200:
        notes.append("  ★ 下一步：连 400/405 都拿不到 ⇒ 多半是 URL/传输类型配错"
                     "（官方只支持 HTTP/SSE，不支持 stdio）⇒ 查客户端配置。")
        return False, notes, []

    sid = pick_session(hd)
    notes.append("L2 Mcp-Session-Id -> %s" % (sid if sid else "★ 没下发"))
    if not sid:
        notes.append("  ★ 下一步：★ 这就是最容易误判的那一步 —— initialize 回 200 但**没会话头**"
                     "⇒ 后续请求会全被 400 拒（服务端日志写 Missing required Mcp-Session-Id header）。")
        return False, notes, []

    # ── L3 initialized：必须带 sid ──
    st2, _, _ = post(url, {"jsonrpc": "2.0", "method": "notifications/initialized"},
                     sid, timeout=timeout)
    notes.append("L3 initialized -> %d（202 正常）" % st2)

    # ── L4 tools/list：★★ 唯一可作为「通了」的判据 ★★ ──
    st3, _, body = post(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/list",
                             "params": {}}, sid, timeout=timeout)
    if st3 != 200:
        notes.append("L4 tools/list -> %d ★ 握手未生效（400 = 典型「漏带会话头」）" % st3)
        notes.append("  ★ 下一步：核对每个请求都带了 Mcp-Session-Id；服务端日志比客户端报错更有用。")
        return False, notes, []

    try:
        tools = json.loads(body).get("result", {}).get("tools", [])
    except Exception:
        tools = []
    names = [t.get("name", "?") for t in tools]
    notes.append("L4 tools/list -> %d · 工具 %d 个：%s" % (st3, len(tools), names))

    if not tools:
        notes.append("  ★ 下一步：端口在但工具为空 ⇒ 查两件事 —— "
                     "① 工具集插件是否启用（官方默认全禁）；② 控制台 ModelContextProtocol.RefreshTools。")
        return False, notes, []

    if not all(m in names for m in META_TOOLS):
        notes.append("  ★ 注意：没看到全套 %s 元工具 ⇒ 可能 Tool Search 被关"
                     "（会把全部工具直接列出，载荷变大）或版本不同 ⇒ 以运行时为准。"
                     % (list(META_TOOLS),))
    return True, notes, tools


def main():
    ap = argparse.ArgumentParser(description="官方 unreal-mcp 分层健康探针")
    ap.add_argument("--url", default=DEFAULT_URL, help="MCP 端点（默认取环境变量 UE_MCP_URL）")
    ap.add_argument("--timeout", type=int, default=20)
    ap.add_argument("--expect-tools", type=int, default=0,
                    help="期望的工具数；给了就不符就非零退出（适合进门禁）")
    a = ap.parse_args()

    print("=" * 60)
    print(" 官方 unreal-mcp 通道探针")
    print("   端点: %s" % a.url)
    print("=" * 60)

    ok, notes, tools = probe(a.url, a.timeout)
    for n in notes:
        print("  " + n)

    print("-" * 60)
    if not ok:
        print(" 结论: ★ 未通过")
        return 1
    print(" 结论: 通过（判据 = L4 拿到 %d 个工具；★ 不是「initialize 回了 200」）" % len(tools))
    if a.expect_tools and len(tools) != a.expect_tools:
        print(" ★ 工具数与 --expect-tools=%d 不符" % a.expect_tools)
        return 2
    print()
    print(" ★ 下一步怎么调（★ 记住它只暴露 3 个元工具）：")
    print("   1) list_toolsets                → 列出全部工具集（★ 真源，比任何文档准）")
    print("   2) describe_toolset <全限定名>   → 看这个工具集有哪些工具与参数")
    print("   3) call_tool <全限定名> <工具全名> '<json 参数>'")
    print(" ★ 参数名一律 snake_case；工具集/工具都要**全限定名** ⇒ 写错时"
          "服务端会在错误信息里把可用的全名列出来 ⇒ ★ 排查先读错误信息。")
    return 0


if __name__ == "__main__":
    sys.exit(main())