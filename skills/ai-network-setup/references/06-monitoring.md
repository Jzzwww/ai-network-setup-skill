# 6. 定时看结果

下文命令都在技能根目录执行。巡检只报告，不自动改配置，也不重载。

## 适用谁

01 已经 pass，希望每天看一次有没有 FAIL 的人。不是必做。

## 先问

- 是否要开机定时跑。不同意就只在需要时手动执行。
- 是否启用了固定出口。只有那时才设置 `EXPECTED_IP`。
- 机器上是不是已经有别的定时任务在做同样的事。有的话不要再装一份。

## 目标

用同一条只读命令看到：探测有没有响应、`AI-EXIT` 在不在、类型是不是 Fallback。固定出口模式下，再看地址是否还是你记下的那个。

## 前置

- 技能目录留在一个不会被随便挪走的路径。launchd 要用绝对路径。
- 本机有 curl。没有 dig 或 python3 时，脚本会跳过对应项并说明，不会去弹 macOS 的命令行工具安装窗。

## 脚本会访问哪里

`net-check.sh` 默认向这些地址发起出站请求，对方能看到出口地址：

| 变量 | 默认 | 作用 |
|---|---|---|
| `TRACE_URL` | `https://1.1.1.1/cdn-cgi/trace` | 看 ip / loc / colo |
| `IP_ECHO_URL` | `https://api.ipify.org` | 再取一次经混合端口的地址 |
| `DELAY_URL` | `http://www.gstatic.com/generate_204` | 让本机 Clash 给分组成员做延迟测试 |

可以全部改成你信任的地址。脚本不默认请求某一家 AI 的网站。不想产生这些请求就不要跑它。

其它常用变量：`GROUP`（默认 `AI-EXIT`）、`PROXY_PORT`、`CLASH_SOCK`、`NETWORK_SERVICE`、`BYPASS_DOMAINS`、`FAKEIP_SERVER`、`DNS_PROBE_NAME`、`MAX_DELAY_CHECKS`。不设置端口和服务名时，脚本自己探测，不写死 Wi-Fi 或 7897。

## 步骤

1. `[Agent只读]` 先手动跑一次：

```bash
./scripts/net-check.sh
./scripts/net-check.sh --json
```

2. `[Agent需确认]` 要定时的话，复制 `templates/com.example.net-check.plist` 到 `~/Library/LaunchAgents/`，把 `REPLACE_ME_USER` 和脚本路径换成这台机器上的绝对路径。仓库克隆运行时，路径是仓库里的 `skills/ai-network-setup/scripts/net-check.sh`，不是模板里的 `~/.claude` 示例。
3. 时刻是例子：09:00 和 18:00。改成你需要的时间。launchd 用这台 Mac 的本地时区。
4. 固定出口才加上 `EXPECTED_IP`。值不要提交。

```bash
plutil -lint ~/Library/LaunchAgents/com.example.net-check.plist
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.example.net-check.plist
launchctl kickstart "gui/$(id -u)/com.example.net-check"
tail -n 40 ~/Library/Logs/net-check.log
```

## 验证

退出码：`0` 没有 FAIL 和 WARN，`1` 有 WARN，`2` 有 FAIL，`3` 是 `--json` 但没有可用的 python3。

- pass：手动运行退出码不是 2，并且日志里能看到组 `AI-EXIT`。
- fail：输出里有「代理组不存在」。这表示要去创建组或修正 `GROUP`，不是一句含糊的 INFO。
- dns-guard 没装：INFO。不是故障。
- 节选示例（地址是文档网段，不是某台真实机器；真实输出里的 INFO 会更多）：

```text
== net-check 2026-01-01 09:00:00 UTC ==
[INFO] 只读巡检，不改配置、不重载。出站请求：TRACE_URL=...
[OK]   trace(proxy) ip=203.0.113.10 loc=US colo=EWR（未设置 EXPECTED_IP，不要求固定地址）
[OK]   组 AI-EXIT 类型是 Fallback，当前成员: node-a
[INFO] dns-guard 未安装或未加载。它是可选项，只在 VPN 反复改写 DNS 时才需要；没装不是故障。
== 结果: FAIL=0 WARN=0 INFO=2 ==
```

## 告警时做什么

FAIL（告诉人，**不自动修复、不重载**）：探测无响应；设置了 `EXPECTED_IP` 但地址不一致；组不存在。

WARN：组不是 Fallback、成员超时或超过 1500ms、TUN 或系统代理没开、代理路径和 noproxy 路径的地址不一致。最后一项要按 [05-leak-checks.md](05-leak-checks.md) 判断，脚本不下结论。

## 常见坑

- 把 plist 直接 bootstrap，路径里还留着 `REPLACE_ME_USER`。
- 在已经有定时任务的机器上又装一份。
- 用某一家 AI 网站的 trace 当作唯一标准。默认已经换成通用回显。

## 回滚

```bash
launchctl bootout "gui/$(id -u)/com.example.net-check"
rm ~/Library/LaunchAgents/com.example.net-check.plist
```

这只卸掉定时任务，不改 Clash。Clash 本身的回退见 [troubleshooting.md](troubleshooting.md)。
