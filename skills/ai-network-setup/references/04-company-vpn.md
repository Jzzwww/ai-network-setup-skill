# 4. 和公司或学校 VPN 共存

下文命令都在技能根目录执行。这里不针对某一家公司的产品。单位下发的安全组件保持原样：不关闭，不绕过。

## 适用谁

macOS 上已经按 [01-path-mac-clash.md](01-path-mac-clash.md) 配好，同时还要连公司或学校 VPN，或要解析内网域名。

## 先问

- VPN 客户端和 MDM 是否必须保持启用。答案只能是保持启用。
- 哪些域名必须直连。向用户要域名，不要猜内部域名，也不要把真实内部域名写进仓库。
- 是否允许写 `/etc/resolver`。这需要管理员权限。
- 只有在「VPN 反复改写 DNS，导致该解析的名字失败」时，才讨论文末的可选 dns-guard。

## 目标

连上 VPN 后内网仍可用，AI 工具仍走 `AI-EXIT`，单位域名不进代理。

## 前置

- 01 已完成。
- 知道要直连的域名，以及 VPN 网关域名（如果有）。

## 步骤

1. `[用户UI]` 在扩展脚本的 `COMPANY_DOMAINS` 里写上单位域名，并填好 `COMPANY_DNS`。解析地址换成你的网络里真正该用的，例如系统 DNS、单位内网 DNS、`1.1.1.1`、`8.8.8.8` 或 `223.5.5.5`。不要留着 `REPLACE_ME_DNS`，否则脚本拒绝加载。
2. `[用户UI]` VPN 网关域名也走 `DIRECT`。在系统代理 bypass 里加上 `*.单位域名`。bypass 只在 Clash Verge 界面里改。
3. `[用户UI]` 先开 Clash，再连 VPN。若连上后特别慢：`[用户UI]` 断开 VPN 再连一次。不要关闭 Clash 的 TUN 来「修好」VPN，也不要关闭 VPN。
4. `[Agent需确认]` 仅当公网能看见的单位域名被 VPN 推来的 DNS 解析成 SERVFAIL 时，才添加分流解析。先备份 `/etc/resolver`（见诊断文档）。文件名用该域名，内容是一台能解析它的服务器：

```bash
sudo tee "/etc/resolver/corp.example.com" <<'EOF'
nameserver 192.0.2.53
EOF
```

把域名和地址换成你的。`192.0.2.53` 只是文档占位，不能真用。

5. `[Agent只读]` Tailscale 若没安装，跳过。若已安装且用户同意，再改设置：不要让它接管系统 DNS，也不要使用 exit node。

```bash
tailscale set --accept-dns=false --exit-node=
tailscale debug prefs
```

只看 `CorpDNS` 是否为 false、ExitNode 是否为空。不要把 `tailscale status` 全文贴到聊天，里面有网络里其他设备的信息。App 版命令可能在 `/Applications/Tailscale.app/Contents/MacOS/Tailscale`。不同安装方式的差异还没逐一写完。

## 验证

- pass：内网站点或内网名字能打开；`./scripts/net-check.sh` 没有新增 FAIL；你点名的单位域名出现在 bypass 列表里。

```bash
networksetup -getproxybypassdomains "这里换成 network_service"
dig corp.example.com
scutil --dns
```

`dig` 有你预期的记录，并且 `scutil --dns` 能看到对应的 resolver 文件，分流解析才算 pass。

- fail：内网完全不可用，或 AI 探测没有响应。慢，但内网和探测都正常，先按「断开 VPN 再连一次」处理，不要扩大改动。

## 常见坑

- 只改了 `verge.yaml` 里的 bypass，界面没改，系统代理绕过名单不变。
- 单位的 DNS 安全扩展会拦截系统 DNS，也可能覆盖 `/etc/resolver`。这是策略，不修、不绕。它不影响你已经交给 Clash 的那部分出口。
- `systemextensionsctl list` 里旧实例显示等待重启后卸载，是系统的正常状态，不要手动去删扩展。

## 可选：dns-guard

默认不装。它**会改系统 DNS**，影响这块网卡上的所有程序，也可能和 VPN、描述文件来回覆盖。

适合：VPN 一连上就把 DNS 改掉，导致你需要的名字失败，而且用户明确同意用一个指定的解析地址把它改回来。

不适合：DNS 目前是正常的；单位要求必须用他们的解析器；你还没问过用户。

使用前：

1. `[Agent只读]` `NETWORK_SERVICE` 用 probe 的 `network_service`。
2. `[Agent需确认]` 在 DNS 仍正确时先备份，再写入。占位符没替换时脚本拒绝修改。

```bash
NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --status
NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --backup-only
NETWORK_SERVICE='无线局域网' DNS_SERVERS='1.1.1.1 8.8.8.8' ./scripts/dns-guard.sh --apply
```

定时示例是 `templates/com.example.dns-guard.plist`，间隔 300 秒。把 `REPLACE_ME_*` 都换掉，`plutil -lint` 通过后再加载。不要把间隔改成数秒。

```bash
cp templates/com.example.dns-guard.plist ~/Library/LaunchAgents/
# 编辑路径、服务名和 DNS 之后：
plutil -lint ~/Library/LaunchAgents/com.example.dns-guard.plist
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.example.dns-guard.plist
```

卸载：

```bash
NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --restore
launchctl bootout "gui/$(id -u)/com.example.dns-guard"
rm ~/Library/LaunchAgents/com.example.dns-guard.plist
```

`net-check` 在它没加载时只打 INFO，不会因此失败。

## 回滚

删掉你添加的 `/etc/resolver/<域名>`，或从备份拷回。bypass 和脚本按备份恢复。装了 dns-guard 就按上面的卸载做。VPN 客户端保持安装。
