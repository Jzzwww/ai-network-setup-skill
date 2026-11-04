## 2. 小工具：浏览器插件 + Shadowrocket

### 2.1 Chrome WebRTC Network Limiter
**目标**：防止 WebRTC 绕过代理暴露真实本地/公网 IP。
**前置**：Chrome（公司托管也可装官方插件，ID `npeicpdbkakmehahjeeohfdhnlpdklia`）。
**步骤**：每个使用的 **Profile 分别安装** → 选项选 **"Use my proxy server (if present)"** → 扩展详情打开 **"在无痕模式下允许"**。
**验证**：browserleaks.com/webrtc 不出现本地真实公网 IP；显示的 IPv6 若属于代理节点则不是泄漏。
**常见坑**：只装了一个 Profile；无痕未授权。
**回滚**：停用/卸载扩展。

### 2.2 iPhone Shadowrocket
**目标**：手机 AI 流量与 Mac 同一出口。
**前置**：Shadowrocket；模板 `templates/shadowrocket.conf`（全占位符）。
**步骤**
1. 把模板 AirDrop/文件导入：配置 → 从文件导入 → 使用。
2. **在手机上**把 `<见…>` 占位替换为真实值（机场节点、ISP 用户名密码）；不要回写到文件/仓库。
3. 关键项：`ipv6 = false`；DoH + `dns-fake-ip = true`；规则首条 `AND,((PROTOCOL,UDP),(DST-PORT,443)),REJECT-NO-DROP`（拒 QUIC，强制 TCP，因 ISP 链 UDP 关）；ISP 节点 `udp-relay=false,tfo=false`，`proxy=<前置节点>` 链式；`Claude-ISP = fallback,...`；公司域名 DIRECT。
4. 全局路由选"配置"；在节点"代理通过"里核对链路。
**验证**：Safari 打开 `https://claude.ai/cdn-cgi/trace` → ip=<你的固定出口IP>；`https://api.ipify.org` → 普通节点；日志中 claude 域名命中 Claude-ISP。
**回滚**：切回旧配置或关闭 Shadowrocket。

---
