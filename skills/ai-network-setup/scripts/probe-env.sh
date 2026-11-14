#!/usr/bin/env bash
# probe-env.sh — 只读环境探测。不修改配置，不读取订阅正文，不访问外网。
# 用法（在技能根目录）:
#   ./scripts/probe-env.sh
#   ./scripts/probe-env.sh --json
# 兼容 macOS 自带 bash 3.2。

set -u

SCRIPT_DIR=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
if [ ! -f "$SCRIPT_DIR/lib.sh" ]; then
  printf '%s\n' "缺少 ${SCRIPT_DIR}/lib.sh" >&2
  exit 2
fi
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

JSON=0

usage() {
  cat <<'EOF'
用法: ./scripts/probe-env.sh [--json]

只读。查看操作系统、网络服务名、本机代理端口、Clash/mihomo 是否在跑、
unix socket、Service 模式迹象、TUN、常见 AI 客户端进程名。

不访问外网，不 cat 订阅 profile（里面有节点凭据），不改系统设置。
macOS 上若没有可用的 python3，不会去运行会弹出「安装命令行开发者工具」的占位解释器。

--json  结果只打到标准输出，需要可用的 python3。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf '未知参数: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$JSON" -eq 1 ]; then
  if ! python3_bin >/dev/null; then
    printf '%s\n' "probe-env: --json 需要可用的 python3。未调用可能弹出安装窗口的 macOS 占位解释器。" >&2
    exit 3
  fi
fi

umask 077
TMPS=$(mktemp -d "${TMPDIR:-/tmp}/probe-env.XXXXXX") || exit 2
trap 'rm -rf "$TMPS"' EXIT
CHECKS="$TMPS/checks.tsv"
: > "$CHECKS"

note() {
  local level="$1"
  shift
  local msg="$*"
  msg=${msg//$'\t'/ }
  printf 'NOTE\t%s\t%s\n' "$level" "$msg" >> "$CHECKS"
  if [ "$JSON" -eq 0 ]; then
    printf '[%s] %s\n' "$level" "$msg"
  fi
}

fact() {
  local key="$1"
  shift
  local val="$*"
  val=${val//$'\t'/ }
  printf 'FACT\t%s\t%s\n' "$key" "$val" >> "$CHECKS"
  if [ "$JSON" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$val"
  fi
}

emit_json() {
  local py
  py=$(python3_bin) || return 1
  "$py" - "$CHECKS" <<'PY'
import json, sys
facts = {}
notes = []
with open(sys.argv[1], encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        kind, _, rest = line.partition("\t")
        if kind == "FACT":
            key, _, val = rest.partition("\t")
            facts[key] = val
        elif kind == "NOTE":
            level, _, detail = rest.partition("\t")
            notes.append({"level": level, "detail": detail})
supported = facts.get("supported") == "yes"
out = {"supported": supported, "external_http": False, "facts": facts, "notes": notes}
json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
PY
}

collect_procs() {
  local kind="$1"
  ps -ax -o comm= 2>/dev/null | while IFS= read -r c; do
    base=${c##*/}
    low=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    case "$kind" in
      clash)
        case "$low" in
          *clash*|*mihomo*|*verge*) printf '%s\n' "$base" ;;
        esac
        ;;
      ai)
        case "$low" in
          *claude*|*chatgpt*|*codex*|*cursor*) printf '%s\n' "$base" ;;
        esac
        ;;
    esac
  done | sort -u | awk 'BEGIN{s=""} NF{s=s (s?",":"") $0} END{if (s!="") print s}'
}

http_code() {
  local out="$1"
  local url="$2"
  shift 2
  : > "$out"
  curl -sS -m 5 --connect-timeout 3 --path-as-is -o "$out" -w '%{http_code}' "$@" "$url" 2>"$TMPS/curl.err" || true
}

if [ "$JSON" -eq 0 ]; then
  printf '%s\n' "== probe-env =="
fi

OS_NAME=$(uname -s)
fact os "$OS_NAME"
if [ "$OS_NAME" = "Darwin" ]; then
  fact os_version "$(sw_vers -productVersion 2>/dev/null || uname -r)"
  fact supported yes
else
  fact os_version "$(uname -r)"
  fact supported no
  note INFO "当前系统是 ${OS_NAME}。Windows、Linux、Android 的配置步骤都还没写，请停在这里，不要把 macOS 步骤套过去。"
fi
fact external_http no

if command -v curl >/dev/null 2>&1; then
  fact tool_curl yes
else
  fact tool_curl no
  note INFO "未找到 curl。稍后的 net-check 无法做连通探测。"
fi
if command -v dig >/dev/null 2>&1; then
  fact tool_dig yes
else
  fact tool_dig no
  note INFO "未找到 dig。fake-ip 探测会跳过。请自行安装 dig，本脚本不会打开系统安装窗。"
fi
if python3_bin >/dev/null; then
  fact tool_python3 yes
else
  fact tool_python3 no
  note INFO "没有可用的 python3。已避免运行 macOS 占位解释器。分组 JSON 会退化为简化解析，--json 不可用。"
fi
if command -v perl >/dev/null 2>&1; then
  fact tool_perl yes
else
  fact tool_perl no
fi
if command -v lsof >/dev/null 2>&1; then
  fact tool_lsof yes
else
  fact tool_lsof no
  note INFO "未找到 lsof，不能列出本机监听端口。"
fi
if command -v networksetup >/dev/null 2>&1; then
  fact tool_networksetup yes
else
  fact tool_networksetup no
fi

IFACE=""
if [ "$OS_NAME" = "Darwin" ]; then
  IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')
elif command -v ip >/dev/null 2>&1; then
  IFACE=$(ip route show default 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
fi
if [ -n "$IFACE" ]; then
  fact default_interface "$IFACE"
else
  fact default_interface none
fi

SVC=$(detect_network_service || true)
if [ -n "$SVC" ]; then
  fact network_service "$SVC"
else
  fact network_service none
  note INFO "没有识别到网络服务名。可设置 NETWORK_SERVICE（例如 Wi-Fi、Ethernet、无线局域网、USB 10/100/1000 LAN）。不要假设一定叫 Wi-Fi。"
fi

if command -v lsof >/dev/null 2>&1; then
  PORTS=$(list_listen_ports || true)
  if [ -n "$PORTS" ]; then
    ports_one=$(printf '%s\n' "$PORTS" | paste -sd, -)
    fact listen_ports "$ports_one"
    note INFO "在常见端口看到监听: ${ports_one}。混合端口以这个结果或客户端设置为准，不要默认写成 7897。"
  else
    fact listen_ports none
    note INFO "常见混合端口上没有监听。Clash 可能没开，或端口不在探测列表里。请看客户端设置。"
  fi
else
  fact listen_ports none
fi

CLASH_PROCS=$(collect_procs clash || true)
if [ -n "$CLASH_PROCS" ]; then
  fact clash_processes "$CLASH_PROCS"
else
  fact clash_processes none
fi

AI_PROCS=$(collect_procs ai || true)
if [ -n "$AI_PROCS" ]; then
  fact ai_clients "$AI_PROCS"
  note INFO "根据进程名看到: ${AI_PROCS}。这只说明程序开着。改配置前建议先退出，避免当前会话被重载打断。"
else
  fact ai_clients none
fi

SOCK=""
if [ -n "${CLASH_SOCK:-}" ]; then
  if [ -S "$CLASH_SOCK" ]; then
    SOCK=$CLASH_SOCK
  else
    note INFO "环境变量 CLASH_SOCK 不是套接字，已忽略: ${CLASH_SOCK}"
  fi
else
  SOCK=$(first_existing_socket || true)
fi

VER=unknown
TUN_ENABLE=unknown
TUN_STACK=unknown
DNS_HIJACK=unknown
CLASH_MODE=unknown
ENHANCED_MODE=unknown
FAKE_RANGE=unknown
SERVICE_MODE=no

if [ -n "$SOCK" ] && [ -S "$SOCK" ]; then
  fact socket "$SOCK"
  case "$SOCK" in
    /var/run/clash-verge-service/*)
      SERVICE_MODE=yes
      note INFO "socket 位于 clash-verge-service，通常表示开了 Service 模式。"
      ;;
    *)
      SERVICE_MODE=unknown
      note INFO "找到 socket，但路径不像 Service 模式的默认位置。以客户端设置为准。"
      ;;
  esac
  if command -v curl >/dev/null 2>&1; then
    code=$(http_code "$TMPS/version.json" "http://localhost/version" --unix-socket "$SOCK")
    code=${code//$'\r'/}
    code=${code//$'\n'/}
    if [ "$code" = "200" ]; then
      ver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMPS/version.json" | head -1)
      if [ -n "$ver" ]; then
        VER=$ver
      fi
    elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
      note INFO "本地接口返回 HTTP ${code}。本脚本不读取密钥，也不打印响应正文。"
    fi

    code=$(http_code "$TMPS/configs.json" "http://localhost/configs" --unix-socket "$SOCK")
    code=${code//$'\r'/}
    code=${code//$'\n'/}
    if [ "$code" = "200" ]; then
      py=$(python3_bin || true)
      if [ -n "$py" ]; then
        parsed=$("$py" - "$TMPS/configs.json" <<'PY' || true
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
tun = d.get("tun") or {}
dns = d.get("dns") or {}
hij = tun.get("dns-hijack") or []
if isinstance(hij, list):
    hij = ",".join(str(x) for x in hij)
else:
    hij = str(hij)
def s(v):
    return "" if v is None else str(v)
print("\t".join([
    s(tun.get("enable")),
    s(tun.get("stack")),
    hij,
    s(d.get("mode")),
    s(dns.get("enhanced-mode")),
    s(dns.get("fake-ip-range")),
]))
PY
)
        if [ -n "$parsed" ]; then
          TUN_ENABLE=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
          TUN_STACK=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')
          DNS_HIJACK=$(printf '%s' "$parsed" | awk -F '\t' '{print $3}')
          CLASH_MODE=$(printf '%s' "$parsed" | awk -F '\t' '{print $4}')
          ENHANCED_MODE=$(printf '%s' "$parsed" | awk -F '\t' '{print $5}')
          FAKE_RANGE=$(printf '%s' "$parsed" | awk -F '\t' '{print $6}')
        fi
      else
        note INFO "有运行时配置，但没有可用的 python3，跳过 TUN/DNS 字段解析。"
      fi
    fi
  fi
else
  fact socket none
  note INFO "没有找到 Clash/mihomo 的 unix socket。可能还没安装、没运行，或没开外部控制。"
fi

fact service_mode "$SERVICE_MODE"
fact version "$VER"
fact tun_enable "${TUN_ENABLE:-unknown}"
fact tun_stack "${TUN_STACK:-unknown}"
fact dns_hijack "${DNS_HIJACK:-unknown}"
fact clash_mode "${CLASH_MODE:-unknown}"
fact enhanced_mode "${ENHANCED_MODE:-unknown}"
fact fake_ip_range "${FAKE_RANGE:-unknown}"

V6=$(count_global_ipv6)
fact global_ipv6 "$V6"
if [ "$V6" = "NO_TOOL" ]; then
  note INFO "没有 ip 或 ifconfig，跳过 IPv6 统计。"
elif [ "$V6" != "0" ]; then
  note INFO "看到 ${V6} 个全局 IPv6（已排除链路本地和 ULA）。这还不是泄漏结论，见 references/05-leak-checks.md。"
fi

CONFIG_DIR=none
for d in \
  "${HOME}/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev" \
  "${HOME}/Library/Application Support/clash-verge"
do
  if [ -d "$d" ]; then
    CONFIG_DIR=$d
    break
  fi
done
fact config_dir "$CONFIG_DIR"
if [ "$CONFIG_DIR" != "none" ]; then
  note INFO "配置目录: ${CONFIG_DIR} 。备份可以复制这个目录里的 profiles 与 verge.yaml。不要把 profile 内容贴到聊天。"
fi

if [ "$JSON" -eq 1 ]; then
  emit_json || exit 3
fi
exit 0
