---
name: ai-network-setup
description: Use when setting up, replicating, or auditing a stable proxy and leak-prevention network environment on macOS/iPhone for developers using AI tools — Clash Verge Rev fixed-egress Fallback group, TUN/fake-ip DNS, WebRTC limiter, Shadowrocket, company VPN/split-DNS coexistence, proxy service selection, and scheduled read-only checks.
---

# AI 开发者网络配置（渐进式）

定位：稳定、一致的出口 + 公司网络兼容 + 隐私防泄漏。**不用于**规避服务地区限制、封禁或 KYC；遵守当地法律与服务条款。

## 执行原则（Agent 必读）
1. 默认**只读**：先跑检查、报告差异，改动前征得用户同意。
2. AI 客户端运行时**不热重载/不退出** Clash。
3. 改前备份：`cp FILE FILE.bak-<用途>-$(date +%Y%m%d%H%M%S)`；改后确认运行时 == 磁盘。
4. **永不打印**凭据、订阅 URL；订阅 profile 文件不 `cat`。
5. 不禁用、不绕过公司安全组件（DNS 安全扩展、VPN、MDM）。

## 层级（按顺序，每层：目标 / 前置条件 / 步骤 / 验证 / 常见坑 / 回滚）
| 层 | 内容 | 文档 |
|---|---|---|
| 0 | 红线、拓扑 | [references/00-overview.md](references/00-overview.md) |
| 1 | Clash Verge：Service 模式、脚本覆写、AI-ISP Fallback、TUN gVisor、fake-ip、系统代理 bypass | [references/01-basic-clash.md](references/01-basic-clash.md) |
| 2 | WebRTC Network Limiter、Shadowrocket | [references/02-tools-browser-shadowrocket.md](references/02-tools-browser-shadowrocket.md) |
| 3 | 公司 VPN 共存、Split DNS、Tailscale、dns-guard、IPv6、bypass 字段坑 | [references/03-advanced.md](references/03-advanced.md) |
| 4 | 服务选购（机场 / 静态 ISP / VPS） | [references/04-service-selection.md](references/04-service-selection.md) |
| 5 | 巡检脚本与定时 | [references/05-scheduled-checks.md](references/05-scheduled-checks.md) |
| — | 故障速查、新设备/同事 checklist | [references/troubleshooting.md](references/troubleshooting.md) |

## 快速流程
1. 读第 0 层；向用户确认占位符：`<你的固定出口IP>`、`<公司域名>`、订阅与代理账号（用户自己在 UI 填写）。
2. 按第 1 层配置，模板 `../../templates/clash-verge-script-override.example.js`。
3. 运行 `EXPECTED_IP=<你的固定出口IP> ../../scripts/net-check.sh`（退出码 0 OK / 1 WARN / 2 FAIL）。
4. 全 OK 后按需做 2–5 层；手机用 `../../templates/shadowrocket.conf`，定时用 `../../templates/com.example.net-check.plist`。
