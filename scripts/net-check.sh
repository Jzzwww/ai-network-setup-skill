#!/bin/bash
# net-check.sh — 只读网络巡检（不改任何配置，不重载 Clash，不打印凭据）
# 用法: EXPECTED_IP=<你的固定出口IP> EXPECTED_COLO=<机房如EWR> ./net-check.sh
# 可选: CLASH_SOCK=<socket路径> PROXY_PORT=7897 GROUP=Claude-ISP BYPASS_DOMAINS="*.<公司域名> ..."（空格分隔，检查系统代理 bypass）
set -u
PORT="${PROXY_PORT:-7897}"; GROUP="${GROUP:-Claude-ISP}"
SOCK="${CLASH_SOCK:-/var/run/clash-verge-service/users/$(id -u)/verge-mihomo.sock}"
EXP="${EXPECTED_IP:-}"; COLO="${EXPECTED_COLO:-}"
FAIL=0; WARN=0
ok(){ echo "[OK]   $*"; }; warn(){ echo "[WARN] $*"; WARN=$((WARN+1)); }; bad(){ echo "[FAIL] $*"; FAIL=$((FAIL+1)); }
echo "== net-check $(date '+%F %T %Z') =="
trace(){ curl -s -m 10 "$@" https://claude.ai/cdn-cgi/trace | grep -E '^(ip|loc|colo)=' | tr '\n' ' '; }
for mode in proxy tun; do
  if [ $mode = proxy ]; then T=$(trace -x "http://127.0.0.1:$PORT"); else T=$(trace --noproxy '*'); fi
  ip=$(echo "$T" | sed -nE 's/.*ip=([^ ]+).*/\1/p'); c=$(echo "$T" | sed -nE 's/.*colo=([^ ]+).*/\1/p')
  if [ -z "$ip" ]; then bad "trace($mode) 无响应"
  elif [ -n "$EXP" ] && [ "$ip" != "$EXP" ]; then bad "trace($mode) 出口 $ip ≠ 期望 $EXP ($T)"
  elif [ -n "$COLO" ] && [ "$c" != "$COLO" ]; then warn "trace($mode) colo=$c ≠ $COLO"
  else ok "trace($mode) $T"; fi
done
G=$(curl -s -m 5 -x "http://127.0.0.1:$PORT" https://api.ipify.org)
[ -n "$G" ] && ok "普通出口 $G" || warn "普通出口查询失败"
if [ -S "$SOCK" ]; then
  J=$(curl -s -m 5 --unix-socket "$SOCK" "http://x/proxies/$GROUP")
  echo "$J" | python3 -c 'import json,sys
d=json.load(sys.stdin);print("[INFO] '"$GROUP"'",d.get("type"),"now=",d.get("now"),"all=",d.get("all"))' 2>/dev/null || bad "读取 $GROUP 失败"
  echo "$J" | grep -qi '"type":"Fallback"' && ok "$GROUP 为 Fallback" || warn "$GROUP 类型非 Fallback"
  MEMBERS=$(echo "$J" | python3 -c 'import json,sys;print("\n".join(json.load(sys.stdin).get("all",[])))' 2>/dev/null)
  OKN=0; TOT=0
  while IFS= read -r m; do [ -z "$m" ] && continue; TOT=$((TOT+1))
    e=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$m")
    R=$(curl -s -m 7 --unix-socket "$SOCK" "http://x/proxies/$e/delay?url=http%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=5000")
    d=$(echo "$R" | sed -nE 's/.*"delay":([0-9]+).*/\1/p')
    if [ -z "$d" ]; then warn "延迟 $m 超时/失败 ($R)"
    elif [ "$d" -gt 1500 ]; then warn "延迟 $m ${d}ms >1500"; OKN=$((OKN+1))
    else ok "延迟 $m ${d}ms"; OKN=$((OKN+1)); fi
  done <<< "$MEMBERS"
  [ $TOT -gt 0 ] && [ $OKN -eq 0 ] && warn "$GROUP 全部成员失败"
  curl -s -m 5 --unix-socket "$SOCK" http://x/configs | python3 -c 'import json,sys
d=json.load(sys.stdin);t=d.get("tun",{});print("[INFO] tun",t.get("enable"),t.get("stack"),t.get("dns-hijack"),"ipv6",d.get("ipv6"),"mode",d.get("mode"))' 2>/dev/null
else warn "Clash socket 不存在: $SOCK"; fi
F=$(dig +short +time=2 +tries=1 @198.18.0.2 claude.ai 2>/dev/null | head -1)
case "$F" in 198.18.*|198.19.*) ok "fake-ip $F";; *) warn "fake-ip 异常: '${F}'";; esac
V6=$(ifconfig 2>/dev/null | grep inet6 | grep -v -E 'fe80|::1 ' | grep -c inet6)
[ "$V6" -eq 0 ] && ok "无全局 IPv6 地址" || warn "存在 $V6 个全局 IPv6 地址（确认是否预期）"
echo "[INFO] Wi-Fi $(networksetup -getinfo Wi-Fi 2>/dev/null | grep -m1 IPv6)"
WP=$(networksetup -getwebproxy Wi-Fi 2>/dev/null | tr '\n' ' ')
echo "$WP" | grep -q "Enabled: Yes.*Port: $PORT" && ok "系统代理 127.0.0.1:$PORT" || warn "系统代理: $WP"
BP=$(networksetup -getproxybypassdomains Wi-Fi 2>/dev/null | tr '\n' ' ')
set -f; for d in ${BYPASS_DOMAINS:-}; do echo "$BP" | grep -qF "$d" || warn "bypass 缺 $d"; done; set +f
launchctl list 2>/dev/null | grep -q dns-guard && ok "dns-guard 在运行" || warn "dns-guard 未加载"
echo "== 结果: FAIL=$FAIL WARN=$WARN =="
[ $FAIL -eq 0 ] || exit 2; [ $WARN -eq 0 ] || exit 1; exit 0
