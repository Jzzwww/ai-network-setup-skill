---
name: ai-network-setup
description: >
  Stable proxy and leak prevention for AI tools on macOS (session drops,
  the egress address changing mid-session, DNS or WebRTC leaks, company VPN
  clashes). Triggers: 网络不稳, 出口跳变, 掉线, DNS泄漏, WebRTC泄漏,
  公司VPN冲突, stable proxy, leak check, Clash TUN, fake-ip.
  Do not use on Windows, Linux, or Android, or where the service is not
  officially available.
---

# 稳定代理与防泄漏

只在服务官方支持的地区使用。`scripts/` 和 `templates/` 都相对本文件所在的技能根目录。

## 第 0 步

按 [references/00-diagnose.md](references/00-diagnose.md) 问完 6 个问题。Windows、Linux、Android：说明当前未覆盖并停止。

| 诊断结果 | 打开 |
|---|---|
| Mac，已有订阅，要稳定 | [01-path-mac-clash.md](references/01-path-mac-clash.md) |
| 还要固定出口地址 | 先做完 01，再可选 [02-fixed-exit.md](references/02-fixed-exit.md) |
| iPhone | [03-mobile.md](references/03-mobile.md)。Android 未覆盖 |
| 公司或学校 VPN、内网域名 | [04-company-vpn.md](references/04-company-vpn.md) |
| DNS / WebRTC / IPv6 | [05-leak-checks.md](references/05-leak-checks.md) |
| 定时复查 | [06-monitoring.md](references/06-monitoring.md) |
| 还没有订阅 | [07-buying.md](references/07-buying.md) |
| 已经异常 | [troubleshooting.md](references/troubleshooting.md) |

## Agent 约定

1. **问。** 操作系统、有没有订阅、要不要改 IPv6 / DNS / 系统代理 / 开机任务 / 浏览器插件，不清楚就先问。非 macOS，或服务在当地官方不可用，立即停止。
2. **做。** 默认可跑 `scripts/probe-env.sh` 和 `scripts/net-check.sh`（只读）。备份和改配置是 `[Agent需确认]`。订阅和密码只由用户在客户端界面填写，不要读取 profile 正文。
3. **验。** 以每一层的 pass/fail 为准。未启用固定出口时，出口地址变化不算失败。
4. **退。** 验证失败或用户叫停时，按 [troubleshooting.md](references/troubleshooting.md) 的「紧急全回退」处理。AI 客户端仍连着时不要重载。

`[用户UI]` 用户自己点图形界面。`[Agent只读]` 只查询。`[Agent需确认]` 写入前必须得到明确同意。人人都要遵守的红线在诊断文档里。「不要换出口、客户端开着不要重载」只在固定出口模式生效。
