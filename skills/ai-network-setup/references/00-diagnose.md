# 0. 先诊断，再选一条路

下文命令都在技能根目录执行。仓库里是 `skills/ai-network-setup/`；单独安装后，这个文件夹本身就是根目录。

## 适用谁

任何人。还没回答下面 6 个问题之前，不要改系统，也不要导入模板。

## 先问这 6 个问题

1. 电脑是 macOS、Windows、Linux，还是别的？
2. 手机要一起配吗？不配、iPhone，还是 Android？
3. 现在的客户端是什么？Clash Verge Rev、别的 Clash、Shadowrocket、还没有，或是别的？
4. 这台机器会连公司或学校的 VPN，或者受 MDM / 描述文件管理吗？
5. 你已经有一份订阅（有人把它叫机场），只想让它稳定；还是另外还有一个固定出口账号？
6. 你打算自己点界面，还是让代理只做只读检查、每次写入前都停下来问你？

## 怎么分流

| 答案 | 做什么 |
|---|---|
| Windows、Linux，或只有 Android | **当前未覆盖。** 停在这里。不要把后面的 macOS / iPhone 步骤套过去。进度见仓库 `docs/ROADMAP.md`。 |
| 服务在你所在地区官方不提供 | 停止。本技能不处理这件事。 |
| macOS，已有订阅，想稳定 | [01-path-mac-clash.md](01-path-mac-clash.md)。这是默认路径。 |
| 做完默认路径，还要同一个出口地址 | [02-fixed-exit.md](02-fixed-exit.md)，可选。 |
| iPhone | [03-mobile.md](03-mobile.md)。没有 Mac 也可以只看这一篇。 |
| 要和公司或学校 VPN 共存 | [04-company-vpn.md](04-company-vpn.md) |
| 怀疑 DNS、WebRTC 或 IPv6 把本机地址送了出去 | [05-leak-checks.md](05-leak-checks.md) |
| 想定时看一眼 | [06-monitoring.md](06-monitoring.md) |
| 还没有订阅 | [07-buying.md](07-buying.md)。不想再买的话，用现有订阅做 01。 |
| 已经坏了 | [troubleshooting.md](troubleshooting.md) |

## 只读探测

`[Agent只读]`

```bash
./scripts/probe-env.sh
./scripts/probe-env.sh --json
```

先看这几项：

| 字段 | 用来决定什么 |
|---|---|
| `supported` | 不是 `yes` 就停止 macOS 步骤 |
| `network_service` | 后面的备份、DNS、IPv6 都用这个名字，不要写死 Wi-Fi |
| `listen_ports` | 混合端口。没有就看客户端设置，不要假设 7897 |
| `socket` / `service_mode` | 有没有外部控制，以及像不像 Service 模式 |
| `tun_enable` / `clash_mode` / `enhanced_mode` | 运行时实际状态。`unknown` 表示还没读到 |
| `ai_clients` | 这些进程开着时，先别重载 |
| `config_dir` | 备份从这里拷。不要把里面的 profile 贴出来 |

脚本不访问外网。它只看本机进程、端口和本地 socket。

## 通用红线

所有路径都遵守：

1. 改配置前先备份。路径见下一节。
2. 不打印订阅链接、密码、节点凭据。不 `cat` profiles 目录里的文件。
3. 不禁用、不绕过单位下发的 DNS 安全组件、VPN 客户端、MDM 或浏览器托管策略。
4. `probe-env.sh` 和 `net-check.sh` 只读。会改 DNS 的 `dns-guard.sh` 不是默认步骤。
5. 只在服务官方支持的地区使用。

固定出口才额外遵守的两条（只用订阅的人忽略）：不要把约定流量临时切到别的出口；AI 客户端还连着的时候不要重载或退出 Clash。详见 [02-fixed-exit.md](02-fixed-exit.md)。

重新激活订阅会断开当前连接。这不是红线，但动手前先保存正在做的事。

## 代理必须停下来问的时候

- 操作系统不是 macOS，或用户还没回答上面 6 个问题。
- 要关 IPv6、改 DNS、改系统代理、装开机任务、装浏览器插件。
- 公司电脑，不确定 MDM 允不允许装插件或改网络。
- 需要订阅链接或密码。这些只由用户在界面里填。
- 用户没有固定出口账号，文档却走到了 02。
- 用户说所在地区官方不支持该服务。

## 备份

`[Agent需确认]` 下面的命令只往备份目录里复制，不改 Clash。`config_dir` 和 `network_service` 用刚才 probe 打出来的值。目录不存在就停下来问，不要猜另一个路径。

```bash
STAMP=$(date +%Y%m%d%H%M%S)
DEST="$HOME/Library/Application Support/ai-network-setup-backups/$STAMP"
mkdir -p "$DEST"
CFG="这里换成 probe 的 config_dir"
cp -R "$CFG/profiles" "$DEST/profiles"
cp "$CFG/verge.yaml" "$DEST/verge.yaml"
cp "$CFG/profiles.yaml" "$DEST/profiles.yaml" 2>/dev/null || true
SVC="这里换成 probe 的 network_service"
{
  echo "service=$SVC"
  networksetup -getinfo "$SVC"
  networksetup -getdnsservers "$SVC"
  networksetup -getwebproxy "$SVC"
  networksetup -getsecurewebproxy "$SVC"
  networksetup -getsocksfirewallproxy "$SVC"
  networksetup -getproxybypassdomains "$SVC"
} > "$DEST/networksetup.txt"
if [ -d /etc/resolver ]; then
  mkdir -p "$DEST/resolver"
  cp -R /etc/resolver/. "$DEST/resolver/" 2>/dev/null || true
fi
printf '备份在 %s\n' "$DEST"
```

记住这个 `$DEST`。紧急回退用它，见 [troubleshooting.md](troubleshooting.md)。

## 验证

- pass：6 个问题有答案，`supported` 的结论和所选文档一致，还没改系统。
- fail：还不知道系统或有没有订阅，就已经去改 TUN、DNS 或 IPv6。

## 回滚

这一步如果还没改系统，就没有要回滚的东西。已经改过的，走紧急全回退。
