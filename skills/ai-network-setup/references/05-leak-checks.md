# 5. 泄漏怎么判定

下文命令都在技能根目录执行。这一页给出 pass/fail。关闭 IPv6 和安装浏览器插件都不是默认步骤。

## 适用谁

怀疑本机地址从 DNS、浏览器或 IPv6 绕过了代理的人。还没做完 [01-path-mac-clash.md](01-path-mac-clash.md) 的，先做那一页。

## 先问

- 浏览器是不是公司托管的。MDM 可能禁止安装扩展。用户不同意或策略不允许时，跳过 WebRTC 插件，只做观察，不要关掉设备管理。
- 用户是否同意关闭某一块网卡的 IPv6。这是系统级设置，影响所有程序，不只是 AI 工具。不同意就不要执行关闭命令。

## WebRTC

### 目标

网页里的 WebRTC 不要把这台机器的公网地址暴露给页面。

### 步骤

1. `[Agent需确认]` 先问 MDM。允许的话，由用户在**每个**浏览器配置文件安装官方的 WebRTC Network Limiter（扩展 ID `npeicpdbkakmehahjeeohfdhnlpdklia`）。
2. `[用户UI]` 选项选 “Use my proxy server (if present)”。扩展详情里允许在无痕模式运行。每个配置文件都要做。

### 验证

打开 `https://browserleaks.com/webrtc`。另开一次终端，在**关掉系统代理和 TUN 之后**看本机网络自己的地址，用来对比。对比用的地址不要写进仓库或聊天。

- pass：页面上的 host 候选里没有这台机器的公网地址。`*.local` 这种 mDNS 名字不算公网泄漏。属于代理出口的地址不算本机泄漏。
- fail：页面上出现了和「本机网络自己的地址」相同的公网地址。
- 只装了一个配置文件，或无痕没授权：还不能算 pass。

### 回滚

`[用户UI]` 停用或卸载该扩展。

## IPv6

### 目标

分清「链路本地 / 本机私有地址」「代理的 IPv6」和「运营商分给这台电脑的全局 IPv6」。只有最后一种在 IPv4 已经走代理时算旁路。

### 步骤

`[Agent只读]` 先看，不改：

```bash
SVC="这里换成 probe 的 network_service"
networksetup -getinfo "$SVC"
./scripts/net-check.sh
```

脚本统计全局 IPv6 时已经排除链路本地（`fe80::/10`）、组播和 ULA（`fc00::/7`，也就是 `fc` 和 `fd` 开头）。它看到全局地址时只给 INFO，不会因此失败，也不会去关闭 IPv6。

`[Agent需确认]` 只有用户明确同意后，才对**这一块服务**关闭 IPv6：

```bash
networksetup -setv6off "$SVC"
```

### 验证

- pass：物理网卡上没有全局 IPv6；或者测试页上的 IPv6 属于代理，而不是 `networksetup -getinfo` 里这块网卡的地址。
- fail：物理网卡有全局 IPv6，并且测试页显示的就是这个地址，同时 IPv4 已经走代理。
- ULA 和链路本地不是 fail。

### 回滚

```bash
networksetup -setv6automatic "$SVC"
```

## DNS

### 目标

判断应用的查询是交给了 Clash，还是直接交给了系统里看到的那台解析器。系统 DNS 显示成某一个公共地址，本身既不是 pass 也不是 fail。

### 步骤

`[Agent只读]`

1. 看系统解析器：

```bash
networksetup -getdnsservers "$SVC"
```

2. 看 Clash 的运行时模式。`./scripts/probe-env.sh` 里的 `enhanced_mode` 和 `fake_ip_range`，或 `./scripts/net-check.sh` 的对应 INFO。
3. 若模式是 fake-ip，向**探测到的**监听地址查询一个名字。监听地址用 `FAKEIP_SERVER`。没探测到之前，不要假设是 `198.18.0.2`。

```bash
dig +short +time=2 +tries=1 @"$FAKEIP_SERVER" example.com
dig +short example.com
```

把 `example.com` 换成你真正想检查的、且不在 fake-ip 过滤名单里的名字。过滤名单里的名字返回真实地址是预期行为。

### 114.114.114.114 以及任何公共 DNS

系统 DNS 里出现 `114.114.114.114`、`1.1.1.1`、`8.8.8.8` 或 `223.5.5.5`，只说明系统解析器被写成了这个地址。

- 若 enhanced-mode 是 fake-ip，向 fake-ip 监听地址查询得到 `198.18.*` 或 `198.19.*`，并且 TUN 的 dns-hijack 包含 `any:53`：应用的查询由代理处理。这时系统里的公共 DNS 更像占位。这是 pass。
- 若不指定 `@` 的 `dig` 得到了公网 A/AAAA，而你预期这个名字应返回 fake-ip：这是 fail。去查 TUN 是否开启、dns-hijack 是否还在、这个名字是否在过滤名单里。
- 模式是 redir-host 时，不要用「是不是 198.18」来判定。看查询最终是否只经过你配置的解析器，而不是你没打算使用的那一台。

### 验证汇总

| 检查 | pass | fail |
|---|---|---|
| WebRTC | 页面没有本机公网地址 | 页面出现本机公网地址 |
| IPv6 | 物理网卡无全局地址，或测试页上的地址属于代理 | 物理网卡的全局地址出现在测试页 |
| DNS | fake-ip 名字返回 198.18/198.19，或 redir-host 下查询走你指定的解析器 | 预期 fake-ip 的名字直接返回公网地址 |

## 常见坑

- 把系统 DNS 上的 `114.114.114.114` 直接说成正常。
- 没问用户就关闭 IPv6。
- 公司浏览器装不上插件时，去关 MDM。

## 回滚

插件卸载。IPv6 用 `-setv6automatic`。DNS 用备份或 `networksetup -setdnsservers "$SVC" Empty` 回到网络分配的解析器。完整步骤在 [troubleshooting.md](troubleshooting.md)。
