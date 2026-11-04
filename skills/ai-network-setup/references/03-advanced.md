## 3. 进阶配置

### 3.1 公司 VPN（公司 VPN 客户端）共存
- **目标**：VPN 与 Clash TUN 同时可用。
- **步骤**：公司域名在 Clash 规则 DIRECT + 系统代理 bypass；VPN 网关域名（示例 `<VPN网关域名>`）DIRECT。
- **坑**：先开 Clash 再连 VPN 时，VPN 流量可能被 utun 带进代理 → 很慢。**处理：断开 VPN 再重连**。
- **验证**：内网站点可开；trace 仍为固定出口。

### 3.2 Split DNS
- VPN 可能推送内网 DNS，对公网公司域名 SERVFAIL。
- 新建 `/etc/resolver/<公网公司域名>`，内容 `nameserver 223.5.5.5`（需 sudo，先备份）。示例：`portal.example.com`。
- Clash 脚本 `nameserver-policy`：`+.<公司域名>` → `["<内网DNS>","223.5.5.5"]`（VPN 外回退）；个别域名可指定 DoH。
- 验证：`dig <域名>` 有 A 记录；`scutil --dns` 能看到 resolver。
- 回滚：删除 resolver 文件 / 恢复脚本备份。

### 3.3 Tailscale 安全设置
- 目标：`accept-dns=false`（不抢系统 DNS）、不用 exit node（不改出口）、按需关闭开机自启。
- 设置：`tailscale set --accept-dns=false --exit-node=`（需 Tailscale 已安装并登录）。
- 只读验证（Tailscale 官方 CLI 命令）：
  ```bash
  tailscale debug prefs | python3 -c 'import json,sys;d=json.load(sys.stdin);print("CorpDNS",d["CorpDNS"],"ExitNode",d.get("ExitNodeID") or d.get("ExitNodeIP"))'   # 期望 CorpDNS False、ExitNode 空
  tailscale status --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["BackendState"],d.get("ExitNodeStatus"))'
  ```
  macOS App 版 CLI 位于 `/Applications/Tailscale.app/Contents/MacOS/Tailscale`（`/usr/local/bin/tailscale` 通常是指向它的包装脚本）。
- 坑：卸载 App 后残留 `/usr/local/bin/tailscale` 包装脚本；accept-dns 打开会覆盖 DNS；exit node 会改变出口。
- 回滚：`tailscale set --accept-dns=true` 或退出 Tailscale。

### 3.4 dns-guard（launchd）
- 用途：守护系统 DNS/解析设置不被 VPN 改乱。示例：`~/Library/LaunchAgents/com.example.dns-guard.plist` → `/bin/bash ~/.local/bin/dns-guard.sh`，RunAtLoad，StartInterval 3，错误日志 `~/Library/Logs/dns-guard.err.log`。
- 只做 DNS 守护，**不得**去禁用公司 公司 DNS 安全组件。
- 验证：`launchctl list | grep dns-guard`。回滚：`launchctl bootout gui/$(id -u) <plist>`。

### 3.5 IPv6
- Wi-Fi IPv6 关：`networksetup -setv6off Wi-Fi`（回滚 `-setv6automatic`）。
- Clash 运行时 ipv6 可为 true（节点侧 IPv6），测试站显示的代理 IPv6 不是泄漏。
- 验证：`networksetup -getinfo Wi-Fi | grep IPv6`、`ifconfig | grep inet6` 无全局地址。

### 3.6 公司 DNS 安全组件 已知行为
公司 DNS 系统扩展会拦截系统 DNS、可能覆盖 /etc/resolver；属策略，**不修、不绕**，不影响 Clash 出口。`systemextensionsctl list` 里出现旧实例 "terminated waiting to uninstall on reboot" 正常。

### 3.7 Clash Verge bypass 字段坑
bypass 只能通过 Verge UI（或其 patchVerge 接口）同时设置 `use_default_bypass` + `system_proxy_bypass` 生效；**只改 verge.yaml 不生效**。验证用 `networksetup -getproxybypassdomains Wi-Fi`。

---
