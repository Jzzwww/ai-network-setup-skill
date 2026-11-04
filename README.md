# ai-network-setup-skill

> 面向使用 AI 工具的开发者：从基础到进阶的**稳定代理与防泄漏**网络配置 SOP，同时是一个 Agent Skill。

## 定位与边界
- ✅ 为 AI 工具提供**稳定、一致**的出口；与公司 VPN / 内网 DNS **兼容共存**；防 DNS/WebRTC/IPv6 泄漏；只读巡检。
- ❌ **不用于**规避服务的地区限制、封禁或 KYC，不提供伪造身份相关内容。
- ⚖️ 请遵守所在地法律法规、公司安全策略以及各服务条款；使用真实身份与支付。

## 内容
```
skills/ai-network-setup/SKILL.md        Agent Skill 入口（渐进式层级）
skills/ai-network-setup/references/     分层文档 00–05 + troubleshooting
scripts/net-check.sh                    只读巡检脚本（macOS）
templates/                              Clash 脚本覆写示例、Shadowrocket 配置、launchd plist
docs/ROADMAP.md                         待补内容
```

## 三种用法
1. **人读**：从 `references/00-overview.md` 开始逐层做，每层跑"验证"。
2. **交给 AI 编程助手**（Codex / Claude Code / Cursor 等）：把仓库放进项目，提示：
   > 阅读 skills/ai-network-setup/SKILL.md，只读检查我这台 Mac 与第 1 层的差异，改动前先问我，不要打印任何凭据，不要重载 Clash。
3. **作为 Agent Skill**：将 `skills/ai-network-setup/` 复制到你的 Agent skills 目录（如 `~/.claude/skills/`），并保留 `scripts/`、`templates/` 的相对位置或修改 SKILL.md 中的路径。

## 快速开始
```bash
git clone <本仓库地址> && cd ai-network-setup-skill
EXPECTED_IP=<你的固定出口IP> BYPASS_DOMAINS="*.<公司域名>" ./scripts/net-check.sh
```

## 安全
所有凭据、订阅 URL 用占位符；请勿在 Issue/PR 中提交真实配置。见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## English summary
A progressive (basic → advanced) SOP and Agent Skill for developers using AI tools who need a **stable, consistent proxy egress and leak prevention** on macOS/iPhone: Clash Verge Rev with a fixed-egress Fallback group, TUN + fake-IP DNS, WebRTC limiting, Shadowrocket, coexistence with corporate VPN/split DNS, provider selection criteria, and a read-only health-check script with launchd scheduling.
**Not** intended for circumventing service region restrictions, bans, or KYC. Follow local laws and each service's Terms of Service. Docs are currently Chinese-only; see `docs/ROADMAP.md`.

License: MIT
