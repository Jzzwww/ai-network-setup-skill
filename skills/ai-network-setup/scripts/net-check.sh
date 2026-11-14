#!/usr/bin/env bash
# net-check.sh — 只读巡检。不改配置，不重载 Clash，不打印凭据或接口原文。
#
# 会向下面这些地址发起出站请求（可用环境变量换成你信任的探测地址）:
#   TRACE_URL     默认 https://1.1.1.1/cdn-cgi/trace     看 ip/loc/colo
#   IP_ECHO_URL   默认 https://api.ipify.org             经混合端口再看一次地址
#   DELAY_URL     默认 http://www.gstatic.com/generate_204
#                 由本机 Clash 对 AI-EXIT 的成员做延迟测试，目标站点能看到对应出口
#
# 用法（在技能根目录）:
#   ./scripts/net-check.sh
#   ./scripts/net-check.sh --json
#   EXPECTED_IP=<固定出口地址> ./scripts/net-check.sh
#
# 未设置 EXPECTED_IP 时，不要求出口等于某一个地址（订阅模式的正常情况）。
# 组不存在是 FAIL。dns-guard 没装是 INFO，不是故障。
# 退出码: 0 无 FAIL/WARN，1 有 WARN，2 有 FAIL，3 --json 但没有可用的 python3。
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
FAIL=0
WARN=0
INFO=0

usage() {
  cat <<'EOF'
用法: ./scripts/net-check.sh [--json]

只读巡检。环境变量（都可选）:
  EXPECTED_IP       固定出口模式才设置。不设则不比较地址是否固定
  EXPECTED_COLO     可选，回显里的机房代码，用来发现路径被换掉
  GROUP             默认 AI-EXIT
  PROXY_PORT        不设则从系统代理或常见监听端口探测，不要假设 7897
  CLASH_SOCK        不设则查找本机常见 unix socket
  NETWORK_SERVICE   不设则按默认路由识别，兼容有线、扩展坞、无线局域网
  BYPASS_DOMAINS    空格分隔。不设则跳过 bypass 核对
  TRACE_URL IP_ECHO_URL DELAY_URL DNS_PROBE_NAME FAKEIP_SERVER
  MAX_DELAY_CHECKS  默认 20，0 表示不做延迟探测

--json  只向标准输出打印 JSON，需要可用的 python3。
EOF
}

note() {
  local level="$1"
  shift
  local msg="$*"
  msg=${msg//$'\t'/ }
  printf '%s\t%s\n' "$level" "$msg" >> "$CHECKS"
  if [ "$JSON" -eq 0 ]; then
    printf '[%s] %s\n' "$level" "$msg"
  fi
  case "$level" in
    FAIL) FAIL=$((FAIL + 1)) ;;
    WARN) WARN=$((WARN + 1)) ;;
    INFO) INFO=$((INFO + 1)) ;;
    OK) ;;
    *) ;;
  esac
}

finish() {
  local code=0
  if [ "$FAIL" -ne 0 ]; then
    code=2
  elif [ "$WARN" -ne 0 ]; then
    code=1
  fi
  if [ "$JSON" -eq 1 ]; then
    GENERATED_AT=$(date '+%Y-%m-%dT%H:%M:%S%z')
    if ! FAIL="$FAIL" WARN="$WARN" INFO="$INFO" GENERATED_AT="$GENERATED_AT" \
      python3_bin >/dev/null; then
      exit 3
    fi
    py=$(python3_bin)
    FAIL="$FAIL" WARN="$WARN" INFO="$INFO" GENERATED_AT="$GENERATED_AT" \
      "$py" - "$CHECKS" <<'PY' || exit 3
import json, os, sys
rows = []
with open(sys.argv[1], encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        level, _, detail = line.partition("\t")
        rows.append({"level": level, "detail": detail})
out = {
    "time": os.environ.get("GENERATED_AT", ""),
    "fail": int(os.environ.get("FAIL", "0")),
    "warn": int(os.environ.get("WARN", "0")),
    "info": int(os.environ.get("INFO", "0")),
    "checks": rows,
}
json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
PY
  else
    printf '== 结果: FAIL=%s WARN=%s INFO=%s ==\n' "$FAIL" "$WARN" "$INFO"
  fi
  exit "$code"
}

require_http_url() {
  local value="$1"
  local name="$2"
  case "$value" in
    http://*|https://*) ;;
    *)
      note FAIL "${name} 必须以 http:// 或 https:// 开头"
      finish
      ;;
  esac
  case "$value" in
    *[[:space:]]*)
      note FAIL "${name} 含空白，已拒绝"
      finish
      ;;
  esac
}

