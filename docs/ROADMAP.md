# Roadmap

现状和仓库一致：

- 已有：macOS 上「先诊断再分流」的订阅路径、可选固定出口、iPhone 示例、通用的公司 VPN 共存说明、只读 `probe-env.sh` / `net-check.sh`（含 `--json`）、可选且默认关闭的 `dns-guard.sh`。
- CI：GitHub Actions 对 `skills/ai-network-setup/scripts/*.sh` 运行 `shellcheck -S warning`。还没有 markdownlint，也没有 gitleaks。

## P1

- [ ] Windows 只读诊断脚本，以及 Clash Verge / TUN 在 Windows 上的步骤
- [ ] Linux 上 mihomo 的只读诊断（配置步骤仍单独写）

## P2

- [ ] Linux（mihomo + systemd）配置说明
- [ ] Android。在有单独验证之前保持「未覆盖」
- [ ] Surge、Stash、sing-box 的等价模板

## P3

- [ ] 路由器 / 旁路由
- [ ] CI 增加 markdownlint 和密钥扫描
- [ ] 英文全文
- [ ] Tailscale 在 App Store、独立安装、Homebrew 下的命令差异
