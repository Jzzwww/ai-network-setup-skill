#!/usr/bin/env bash
# dns-guard.sh — 可选。把某一块网卡的 DNS 保持成你指定的值。
#
# 默认路径用不到它。只有「公司或学校 VPN 反复改写 DNS，导致该解析的名字失败」时才考虑。
# 它会修改系统 DNS，影响这块网卡上的所有程序。它不关闭、不绕过任何安全软件。
#
# 风险:
#   - 和 VPN / 描述文件来回覆盖 DNS
#   - 间隔太短会一直抢设置。配套 plist 的示例是 300 秒，不要改成数秒一次
#   - 第一次 --apply 时如果 DNS 已经是错的，备份下来的也是错的。
#     请在 DNS 仍正常时先跑 --backup-only
#
# 没有 NETWORK_SERVICE 和明确的 DNS_SERVERS 时，--apply 直接退出，不改任何东西。
# 仍含 REPLACE_ME 或尖括号时拒绝执行。
#
# 用法:
#   NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --status
#   NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --backup-only
#   NETWORK_SERVICE='无线局域网' DNS_SERVERS='1.1.1.1 8.8.8.8' ./scripts/dns-guard.sh --apply
#   NETWORK_SERVICE='无线局域网' ./scripts/dns-guard.sh --restore
#
# 卸载见 references/04-company-vpn.md。兼容 macOS 自带 bash 3.2。

set -u

usage() {
  cat <<'EOF'
用法: NETWORK_SERVICE=<服务名> [DNS_SERVERS='<解析地址...>'] ./scripts/dns-guard.sh <动作>

动作:
  --status       只查看（默认）。不修改 DNS
  --backup-only  把当前 DNS 写入备份。不修改 DNS。会覆盖上一份备份
  --apply        仅当当前值与 DNS_SERVERS 不同时写系统 DNS
  --restore      按备份恢复
  -h, --help     显示这段说明

DNS 服务器请换成你自己的网络里该用的地址。示例只是公共解析服务，不是默认要求:
  1.1.1.1  8.8.8.8  223.5.5.5
备份目录:
  ~/Library/Application Support/ai-network-setup-backups/dns-guard/
EOF
}

die() {
  printf 'dns-guard: %s\n' "$*" >&2
  exit 2
}

ACTION=status
case "${1:-}" in
  ""|--status) ACTION=status ;;
  --backup-only) ACTION=backup ;;
  --apply) ACTION=apply ;;
  --restore) ACTION=restore ;;
  -h|--help) usage; exit 0 ;;
  *)
    usage >&2
    die "未知参数: $1"
    ;;
esac

if ! command -v networksetup >/dev/null 2>&1; then
  die "未找到 networksetup。此可选工具只适用于 macOS，本次没有修改任何设置。"
fi

NETWORK_SERVICE="${NETWORK_SERVICE:-}"
DNS_SERVERS="${DNS_SERVERS:-}"
if [ -z "$NETWORK_SERVICE" ]; then
  die "缺少 NETWORK_SERVICE。请先跑 probe-env.sh，把打印出的网络服务名原样填上。本次没有修改任何设置。"
fi
case "$NETWORK_SERVICE" in
  -*|*"REPLACE_ME"*|*"<"*|*">"*)
    die "NETWORK_SERVICE 不合法或仍是占位符。本次没有修改任何设置。"
    ;;
esac

backup_file() {
  local safe
  safe=$(printf '%s' "$NETWORK_SERVICE" | tr ' /' '__')
  printf '%s\n' "${HOME}/Library/Application Support/ai-network-setup-backups/dns-guard/${safe}.txt"
}

current_dns_text() {
  networksetup -getdnsservers "$NETWORK_SERVICE" 2>/dev/null || true
}

is_empty_dns() {
  printf '%s\n' "$1" | grep -qi "aren't any DNS"
}