http_code() {
  local out="$1"
  local url="$2"
  shift 2
  : > "$out"
  curl -sS -m 12 --connect-timeout 5 --path-as-is -o "$out" -w '%{http_code}' "$@" "$url" 2>"$TMPS/curl.err" || true
}

parse_trace_file() {
  local file="$1"
  local ip colo loc plain
  ip=$(sed -n 's/^ip=//p' "$file" | head -1)
  colo=$(sed -n 's/^colo=//p' "$file" | head -1)
  loc=$(sed -n 's/^loc=//p' "$file" | head -1)
  if [ -z "$ip" ]; then
    plain=$(tr -d '[:space:]' < "$file" | head -c 80)
    case "$plain" in
      [0-9]*.[0-9]*.[0-9]*.[0-9]*|*:*)
        ip=$plain
        ;;
    esac
  fi
  printf '%s\t%s\t%s\n' "$ip" "$colo" "$loc"
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
    printf '%s\n' "net-check: --json 需要可用的 python3。未调用可能弹出安装窗口的 macOS 占位解释器。" >&2
    exit 3
  fi
fi

umask 077
TMPS=$(mktemp -d "${TMPDIR:-/tmp}/net-check.XXXXXX") || exit 2
trap 'rm -rf "$TMPS"' EXIT
CHECKS="$TMPS/checks.tsv"
: > "$CHECKS"

GROUP="${GROUP:-AI-EXIT}"
TRACE_URL="${TRACE_URL:-https://1.1.1.1/cdn-cgi/trace}"
IP_ECHO_URL="${IP_ECHO_URL:-https://api.ipify.org}"
DELAY_URL="${DELAY_URL:-http://www.gstatic.com/generate_204}"
DNS_PROBE_NAME="${DNS_PROBE_NAME:-example.com}"
EXPECTED_IP="${EXPECTED_IP:-}"
EXPECTED_COLO="${EXPECTED_COLO:-}"
case "${MAX_DELAY_CHECKS:-20}" in
  ""|*[!0-9]*) MAX_DELAY_CHECKS=20 ;;
  *) MAX_DELAY_CHECKS=${MAX_DELAY_CHECKS:-20} ;;
esac

if [ "$JSON" -eq 0 ]; then
  printf '== net-check %s ==\n' "$(date '+%F %T %Z')"
fi

note INFO "只读巡检，不改配置、不重载。出站请求：TRACE_URL=${TRACE_URL} ；IP_ECHO_URL=${IP_ECHO_URL} ；DELAY_URL=${DELAY_URL}（经本地 Clash 测分组成员）。这些服务能看到出口地址。"

if ! command -v curl >/dev/null 2>&1; then
  note FAIL "未找到 curl，无法探测。请先安装 curl。本脚本不会触发 macOS 命令行工具安装窗。"
  finish
fi

require_http_url "$TRACE_URL" "TRACE_URL"
require_http_url "$IP_ECHO_URL" "IP_ECHO_URL"
require_http_url "$DELAY_URL" "DELAY_URL"

SVC=$(detect_network_service || true)
if [ -n "$SVC" ]; then
  note INFO "网络服务: ${SVC}"
else
  note INFO "没有识别到网络服务名，跳过系统代理、bypass 和该服务的 IPv6 模式。可设置 NETWORK_SERVICE（Wi-Fi、Ethernet、无线局域网、USB 网卡等）。"
