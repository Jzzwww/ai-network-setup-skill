# 排障

先对上现象，再跑只读命令，最后才改。改系统前按诊断文档里的标记征得同意。命令在技能根目录执行。服务名和端口用 `./scripts/probe-env.sh` 的结果，不要写死。

## 紧急全回退

目标：系统代理关闭，TUN 关闭，DNS 和 IPv6 回到备份里的状态。每一步做完就可以停，只要网络已经恢复。

1. `[用户UI]` 退出 AI 客户端。
2. `[用户UI]` 在 Clash 里关闭 TUN，关闭系统代理。界面打不开时，才用命令（服务名换成备份里的）：

```bash
networksetup -setwebproxystate "服务名" off
networksetup -setsecurewebproxystate "服务名" off
networksetup -setsocksfirewallproxystate "服务名" off
```

这三行是 `[Agent需确认]`。

3. `[Agent需确认]` 恢复 DNS。备份里的 `networksetup.txt` 若显示没有单独的 DNS 服务器，执行第一行；若当时记着具体地址，把那些地址填进第二行。

```bash
networksetup -setdnsservers "服务名" Empty
networksetup -setdnsservers "服务名" 192.0.2.53
```

`192.0.2.53` 只是占位，必须换成备份里的地址，否则不要执行第二行。装过 dns-guard 时：

```bash
NETWORK_SERVICE='服务名' ./scripts/dns-guard.sh --restore
launchctl bootout "gui/$(id -u)/com.example.dns-guard"
```

4. `[Agent需确认]` 只有以前关闭过 IPv6 时才恢复：

```bash
networksetup -setv6automatic "服务名"
```

5. `[Agent需确认]` 恢复 Clash 文件。把 `~/Library/Application Support/ai-network-setup-backups/<时间戳>/` 里的 `profiles`、`verge.yaml`、`profiles.yaml` 拷回 probe 确认过的 `config_dir`。不要把这些文件贴到聊天。然后 `[用户UI]` 重新打开客户端。
6. `[用户UI]` 手机切回旧配置，或关闭 Shadowrocket。

单位的 VPN、DNS 安全组件和 MDM 不要动。

## 决策

| 现象 | 诊断 | 原因 | 处理 |
|---|---|---|---|
| `net-check` 说组不存在 | `GROUP` 的值；扩展脚本是否启用 | 没有 `AI-EXIT`，或名字不一致 | 按 01 创建 Fallback 组。不要把这句当成 socket 缺失 |
| 提示未找到 socket | `./scripts/probe-env.sh` 的 `socket` | 客户端没开，或没开外部控制 | 这不是组不存在。先开客户端。脚本不读密钥 |
| 探测无响应 | 端口是否等于 `listen_ports` | 端口猜错，或客户端没运行 | 设置 `PROXY_PORT` 后重跑。不要假设 7897 |
| 没设 `EXPECTED_IP`，地址和昨天不同 | 组的当前成员 | 订阅模式在节点之间切换 | 正常。要地址不变才做 02 |
| 设了 `EXPECTED_IP`，但 trace 不等 | 组的 `now`；规则是否指向 `AI-EXIT` | 组被切走，或规则没命中 | 先看规则。客户端还连着就不要重载 |
| 全部成员延迟失败 | 对照订阅里的当前名字 | 订阅更新后节点改名，`dialer-proxy` 或 Fallback 成员失效 | 改脚本里的名字，退出客户端后再激活。不要随便换一个出口 |
| 两条 trace 地址不同 | TUN 是否开启 | 没开 TUN 时，noproxy 那条是本机网络 | 按 05 判断。未征得同意不要关 IPv6 |
| 系统 DNS 是 114.114.114.114 或其它公共 DNS | 05 的 dig 步骤 | 可能是占位，也可能是查询真的出去了 | 用 05 的 pass/fail，不要凭这一个地址下结论 |
| 页面出现本机公网地址 | WebRTC 测试页 | 浏览器没走代理 | 先问 MDM，再考虑 05 的插件 |
| 公司工具证书错误 | `networksetup -getproxybypassdomains` | bypass 缺单位域名，或只改了 yaml | 在 Clash 界面补 bypass，规则里该域名用 DIRECT |
| 连上 VPN 后很慢 | 内网是否仍能打开 | VPN 流量进了虚拟网卡 | 断开 VPN 再连一次。不要关 VPN 客户端 |
| 单位域名 SERVFAIL | `scutil --dns` | VPN 推来的 DNS 不解析这个名字 | 用户同意后再写 `/etc/resolver`。安全扩展覆盖了也不要去关它 |
| 改了脚本没变化 | 是否重新激活订阅 | 运行时还是旧配置 | 退出 AI 客户端后激活 |
| 客户端提示连接 idle | 重试一次同样的操作 | 长连接在中途被断开 | 重试。反复出现再看延迟，而不是换一套身份 |
| 导入 Shadowrocket 失败 | `grep REPLACE_ME templates/shadowrocket.conf` | 占位符还在，或用了非法组语法 | 按 03 在界面建组，或替换后再导入 |
| Windows / Linux / Android | `probe-env` 的 `supported` | 没有对应步骤 | 停止 |

## 新设备

- [ ] probe 的 `supported=yes`
- [ ] Clash Verge Rev 当前稳定版，能看到 socket
- [ ] 订阅只在界面导入
- [ ] `AI-EXIT` 是 Fallback，成员名抄自订阅
- [ ] 规则模式、TUN、系统代理的端口以探测为准
- [ ] 需要时，单位域名 DIRECT，并且 bypass 在界面里
- [ ] `./scripts/net-check.sh` 没有 FAIL，且没有设置 `EXPECTED_IP`
- [ ] 泄漏检查按需做；IPv6 和浏览器插件都问过
- [ ] 固定出口仅在需要时做 02
- [ ] 手机只做 iPhone；Android 跳过
- [ ] launchd 可选

## 给同事复刻

- [ ] 用自己的订阅和自己的账号，不共用密码，也不共用同一个固定出口账号
- [ ] 替换自己的节点名、单位域名和服务列表
- [ ] 单位安全组件保持原样
- [ ] 01 通过后再看其它页
- [ ] 填好的配置不进 git，不发到群里
