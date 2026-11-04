## 附录 A：故障速查表
| 现象 | 原因 | 处理 |
|---|---|---|
| trace ip ≠ 固定出口 | Manual 组被切 / 规则未命中 | 查组 now 与规则；不重载，人工决定 |
| AI-ISP 全部超时 | 前置跳或 ISP 代理故障 | 记录延迟，等 fallback；不换出口 |
| Connection went idle | 长流被断 | 重试 |
| 公司 CLI 证书错误 | bypass 缺公司域名 | Verge UI 补 bypass |
| 家里连 VPN 很慢 | VPN 进了 utun | 断开重连 VPN |
| 公网公司域名 SERVFAIL | VPN 推内网 DNS | /etc/resolver；被 公司 DNS 安全组件 覆盖则接受 |
| 系统 DNS=114.114.114.114 | TUN 占位 | 正常 |
| 测试站显示 IPv6 | 代理节点 IPv6 | 非泄漏，确认 Wi-Fi IPv6 Off |
| 改脚本不生效 | 未重新激活订阅 | 关闭 AI 客户端后激活 |


## 附录 B：新设备 checklist
- [ ] 安装 Clash Verge Rev + Service 模式
- [ ] 导入订阅（UI 粘贴）+ 扩展脚本（AI-ISP Fallback、规则置顶、公司 DIRECT）
- [ ] TUN gVisor / dns-hijack any:53 / fake-ip
- [ ] 系统代理 7897 + 自定义 bypass（含公司域名）
- [ ] Wi-Fi IPv6 Off
- [ ] Chrome 每个 Profile 装 WebRTC Limiter + 无痕允许
- [ ] VPN、/etc/resolver、Tailscale accept-dns=false
- [ ] 部署 net-check.sh + launchd，跑一次全 OK
- [ ] iPhone Shadowrocket 导入模板、手机端填凭据、trace 验证


## 附录 C：同组成员复刻 checklist
- [ ] 用**自己的**机场与 ISP 代理账号（真实身份/支付），不共用凭据、不共用同一出口账号
- [ ] 替换所有 `<你的…>`：订阅、ISP 账号、固定出口 IP、公司域名、uid/socket 路径
- [ ] 公司安全组件保持原状（公司 DNS 安全组件、公司 VPN 客户端、MDM）
- [ ] 第 1 层验证全部通过后再做第 2–5 层
- [ ] 配置文件与模板不入 git、不发群