fi

PORT="${PROXY_PORT:-}"
if [ -n "$PORT" ]; then
  case "$PORT" in
    *[!0-9]*)
      note FAIL "PROXY_PORT 不是纯数字: ${PORT}"
      finish
      ;;
  esac
else
  if [ -n "$SVC" ] && command -v networksetup >/dev/null 2>&1; then
    proxy_out=$(networksetup -getwebproxy "$SVC" 2>/dev/null || true)
    enabled=$(printf '%s\n' "$proxy_out" | awk -F': ' '/^Enabled:/{print $2; exit}')
    detected=$(printf '%s\n' "$proxy_out" | awk -F': ' '/^Port:/{print $2; exit}')
    if [ "$enabled" = "Yes" ] && [ -n "$detected" ]; then
      PORT=$detected
      note INFO "从系统代理读到端口 ${PORT}（服务 ${SVC}）。"
    fi
  fi
  if [ -z "$PORT" ] && command -v lsof >/dev/null 2>&1; then
    PORT=$(list_listen_ports | head -1)
    if [ -n "$PORT" ]; then
      note INFO "从本机监听推断混合端口 ${PORT}。若不对，请设置 PROXY_PORT。"
    fi
  fi
fi

SOCK=""
if [ -n "${CLASH_SOCK:-}" ]; then
  if [ -S "$CLASH_SOCK" ]; then
    SOCK=$CLASH_SOCK
  else
    note WARN "CLASH_SOCK 不是套接字: ${CLASH_SOCK}"
  fi
else
  SOCK=$(first_existing_socket || true)
fi

report_trace() {
  local mode="$1"
  local ip="$2"
  local colo="$3"
  local loc="$4"
  if [ -z "$ip" ]; then
    note FAIL "trace(${mode}) 无响应。探测地址是 ${TRACE_URL} 。确认客户端已运行，或更换 TRACE_URL。"
    return
  fi
  if [ -n "$EXPECTED_IP" ] && [ "$ip" != "$EXPECTED_IP" ]; then
    note FAIL "trace(${mode}) 出口 ${ip} 与 EXPECTED_IP 不一致（loc=${loc:-?} colo=${colo:-?}）。"
    return
  fi
  if [ -n "$EXPECTED_COLO" ] && [ -n "$colo" ] && [ "$colo" != "$EXPECTED_COLO" ]; then
    note WARN "trace(${mode}) colo=${colo} 与 EXPECTED_COLO=${EXPECTED_COLO} 不一致。"
    return
  fi
  if [ -n "$EXPECTED_IP" ]; then
    note OK "trace(${mode}) ip=${ip} 与期望一致 loc=${loc:-?} colo=${colo:-?}"
  else
    note OK "trace(${mode}) ip=${ip} loc=${loc:-?} colo=${colo:-?}（未设置 EXPECTED_IP，不要求固定地址）"
  fi
}

IP_PROXY=""
IP_DIRECT=""
if [ -z "$PORT" ]; then
  note FAIL "未能确定混合端口，跳过经代理的探测。请设置 PROXY_PORT。不要假设是 7897。"
else
  code=$(http_code "$TMPS/trace-proxy.txt" "$TRACE_URL" -x "http://127.0.0.1:${PORT}")
  parsed=$(parse_trace_file "$TMPS/trace-proxy.txt")
  IP_PROXY=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
  COLO_PROXY=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')
  LOC_PROXY=$(printf '%s' "$parsed" | awk -F '\t' '{print $3}')
  report_trace "proxy" "$IP_PROXY" "$COLO_PROXY" "$LOC_PROXY"
  code=$(http_code "$TMPS/ip-echo.txt" "$IP_ECHO_URL" -x "http://127.0.0.1:${PORT}")
  echo_ip=$(tr -d '[:space:]' < "$TMPS/ip-echo.txt" | head -c 80)
  case "$echo_ip" in
    [0-9]*.[0-9]*.[0-9]*.[0-9]*|*:*)
      note INFO "经混合端口访问 IP 回显得到 ${echo_ip}（取决于规则，不一定等于 AI 分组）。"
      ;;
    *)
      note WARN "IP 回显无结果（${IP_ECHO_URL}）。这是补充信息，探测地址可改。"
      ;;
  esac
  # code is unused on purpose; body emptiness is the signal.
  : "$code"
