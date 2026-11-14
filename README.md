# ai-network-setup-skill

给使用 AI 工具的人准备的稳定代理和防泄漏做法：连接尽量少中断，DNS 和 WebRTC 少把本机地址送出去，并能和公司或学校的 VPN 放在一起。

只在服务官方支持的地区使用。

## 适用

| 适用 | 不适用 |
|---|---|
| macOS，已经有订阅，希望出口稳定、少泄漏 | Windows、Linux、Android（当前未覆盖） |
| 可选：iPhone 上的 Shadowrocket | 你所在地区该服务官方不提供 |
| 可选：和公司 VPN 共存 | 必须关掉单位安全组件才能用的环境 |

默认只用你已经有的订阅。固定出口是可选进阶，不是入门条件。

## 三种用法

1. **自己做。** 打开 [SKILL.md](skills/ai-network-setup/SKILL.md)，从第 0 步的 6 个问题进入对应文档。
2. **交给代理。** 让它阅读 `skills/ai-network-setup/SKILL.md`。它应先问再改，默认可只跑只读探测。
3. **只安装技能目录。** 复制或链接 `skills/ai-network-setup/` 到 `~/.claude/skills/ai-network-setup/`（其它工具以各自文档为准）。脚本和模板都在这个目录里。

## 快速上手

已有订阅的 Mac，不需要固定出口账号：

```bash
git clone https://github.com/Jzzwww/ai-network-setup-skill.git
cd ai-network-setup-skill/skills/ai-network-setup
./scripts/probe-env.sh
```

`supported=yes` 之后，按 [诊断](skills/ai-network-setup/references/00-diagnose.md) 回答 6 个问题，然后只做 [Mac + 订阅](skills/ai-network-setup/references/01-path-mac-clash.md)。配完执行：

```bash
./scripts/net-check.sh
```

不要设置 `EXPECTED_IP`。没有 FAIL 就可以先用。脚本会访问通用回显地址，不默认请求某一家 AI 的网站。

## 平台

| 平台 | 状态 |
|---|---|
| macOS + Clash Verge Rev 当前稳定版 | 有步骤，需在你的机器上验证 |
| iPhone + Shadowrocket | 有步骤 |
| Windows / Linux / Android | 未覆盖，见 [ROADMAP](docs/ROADMAP.md) |

客户端版本以官方当前稳定版为准，不锁定历史版本号。

## 合规

遵守当地法律、单位安全策略和服务条款，用真实身份注册和付费。不用于规避地区限制、封禁或 KYC。不禁用、不绕过 DNS 安全组件、VPN 或 MDM。订阅链接和密码只填在客户端界面里。`net-check.sh` 与 `probe-env.sh` 只读。`dns-guard.sh` 会改系统 DNS，默认不启用。

## 更多

步骤、判定标准和紧急回退都在 [references/](skills/ai-network-setup/references/00-diagnose.md)。贡献见 [CONTRIBUTING.md](CONTRIBUTING.md)，计划见 [docs/ROADMAP.md](docs/ROADMAP.md)，许可是 [MIT](LICENSE)。

English: a self-contained skill for a stable proxy and leak checks on macOS, with optional iPhone notes. It does not apply where a service is officially unavailable.
