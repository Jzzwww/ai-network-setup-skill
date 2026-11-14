# 1. Mac + 已有订阅

下文命令都在技能根目录执行。这是默认路径。不需要固定出口账号。

## 适用谁

macOS，希望 AI 工具少掉线、少泄漏。你已经有一份可用的订阅，或者准备新装 Clash Verge Rev 再导入它。

## 先问

- `./scripts/probe-env.sh` 的 `supported` 是不是 `yes`。不是就停止。
- 有没有订阅。没有就去 [07-buying.md](07-buying.md)，或者停下来。不想再买东西的人，用现有订阅即可。
- 能不能安装客户端、打开 TUN 和系统代理。公司电脑先问清楚。
- 这一层**不**关闭 IPv6，也**不**安装浏览器插件。那两件事在 [05-leak-checks.md](05-leak-checks.md)，而且都要先问。

## 目标

名为 `AI-EXIT` 的 Fallback 组使用你从订阅里挑出的少数节点。你点名的那些服务走这一组。单位域名直连。配完有明确的 pass/fail。

## 前置

- macOS，有管理员权限才能装 Service 模式。
- Clash Verge Rev 的**当前稳定版**，以官方发布页为准。不要为了凑某一个历史版本号去装旧包。
- 一份你有权使用的订阅。
- 本技能目录在本机。

## 步骤

1. `[Agent只读]` 跑 `./scripts/probe-env.sh`。记下 `network_service`、`listen_ports`、`config_dir`、`ai_clients`。
2. `[用户UI]` 若还没装客户端：安装 Clash Verge Rev 当前稳定版。
3. `[用户UI]` 打开 Service 模式（界面可能叫系统服务或 Service Mode）。TUN 通常需要它。然后 `[Agent只读]` 再跑一次 probe，确认出现 `socket`。路径因版本而异，以 probe 为准。
4. `[用户UI]` 在订阅页导入订阅。链接只贴在界面里。代理不要打开 `profiles` 里的文件。
5. `[用户UI]` 在节点列表里挑 2 到 3 个你平时觉得稳的节点，把**显示名**原样抄下来，包括空格和符号。
6. `[Agent需确认]` 按 [00-diagnose.md](00-diagnose.md) 做备份。
7. `[用户UI]` 打开订阅的扩展脚本（Script override），粘贴 `templates/clash-verge-script-override.example.js`。
   - `MODE` 保持 `"subscription"`。
   - 把 `SUB_NODES` 换成第 5 步的名字。
   - 把要用的 `AI_SERVICES` 设为 `enabled: true`，域名改成你实际使用的服务，删掉不用的。示例里的 Claude 域名在 `enabled: false` 时不会生效。
   - 不要填 `ISP`。固定出口才需要它。
   - 保存前确认 `SUB_NODES` 里没有 `REPLACE_ME`。脚本发现占位符或没有任何启用的服务会拒绝加载，这是故意的。
8. `[用户UI]` 先退出正在用的 AI 客户端，再重新激活订阅。这一步会重载。
9. `[用户UI]` 模式选规则（Rule）。全局模式不会按你写的规则走。
10. `[用户UI]` 打开 TUN。stack 优先用界面里的 gVisor；这一版如果没有该项，就用界面推荐的 stack。让 DNS 劫持包含 `any:53`。其它数值先用客户端默认，probe 能读到再记下来。
11. `[用户UI]` DNS：若要减少本机直接解析，把 enhanced-mode 设为 fake-ip。网段以客户端显示为准，常见示例是 `198.18.0.1/16`，**探测到之后**再导出 `FAKEIP_SERVER`。名字服务器用你所在网络合适的解析服务，不假设你在哪个国家。可选例子：系统 DNS、`1.1.1.1`、`8.8.8.8`、`223.5.5.5`。
12. `[用户UI]` 打开系统代理。端口以设置页或 probe 的 `listen_ports` 为准。常见默认里有 7897，但没探测到之前不要写死。
    - bypass 放本机网段、`localhost`，以及你的单位域名。
    - 只在客户端界面里改 bypass。只改磁盘上的 `verge.yaml` 往往不生效。
    - 单位工具报证书错误时，把对应域名加进 bypass，并在规则里对它使用 `DIRECT`。

## 验证

`[Agent只读]` 不要设置 `EXPECTED_IP`。

```bash
./scripts/net-check.sh
```

也可以自己看回显（把端口换成探测到的值）：

```bash
curl -sS -m 12 -x "http://127.0.0.1:端口" "https://1.1.1.1/cdn-cgi/trace" | sed -n '/^ip=/p;/^loc=/p;/^colo=/p'
curl -sS -m 12 --noproxy '*' "https://1.1.1.1/cdn-cgi/trace" | sed -n '/^ip=/p;/^loc=/p;/^colo=/p'
```

- pass：没有 FAIL；组 `AI-EXIT` 存在且类型是 Fallback；经混合端口的探测有地址。开了 TUN 时，两条探测的地址一致。
- fail：组不存在、探测无响应，或你明明没做固定出口却因为地址「不是某一个 IP」被判失败。订阅在几个节点之间切换时，地址可以变，这不是失败。
- warn：要读说明。TUN 没开、系统代理没开、成员延迟高，都是警告，脚本不会替你改配置。

## 常见坑

- 改了脚本但没有重新激活订阅，运行时还是旧的。
- 节点名和订阅显示名差一个空格。订阅更新后名字变了，Fallback 成员会失效。见 [troubleshooting.md](troubleshooting.md)。
- 把 `MODE` 改成 `fixed-exit`，但又没有账号。脚本会拒绝加载。
- 系统 DNS 变成 `114.114.114.114` 或别的公共 DNS。这一个数字不能说明正常，也不能说明泄漏。按 [05-leak-checks.md](05-leak-checks.md) 判断。
- 端口不是你以为的那个。以 probe 为准。

## 回滚

最小回退：`[用户UI]` 关掉 TUN 和系统代理。脚本有问题就用备份里的 profiles 恢复，退出客户端后再激活。整机回退见 [troubleshooting.md](troubleshooting.md) 的「紧急全回退」。