fi

code=$(http_code "$TMPS/trace-direct.txt" "$TRACE_URL" --noproxy '*')
parsed=$(parse_trace_file "$TMPS/trace-direct.txt")
IP_DIRECT=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
COLO_DIRECT=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')
LOC_DIRECT=$(printf '%s' "$parsed" | awk -F '\t' '{print $3}')
report_trace "direct" "$IP_DIRECT" "$COLO_DIRECT" "$LOC_DIRECT"
: "$code"

if [ -n "$IP_PROXY" ] && [ -n "$IP_DIRECT" ] && [ "$IP_PROXY" != "$IP_DIRECT" ]; then
  note WARN "混合端口出口 ${IP_PROXY} 与 noproxy 路径 ${IP_DIRECT} 不一致。若没开 TUN，后者可能是本机网络。请按 references/05-leak-checks.md 判断，本脚本不直接把它定成泄漏。"
fi

FAKEIP_GUESS="${FAKEIP_SERVER:-}"
ENHANCED=""
if [ -z "$SOCK" ] || [ ! -S "$SOCK" ]; then
  note WARN "未找到 Clash 外部控制 socket，跳过分组和运行时配置。这不是「组不存在」。请打开 Service / 外部控制，或设置 CLASH_SOCK。"
else
  note INFO "使用 socket: ${SOCK}"
  enc=$(urlencode "$GROUP" || true)
  if [ -z "$enc" ]; then
    note FAIL "无法安全编码组名「${GROUP}」（需要 perl 或可用的 python3）。已停止组请求，避免把组名拼进解释器。"
  else
    code=$(http_code "$TMPS/group.json" "http://localhost/proxies/${enc}" --unix-socket "$SOCK")
    code=${code//$'\r'/}
    code=${code//$'\n'/}
    case "$code" in
      200) ;;
      404)
        note FAIL "代理组「${GROUP}」不存在（HTTP 404）。请创建 Fallback 组 AI-EXIT，或设置 GROUP=实际组名。未打印接口原文。"
        code=skip
        ;;
      401|403)
        note WARN "Clash 接口拒绝访问（HTTP ${code}）。未读取密钥，跳过分组。"
        code=skip
        ;;
      000|"")
        note WARN "Clash socket 无 HTTP 响应，跳过分组。"
        code=skip
        ;;
      *)
        note WARN "读取组时 HTTP ${code}，跳过分组。未打印接口原文。"
        code=skip
        ;;
    esac
    if [ "$code" = "200" ]; then
      if py=$(python3_bin); then
        "$py" - "$TMPS/group.json" > "$TMPS/group.tsv" <<'PY' || true
import json, sys
try:
    raw = open(sys.argv[1], encoding="utf-8").read()
    d = json.loads(raw) if raw.strip() else {}
except Exception:
    print("BADJSON")
    sys.exit(0)
if not isinstance(d, dict) or ("type" not in d and "all" not in d):
    print("MISSING")
    sys.exit(0)
print("TYPE\t" + str(d.get("type") or ""))
now = d.get("now")
print("NOW\t" + ("" if now is None else str(now)))
for m in d.get("all") or []:
    print("MEMBER\t" + str(m))
