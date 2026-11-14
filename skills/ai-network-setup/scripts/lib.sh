# shellcheck shell=bash
# 只读小函数，给 net-check.sh / probe-env.sh 用。不含任何个人默认值。
# 需要被 source。兼容 macOS 自带的 bash 3.2。

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  printf '%s\n' "lib.sh 需要被 source，不能直接执行。" >&2
  exit 2
fi

# 打印可安全执行的 python3 路径。找不到则返回 1。
# 绝不执行 macOS 上会弹出「安装命令行开发者工具」的 /usr/bin/python3 占位程序。
python3_bin() {
  local p
  p=$(command -v python3 2>/dev/null || true)
  if [ -z "$p" ]; then
    return 1
  fi
  case "$(uname -s)" in
    Darwin)
      if [ "$p" = "/usr/bin/python3" ]; then
        if ! xcode-select -p >/dev/null 2>&1; then
          return 1
        fi
      fi
      ;;
  esac
  printf '%s\n' "$p"
}

# 按字节做百分号编码，避免把组名拼进 python 代码。
urlencode() {
  local out py
  if command -v perl >/dev/null 2>&1; then
    out=$(printf '%s' "$1" | perl -ne 's/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge; print') || return 1
    printf '%s' "$out"
    return 0
  fi
  if py=$(python3_bin); then
    "$py" -c 'import urllib.parse,sys; sys.stdout.write(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
    return 0
  fi
  return 1
}

# 打印网络服务名。调用方设置了 NETWORK_SERVICE 时尊重它。
# 否则用默认路由对应的服务（含「无线局域网」、USB 网卡、扩展坞），再退回到第一块有 IPv4 的启用服务。
detect_network_service() {
  if [ -n "${NETWORK_SERVICE:-}" ]; then
    printf '%s\n' "$NETWORK_SERVICE"
    return 0
  fi
  if ! command -v networksetup >/dev/null 2>&1; then
    return 1
  fi
  local dev svc list candidate info
  dev=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')
  case "${dev:-}" in
    ""|*[!A-Za-z0-9]*) dev="" ;;
  esac
  if [ -n "$dev" ]; then
    svc=$(networksetup -listnetworkserviceorder 2>/dev/null | awk -v dev="$dev" '
      BEGIN { disabled="yes"; name="" }
      /^\([*0-9]+\) / {
        name = $0
        sub(/^\([*0-9]+\) /, "", name)
        disabled = ($0 ~ /^\(\*/) ? "yes" : "no"
      }
      index($0, "Device: " dev ")") && disabled == "no" {
        print name
        exit
      }
    ')
    if [ -n "${svc:-}" ]; then
      printf '%s\n' "$svc"
      return 0
    fi
  fi
  list=$(networksetup -listallnetworkservices 2>/dev/null | awk 'NR>1 && $0 !~ /^\*/ {print}')
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    info=$(networksetup -getinfo "$candidate" 2>/dev/null || true)
    if printf '%s\n' "$info" | awk 'BEGIN{ok=0} /^IP address:/{if ($3 ~ /^[0-9]+\./) ok=1} END{exit !ok}'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <<EOF
$list
EOF
  return 1
}

# 打印第一个存在的 mihomo/Clash unix socket。不读取配置正文。
first_existing_socket() {
  local uid c
  uid=$(id -u)
  for c in \
    "/var/run/clash-verge-service/users/${uid}/verge-mihomo.sock" \
    "/tmp/verge/verge-mihomo.sock" \
    "${HOME}/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge-mihomo.sock"
  do
    if [ -S "$c" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

# 常见本地混合端口。只看本机监听，不是全端口扫描。没装 lsof 时返回 1。
list_listen_ports() {
  local p
  if ! command -v lsof >/dev/null 2>&1; then
    return 1
  fi
  for p in 7890 7897 7891 7892 7893 1080 1087; do
    if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
      printf '%s\n' "$p"
    fi
  done
  return 0
}

# 返回 0 表示这个地址不应当算作「全局 IPv6」（链路本地、ULA、组播、回环）。
skip_v6() {
  local low
  low=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$low" in
    ""|::1)
      return 0
      ;;
    fe8*|fe9*|fea*|feb*)
      return 0
      ;;
    fc*|fd*)
      return 0
      ;;
    ff*|::ffff:*)
      return 0
      ;;
  esac
  return 1
}

# 打印全局 IPv6 数量；没有 ip/ifconfig 时打印 NO_TOOL。标准输出只有这一行。
count_global_ipv6() {
  local n=0 addr bare addrs
  n=0
  if command -v ip >/dev/null 2>&1; then
    addrs=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2}')
  elif command -v ifconfig >/dev/null 2>&1; then
    addrs=$(ifconfig 2>/dev/null | awk '/inet6 /{print $2}')
  else
    printf '%s\n' "NO_TOOL"
    return 0
  fi
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    bare=${addr%%%*}
    bare=${bare%%/*}
    if skip_v6 "$bare"; then
      continue
    fi
    n=$((n + 1))
  done <<EOF
$addrs
EOF
  printf '%s\n' "$n"
}
