## 1. 基础：Clash Verge

**目标**：Mac 全局走 Clash；AI 流量固定出口；其余走机场；公司域名直连。

**前置条件**：macOS 管理员权限；一个机场订阅（`<你的订阅URL>`，只在 Verge UI 粘贴）；一个静态 ISP 代理账号（`<你的ISP代理host:port/用户名/密码>`）。

**步骤**
1. 安装 Clash Verge Rev（GitHub 官方 release，示例版本 2.5.8）。
2. 设置 → 安装并启用 **Service 模式**（TUN 需要）。示例控制 socket：`/var/run/clash-verge-service/users/<uid>/verge-mihomo.sock`。
3. 订阅 → 导入 `<你的订阅URL>`。
4. 订阅右键 → **扩展脚本（Script override）**，在脚本中：
   - 新增静态 ISP 节点若干个，host/port 相同，`dialer-proxy` 分别指向不同机场节点 + 一个不带前置的 direct。命名示例：`ISP-10001-viaA / viaB / viaC / direct`。
   - 新增组 `AI-ISP`：`type: fallback`，成员按上序，`url: http://www.gstatic.com/generate_204`，`interval: 300`，expected 204。
   - 可选 `AI-Manual`（select）仅供人工排障，**平时不切**。
   - 规则**插到最前**：
     ```
     PROCESS-NAME-REGEX,(?i)^Claude(?: Helper.*)?$,AI-ISP
     DOMAIN-SUFFIX,claude.ai / anthropic.com / claude.com / claudeusercontent.com / claudemcpclient.com / claudemcpcontent.com → AI-ISP
     DOMAIN,servd-anthropic-website.b-cdn.net / anthropic.com.cdn.cloudflare.net / anthropic-com.ghost.io → AI-ISP
     DOMAIN-KEYWORD,anthropic / claude → AI-ISP
     DOMAIN-SUFFIX,<公司域名1> / <公司域名2> → DIRECT   # 示例：公司域名
     ```
   - 其它 AI 服务（如 OpenAI）用独立组，不要复用 AI-ISP。
5. 保存后在 UI **重新激活订阅**（这就是重载，AI 客户端须先关闭）。
6. TUN：开启，stack **gVisor**，`dns-hijack: [any:53]`，auto-route true，strict-route false，mtu 1500。
7. DNS：`enhanced-mode: fake-ip`（监听示例 198.18.0.2）；`proxy-server-nameserver` 用国内 DoH/DoT（示例 doh.pub、tls://223.5.5.5）。
8. 系统代理：开启，mixed-port **7897**；关闭"使用默认绕过"(`use_default_bypass: false`)，自定义 bypass：
   ```
   127.0.0.1 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 localhost *.local <local> *.<公司域名1> *.<公司域名2> <公司AI网关域名>
   ```
   示例：`*.corp.example.com *.example-intra.net ai-gateway.corp.example.com`。

**验证**
```bash
curl -s -x http://127.0.0.1:7897 https://claude.ai/cdn-cgi/trace | grep -E '^(ip|loc|colo)='   # ip=<你的固定出口IP>
curl -s --noproxy '*'           https://claude.ai/cdn-cgi/trace | grep -E '^(ip|loc|colo)='   # 走 TUN，同上
curl -s -x http://127.0.0.1:7897 https://api.ipify.org   # 普通节点 IP，非 CN，≠ 固定出口
dig +short @198.18.0.2 claude.ai                          # 198.18.x.x
```

**常见坑**
- 只改脚本没重新激活订阅 → 不生效。
- 系统 DNS 显示 114.114.114.114 → TUN 占位，正常。
- bypass 缺公司域名 → 公司 CLI 证书错误。
- "Connection went idle" → 长链路长连接被断，重试即可。

**回滚**：脚本用 `.bak-*` 恢复 → 关闭 AI 客户端 → 重新激活订阅；或临时关 TUN/系统代理。

---