PY
        if grep -qx 'BADJSON' "$TMPS/group.tsv"; then
          note FAIL "分组接口的响应无法解析。未打印原文。请确认 socket 指向 mihomo，且 GROUP=${GROUP}。"
        elif grep -qx 'MISSING' "$TMPS/group.tsv"; then
          note FAIL "代理组「${GROUP}」不存在。请创建名为 AI-EXIT 的 Fallback 组，或设置 GROUP 为实际组名。未打印接口原文。"
        else
          gtype=$(awk -F '\t' '$1=="TYPE"{print $2; exit}' "$TMPS/group.tsv")
          gnow=$(awk -F '\t' '$1=="NOW"{print substr($0, index($0, "\t")+1); exit}' "$TMPS/group.tsv")
          lowtype=$(printf '%s' "$gtype" | tr '[:upper:]' '[:lower:]')
          case "$lowtype" in
            fallback)
              note OK "组 ${GROUP} 类型是 Fallback，当前成员: ${gnow:-未知}"
              ;;
            "")
              note FAIL "代理组「${GROUP}」没有 type。请确认组名。未打印接口原文。"
              ;;
            *)
              note WARN "组 ${GROUP} 存在，但类型是 ${gtype}，不是 Fallback。故障时不会按顺序自动切换。"
              ;;
          esac
          if [ "$MAX_DELAY_CHECKS" -eq 0 ]; then
            note INFO "MAX_DELAY_CHECKS=0，跳过延迟探测。"
          else
            members=$(awk -F '\t' '$1=="MEMBER"{print substr($0, index($0, "\t")+1)}' "$TMPS/group.tsv")
            checked=0
            ok_delay=0
            while IFS= read -r member; do
              [ -n "$member" ] || continue
              if [ "$member" = "$GROUP" ]; then
                continue
              fi
              if [ "$checked" -ge "$MAX_DELAY_CHECKS" ]; then
                note WARN "成员超过 ${MAX_DELAY_CHECKS} 个，其余未测。AI-EXIT 里只放少量节点。"
                break
              fi
              checked=$((checked + 1))
              menc=$(urlencode "$member" || true)
              durl=$(urlencode "$DELAY_URL" || true)
              if [ -z "$menc" ] || [ -z "$durl" ]; then
                note WARN "无法编码成员名或 DELAY_URL，跳过剩余延迟探测。"
                break
              fi
              delay_code=$(http_code "$TMPS/delay.json" "http://localhost/proxies/${menc}/delay?url=${durl}&timeout=5000" --unix-socket "$SOCK")
              delay=$(sed -n 's/.*"delay"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$TMPS/delay.json" | head -1)
              if [ -z "$delay" ]; then
                note WARN "延迟失败: ${member}"
              elif [ "$delay" -gt 1500 ]; then
                note WARN "延迟 ${member} ${delay}ms（超过 1500）"
                ok_delay=$((ok_delay + 1))
              else
                note OK "延迟 ${member} ${delay}ms"
                ok_delay=$((ok_delay + 1))
              fi
              : "$delay_code"
            done <<EOF
$members
EOF
            if [ "$checked" -gt 0 ] && [ "$ok_delay" -eq 0 ]; then
              note WARN "组 ${GROUP} 已测成员全部失败。订阅改名或前置节点失效时也会这样，见 troubleshooting.md。"
            fi
            if [ "$checked" -eq 0 ]; then
              note WARN "组 ${GROUP} 没有可测成员。"
            fi
          fi
        fi
      else
        note INFO "没有可用的 python3，分组用简化解析。未调用可能弹出安装窗口的系统占位解释器。"
        if grep -q '"type"' "$TMPS/group.json"; then
          if grep -Eq '"type"[[:space:]]*:[[:space:]]*"Fallback"' "$TMPS/group.json"; then
            note OK "组 ${GROUP} 为 Fallback（简化解析，未逐个测成员）。"
          else
            note WARN "组 ${GROUP} 有响应，但简化解析不能确认它是 Fallback。"
          fi
        else
          note FAIL "代理组「${GROUP}」不存在或响应里没有 type。请创建该组或修正 GROUP。未打印接口原文。"
        fi
      fi
    fi
  fi

  code=$(http_code "$TMPS/configs.json" "http://localhost/configs" --unix-socket "$SOCK")
  code=${code//$'\r'/}
  code=${code//$'\n'/}
  if [ "$code" = "200" ] && py=$(python3_bin); then
    runtime=$("$py" - "$TMPS/configs.json" <<'PY' || true
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
    s(d.get("ipv6")),
    s(d.get("mode")),
    s(dns.get("enhanced-mode")),
    s(dns.get("fake-ip-range")),
]))
PY
)
    if [ -n "${runtime:-}" ]; then
      tun_enable=$(printf '%s' "$runtime" | awk -F '\t' '{print $1}')
      tun_stack=$(printf '%s' "$runtime" | awk -F '\t' '{print $2}')
      tun_hijack=$(printf '%s' "$runtime" | awk -F '\t' '{print $3}')
      runtime_ipv6=$(printf '%s' "$runtime" | awk -F '\t' '{print $4}')
      runtime_mode=$(printf '%s' "$runtime" | awk -F '\t' '{print $5}')
      ENHANCED=$(printf '%s' "$runtime" | awk -F '\t' '{print $6}')
      fake_range=$(printf '%s' "$runtime" | awk -F '\t' '{print $7}')
      case "$(printf '%s' "$tun_enable" | tr '[:upper:]' '[:lower:]')" in
        true) note OK "TUN 已开启 stack=${tun_stack:-?} dns-hijack=${tun_hijack:-?}" ;;
        false) note WARN "TUN 未开启。不走系统代理的程序可能绕过。本脚本不替你打开它。" ;;
        *) note INFO "未读到 TUN 开关。" ;;
      esac
      note INFO "运行时 ipv6=${runtime_ipv6:-未知}。这只是内核开关，不等于本机有没有全局地址。"
      case "$(printf '%s' "$runtime_mode" | tr '[:upper:]' '[:lower:]')" in
        rule) note OK "Clash mode=rule" ;;
        "") note INFO "未读到 Clash mode。" ;;
        *) note WARN "Clash mode=${runtime_mode}。规则要落到 AI-EXIT，通常需要 rule 模式。" ;;
      esac
      if [ -z "$FAKEIP_GUESS" ]; then
        case "$fake_range" in
          198.18.*|198.19.*)
            FAKEIP_GUESS=$(printf '%s\n' "${fake_range%%/*}" | awk -F. 'NF>=2 {print $1"."$2".0.2"}')
            note INFO "按运行时 fake-ip-range=${fake_range} 推断探测地址 ${FAKEIP_GUESS}。这是推断，可用 FAKEIP_SERVER 覆盖。"
            ;;
        esac
      fi
      if [ -n "$ENHANCED" ]; then
        note INFO "DNS enhanced-mode=${ENHANCED}"
      fi
    fi
  elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
    note INFO "运行时配置接口返回 HTTP ${code}。未读取密钥。"
  fi
