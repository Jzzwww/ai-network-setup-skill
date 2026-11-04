## 5. 定时工具与检查

### 巡检清单
1. trace（系统代理 & TUN）= 固定出口；2. AI-ISP 类型 Fallback、now、成员延迟；2b. 每个成员延迟（>1500ms 或超时 WARN，全失败 WARN）；3. 普通出口非 CN；4. fake-ip；5. TUN/ipv6 运行时 vs 磁盘；6. 脚本存在；7. dns-guard；8. Wi-Fi IPv6、系统代理、bypass；9. AI 客户端进程。

**频率示例**：每天 10:36 / 13:36 / 18:36 / 22:36（Asia/Taipei）。

### 只读脚本 `net-check.sh`
```bash
EXPECTED_IP=<你的固定出口IP> EXPECTED_COLO=<如EWR> ./scripts/net-check.sh
```
可选环境变量：`CLASH_SOCK`、`PROXY_PORT`（默认 7897）、`GROUP`（默认 Claude-ISP）。只做 GET/读取，不改配置、不重载。退出码：0 全部正常 / 1 有 WARN / 2 有 FAIL。

### 调度方式
- **launchd**：模板 `templates/com.example.net-check.plist`（占位 `<你的用户名>` `<你的固定出口IP>` `<机房如EWR>`；10:36/13:36/18:36/22:36；日志 `~/Library/Logs/net-check.log`）。
  ```bash
  # 安装
  cp templates/com.example.net-check.plist ~/Library/LaunchAgents/ && vi ~/Library/LaunchAgents/com.example.net-check.plist   # 替换占位
  plutil -lint ~/Library/LaunchAgents/com.example.net-check.plist
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.net-check.plist
  launchctl kickstart gui/$(id -u)/com.example.net-check   # 立即跑一次
  tail -n 30 ~/Library/Logs/net-check.log
  # 卸载
  launchctl bootout gui/$(id -u)/com.example.net-check && rm ~/Library/LaunchAgents/com.example.net-check.plist
  ```
  注：已有其它定时巡检的机器不要重复安装。
- **Bot routine**：让 bot 按上面时间在 Mac 上执行脚本并汇报 FAIL/WARN。

### 告警阈值
- FAIL（立即告知，**不自动修复、不重载**）：trace 出口 ≠ 期望；trace 无响应。
- WARN：AI-ISP 当前成员非首选持续 >2 次巡检；成员延迟 > 1500ms 或全部超时；fake-ip 异常；bypass 缺公司域名；dns-guard 未加载；出现全局 IPv6。

---