write_backup() {
  local overwrite="$1"
  local dest dir current tmp
  dest=$(backup_file)
  dir=$(dirname -- "$dest")
  mkdir -p "$dir" || die "无法创建备份目录"
  if [ -f "$dest" ] && [ "$overwrite" != "yes" ]; then
    printf '%s\n' "$dest"
    return 0
  fi
  current=$(current_dns_text)
  tmp="${dest}.tmp"
  {
    printf 'service=%s\n' "$NETWORK_SERVICE"
    if is_empty_dns "$current"; then
      printf '%s\n' "mode=empty"
    else
      printf '%s\n' "mode=servers"
      printf '%s\n' "$current"
    fi
  } > "$tmp"
  mv "$tmp" "$dest"
  printf '%s\n' "$dest"
}

validate_servers() {
  local item
  if [ -z "$DNS_SERVERS" ]; then
    die "缺少 DNS_SERVERS。本次没有修改任何设置。"
  fi
  case "$DNS_SERVERS" in
    *"REPLACE_ME"*|*"<"*|*">"*|*[';|$`']*)
      die "DNS_SERVERS 仍是占位符或含拒绝的字符。本次没有修改任何设置。"
      ;;
  esac
  # shellcheck disable=SC2086
  set -f
  # shellcheck disable=SC2086
  set -- $DNS_SERVERS
  set +f
  if [ "$#" -eq 0 ]; then
    die "DNS_SERVERS 为空。本次没有修改任何设置。"
  fi
  for item in "$@"; do
    case "$item" in
      ""|-*|*[!A-Za-z0-9.:_-]*)
        die "拒绝这个 DNS 项: ${item}。本次没有修改任何设置。"
        ;;
    esac
  done
  SAVED_SERVERS="$*"
}

case "$ACTION" in
  status)
    dest=$(backup_file)
    printf 'service=%s\n' "$NETWORK_SERVICE"
    printf 'current=%s\n' "$(current_dns_text | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    if [ -n "$DNS_SERVERS" ]; then
      printf 'desired=%s\n' "$DNS_SERVERS"
    else
      printf '%s\n' "desired=(未设置，--status 不会修改)"
    fi
    if [ -f "$dest" ]; then
      printf 'backup=%s\n' "$dest"
    else
      printf '%s\n' "backup=(无)"
    fi
    ;;
  backup)
    dest=$(write_backup yes)
    printf 'dns-guard: 已备份当前 DNS，未修改系统。%s\n' "$dest"
    ;;
  apply)
    validate_servers
    current=$(current_dns_text | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    if ! is_empty_dns "$current" && [ "$current" = "$SAVED_SERVERS" ]; then
      printf 'dns-guard: unchanged\n'
      exit 0
    fi
    dest=$(write_backup no)
    printf 'dns-guard: 备份位于 %s\n' "$dest"
    # shellcheck disable=SC2086
    set -f
    # shellcheck disable=SC2086
    set -- $SAVED_SERVERS
    set +f
    networksetup -setdnsservers "$NETWORK_SERVICE" "$@"
    printf 'dns-guard: 已写入 %s\n' "$NETWORK_SERVICE"
    ;;
  restore)
    dest=$(backup_file)
    if [ ! -f "$dest" ]; then
      die "没有备份 ${dest}。本次没有修改任何设置。"
    fi
    header=$(sed -n '1p' "$dest")
    mode=$(sed -n '2p' "$dest")
    if [ "$header" != "service=${NETWORK_SERVICE}" ]; then
      die "备份里的服务名与 NETWORK_SERVICE 不一致。本次没有修改任何设置。"
    fi
    case "$mode" in
      mode=empty)
        networksetup -setdnsservers "$NETWORK_SERVICE" Empty
        ;;
      mode=servers)
        servers=$(awk 'NR>2 && NF {print}' "$dest" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        DNS_SERVERS=$servers
        validate_servers
        # shellcheck disable=SC2086
        set -f
        # shellcheck disable=SC2086
        set -- $SAVED_SERVERS
        set +f
        networksetup -setdnsservers "$NETWORK_SERVICE" "$@"
        ;;
      *)
        die "备份格式无法识别。本次没有修改任何设置。"
        ;;
    esac
    printf 'dns-guard: 已按备份恢复 %s\n' "$NETWORK_SERVICE"
    ;;
esac