fi

enhanced_low=$(printf '%s' "$ENHANCED" | tr '[:upper:]' '[:lower:]')
if [ "$enhanced_low" = "redir-host" ]; then
  note INFO "当前是 redir-host，不做 fake-ip 地址判定。"
elif [ -z "$FAKEIP_GUESS" ]; then
  note INFO "未设置 FAKEIP_SERVER，也没有从运行时配置推断出探测地址，跳过 fake-ip。常见示例是 198.18.0.2，但示例不是你的探测结果。"
elif ! command -v dig >/dev/null 2>&1; then
  note INFO "未找到 dig，跳过 fake-ip 探测（${FAKEIP_GUESS}）。"
else
  fake_ip=$(dig +short +time=2 +tries=1 @"$FAKEIP_GUESS" "$DNS_PROBE_NAME" 2>/dev/null | head -1 || true)
  case "$fake_ip" in
    198.18.*|198.19.*)
      note OK "fake-ip ${DNS_PROBE_NAME} -> ${fake_ip}（经 ${FAKEIP_GUESS}）"
      ;;
    "")
      note WARN "向 ${FAKEIP_GUESS} 查询 ${DNS_PROBE_NAME} 没有结果。请核对 fake-ip 监听地址。"
      ;;
    *)
      note WARN "向 ${FAKEIP_GUESS} 查询 ${DNS_PROBE_NAME} 得到 ${fake_ip}。这不一定是泄漏：若该名字在 fake-ip-filter 里，返回真实地址是预期行为。判定步骤见 references/05-leak-checks.md。"
      ;;
  esac
fi

V6=$(count_global_ipv6)
case "$V6" in
  NO_TOOL)
    note INFO "没有 ip 或 ifconfig，跳过全局 IPv6 统计。"
    ;;
  0)
    note OK "未发现全局 IPv6（已排除链路本地、组播和 ULA，含 fc00::/7 / fd00::/8）。"
    ;;
  *)
    note INFO "发现 ${V6} 个全局 IPv6（已排除链路本地和 ULA）。这不是自动失败。请用 references/05-leak-checks.md 区分代理地址和本机地址；关闭 IPv6 前要先问用户。"
    ;;
esac

if [ -n "$SVC" ] && command -v networksetup >/dev/null 2>&1; then
  v6mode=$(networksetup -getinfo "$SVC" 2>/dev/null | awk -F': ' '/^IPv6:/{print $2; exit}')
  note INFO "系统 IPv6 模式（${SVC}）: ${v6mode:-未知}。关闭 IPv6 会影响整块网卡，本脚本不会改它。"
  dns_now=$(networksetup -getdnsservers "$SVC" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  if printf '%s' "$dns_now" | grep -qi "aren't any DNS"; then
    note INFO "系统 DNS（${SVC}）: 未单独指定。数值本身不是 pass/fail，判定见 references/05-leak-checks.md。"
  else
    note INFO "系统 DNS（${SVC}）: ${dns_now:-未知}。出现 114.114.114.114 或其它公共 DNS 都不能单独当成正常或泄漏。"
  fi
  check_one_proxy() {
    local label="$1"
    local flag="$2"
    local out enabled server port
    out=$(networksetup "$flag" "$SVC" 2>/dev/null || true)
    enabled=$(printf '%s\n' "$out" | awk -F': ' '/^Enabled:/{print $2; exit}')
    server=$(printf '%s\n' "$out" | awk -F': ' '/^Server:/{print $2; exit}')
    port=$(printf '%s\n' "$out" | awk -F': ' '/^Port:/{print $2; exit}')
    if [ "$enabled" = "Yes" ] && [ "$server" = "127.0.0.1" ] && [ -n "$PORT" ] && [ "$port" = "$PORT" ]; then
      note OK "${label} 127.0.0.1:${PORT}"
    else
      note WARN "${label}: Enabled=${enabled:-?} Server=${server:-?} Port=${port:-?}（期望 127.0.0.1:${PORT:-未探测}）"
    fi
  }
  if [ -n "$PORT" ]; then
    check_one_proxy "系统 HTTP 代理" -getwebproxy
    check_one_proxy "系统 HTTPS 代理" -getsecurewebproxy
  fi
  if [ -z "${BYPASS_DOMAINS:-}" ]; then
    note INFO "未设置 BYPASS_DOMAINS，跳过 bypass 名单核对。"
  else
    bypass_now=$(networksetup -getproxybypassdomains "$SVC" 2>/dev/null || true)
    # shellcheck disable=SC2086
    set -f
    # shellcheck disable=SC2086
    for domain in ${BYPASS_DOMAINS}; do
      if printf '%s\n' "$bypass_now" | grep -qxF "$domain"; then
        note OK "bypass 含 ${domain}"
      else
        note WARN "bypass 缺少 ${domain}"
      fi
    done
    set +f
  fi
fi

if command -v launchctl >/dev/null 2>&1; then
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx 'com.example.dns-guard'; then
    note OK "可选组件 dns-guard 已加载"
  else
    note INFO "dns-guard 未安装或未加载。它是可选项，只在 VPN 反复改写 DNS 时才需要；没装不是故障。"
  fi
else
  note INFO "当前系统没有 launchctl，跳过可选组件 dns-guard。"
fi

finish
