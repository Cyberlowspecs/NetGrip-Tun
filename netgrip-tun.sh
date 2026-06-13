#!/bin/bash
# Must be run with sudo
# License: MIT
# Copyright (c) 2026 Cyberlowspecs

LOG_FILE="/var/log/tun2socks.log"

# --- Default Configuration ---
MTU=1400
BYPASS_WEBRTC=false
BYPASS_UDP=false
DROP_IPV6=false
PROXY_WAYDROID=false

# --- Usage ---
show_usage() {
  echo "Usage: $0 [start|stop] [PROXY_IP] [PROXY_PORT] [OPTIONS]"
  echo ""
  echo "Actions:"
  echo "  start                 Start the global proxy (default action)"
  echo "  stop                  Stop the global proxy and restore normal internet"
  echo ""
  echo "Arguments:"
  echo "  PROXY_IP              IP address of the SOCKS5 proxy (default: 127.0.0.1)"
  echo "  PROXY_PORT            Port of the SOCKS5 proxy (default: 10808)"
  echo ""
  echo "Options:"
  echo "  --bypass-webrtc       Bypass WebRTC UDP ports from the tunnel."
  echo "                        Fixes voice/video call issues (Discord, Meet, Zoom)."
  echo "                        WARNING: Voice/video traffic will use your real IP."
  echo ""
  echo "  --bypass-udp          Bypass ALL UDP traffic (except DNS) from the tunnel."
  echo "                        Fixes gaming, torrenting, and all real-time UDP apps."
  echo "                        WARNING: All UDP traffic will use your real IP."
  echo ""
  echo "  --drop-ipv6           Drop all IPv6 traffic instead of tunneling it."
  echo "                        Use if your proxy doesn't handle IPv6 well."
  echo ""
  echo "  --proxy-waydroid      Proxy ALL traffic coming out of waydroid-container."
  echo "                        This will only work for waydroid-container running in"
  echo "                        network interface 'waydroid0' for now."
  echo ""
  echo "  --mtu <value>         Set custom MTU for the tun0 interface (default: 1400)."
  echo ""
  echo "Examples:"
  echo "  $0 start 192.168.1.50 1080"
  echo "  $0 start --bypass-webrtc"
  echo "  $0 start 192.168.1.50 1080 --bypass-udp --mtu 1300"
  echo "  $0 stop"
}

# --- Parse Arguments ---
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --bypass-webrtc)
    BYPASS_WEBRTC=true
    shift
    ;;
  --bypass-udp)
    BYPASS_UDP=true
    shift
    ;;
  --drop-ipv6)
    DROP_IPV6=true
    shift
    ;;
  --proxy-waydroid)
    PROXY_WAYDROID=true
    shift
    ;;
  --mtu)
    if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
      echo "Error: --mtu requires a numeric value."
      exit 1
    fi
    MTU="$2"
    shift 2
    ;;
  --help | -h)
    show_usage
    exit 0
    ;;
  -*)
    echo "Error: Unknown option '$1'."
    echo "Run '$0 --help' for usage information."
    exit 1
    ;;
  *)
    POSITIONAL_ARGS+=("$1")
    shift
    ;;
  esac
done

ACTION="${POSITIONAL_ARGS[0]:-start}"
PROXY_IP="${POSITIONAL_ARGS[1]:-127.0.0.1}"
PROXY_PORT="${POSITIONAL_ARGS[2]:-10808}"

# Validate MTU
if ! [[ "$MTU" =~ ^[0-9]+$ ]]; then
  echo "Error: --mtu value must be a number. Got: '$MTU'"
  exit 1
fi

# --- Dependency Check ---
check_dependencies() {
  local missing=()
  for cmd in tun2socks ip iptables ip6tables; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    echo "Error: Missing dependencies."
    echo "Please ensure the following commands are installed: ${missing[*]}"
    echo "Hint: You may need to install packages like 'tun2socks', 'iproute2' (for ip), and 'iptables'."
    exit 1
  fi
}

check_dependencies

# --- Stop Action ---
if [ "$ACTION" == "stop" ]; then
  echo "Stopping global proxy..."
  pkill tun2socks

  # Clean up IPv4
  ip rule del fwmark 42 table 42 2>/dev/null
  ip route flush table 42 2>/dev/null
  iptables -t mangle -F OUTPUT

  # Clean up IPv6
  ip -6 rule del fwmark 42 table 42 2>/dev/null
  ip -6 route flush table 42 2>/dev/null
  ip6tables -t mangle -F OUTPUT

  ip link delete dev tun0 2>/dev/null

  echo "Normal internet restored."
  exit 0
elif [ "$ACTION" != "start" ]; then
  show_usage
  exit 1
fi

# --- Start Action ---

# Print active configuration
echo "=== NetGrip-Tun Configuration ==="
echo "Proxy:           socks5://${PROXY_IP}:${PROXY_PORT}"
echo "MTU:             ${MTU}"
if [ "$DROP_IPV6" = true ]; then
  echo "IPv6:            DROP (all IPv6 blocked)"
else
  echo "IPv6:            TUNNEL (routed through proxy)"
fi
if [ "$BYPASS_UDP" = true ]; then
  echo "UDP Bypass:      ON (all UDP uses real IP)"
elif [ "$BYPASS_WEBRTC" = true ]; then
  echo "WebRTC Bypass:   ON (voice/video uses real IP)"
else
  echo "UDP/WebRTC:      OFF (all traffic tunneled)"
fi
if [ "$PROXY_WAYDROID" = true ]; then
  echo "Proxy Waydroid:  ON (all waydroid0 traffic tunneled)"
else
  echo "Proxy Waydroid:  OFF (waydroid0 uses real IP)"
fi
echo "=================================="
echo ""

# Warn about bypass modes
if [ "$BYPASS_UDP" = true ]; then
  echo "⚠  WARNING: --bypass-udp is active. ALL UDP traffic (except DNS) bypasses the proxy."
  echo "   Your real IP will be visible to UDP-based services."
  echo ""
elif [ "$BYPASS_WEBRTC" = true ]; then
  echo "⚠  WARNING: --bypass-webrtc is active. WebRTC voice/video traffic bypasses the proxy."
  echo "   Your real IP will be visible to voice/video services (Discord, Meet, Zoom, etc)."
  echo ""
fi

echo "Cleaning up any stale states..."
ip rule del fwmark 42 table 42 2>/dev/null
ip -6 rule del fwmark 42 table 42 2>/dev/null
iptables -t mangle -F OUTPUT
ip6tables -t mangle -F OUTPUT

echo "Setting up tun0 interface..."
ip tuntap add dev tun0 mode tun
ip addr add 198.18.0.1/15 dev tun0
if [ "$DROP_IPV6" = false ]; then
  ip -6 addr add fdfe:dcba:9876::1/126 dev tun0
fi
ip link set dev tun0 mtu "${MTU}"
ip link set tun0 up

echo "Starting tun2socks routing to ${PROXY_IP}:${PROXY_PORT}..."
# Log to file for diagnostics
tun2socks -device tun0 -proxy socks5://${PROXY_IP}:${PROXY_PORT} >"${LOG_FILE}" 2>&1 &

echo "Configuring routing tables..."
# IPv4 routing
ip route flush table 42
ip route add default dev tun0 table 42
ip rule add fwmark 42 table 42

# IPv6 routing (only if tunneling IPv6)
if [ "$DROP_IPV6" = false ]; then
  ip -6 route flush table 42
  ip -6 route add default dev tun0 table 42
  ip -6 rule add fwmark 42 table 42
fi

echo "Applying iptables rules..."

# ============================================================
# IPv4 Rules
# ============================================================

# 1. Local traffic bypass
iptables -t mangle -A OUTPUT -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A OUTPUT -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A OUTPUT -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A OUTPUT -d 172.16.0.0/12 -j RETURN

# 2. Proxy bypass group (crucial for Xray/V2Ray to avoid traffic loops)
if getent group xray-direct >/dev/null 2>&1; then
  iptables -t mangle -A OUTPUT -m owner --gid-owner xray-direct -j RETURN
else
  echo "Notice: 'xray-direct' group not found. If you are a non-Xray user, you can safely ignore this."
  echo "        If you use Xray/V2Ray, please create the group to avoid traffic loops."
fi

# 3. DNS routing (force DNS through the tunnel for leak protection)
iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 42
iptables -t mangle -A OUTPUT -p tcp --dport 53 -j MARK --set-mark 42

# 4. Optional: WebRTC bypass (only with --bypass-webrtc, skipped if --bypass-udp covers it)
if [ "$BYPASS_WEBRTC" = true ] && [ "$BYPASS_UDP" = false ]; then
  echo "  → WebRTC bypass rules applied (IPv4)"
  # STUN/TURN servers (used by Discord, Google Meet, Zoom, etc.)
  iptables -t mangle -A OUTPUT -p udp --dport 3478 -j RETURN
  iptables -t mangle -A OUTPUT -p udp --dport 3479 -j RETURN
  iptables -t mangle -A OUTPUT -p udp --dport 5349 -j RETURN
  iptables -t mangle -A OUTPUT -p udp --dport 19302:19309 -j RETURN
  # RTP media streams (high UDP ports used for actual voice/video data)
  iptables -t mangle -A OUTPUT -p udp --dport 50000:65535 -j RETURN
fi

# 5. Optional: Full UDP bypass (only with --bypass-udp)
if [ "$BYPASS_UDP" = true ]; then
  echo "  → Full UDP bypass rules applied (IPv4)"
  iptables -t mangle -A OUTPUT -p udp -j RETURN
fi

# 6. Mark everything else → tunnel
iptables -t mangle -A OUTPUT -j MARK --set-mark 42

# ============================================================
# IPv6 Rules
# ============================================================

if [ "$DROP_IPV6" = true ]; then
  # Drop all IPv6 traffic (except xray-direct group)
  echo "  → Dropping all IPv6 traffic"
  if getent group xray-direct >/dev/null 2>&1; then
    ip6tables -t mangle -A OUTPUT -m owner --gid-owner xray-direct -j RETURN
  fi
  ip6tables -t mangle -A OUTPUT -j DROP
else
  # Tunnel IPv6 through the proxy (default behavior)
  echo "  → Tunneling IPv6 traffic through proxy"

  # 1. Local/link-local IPv6 bypass
  ip6tables -t mangle -A OUTPUT -d ::1/128 -j RETURN
  ip6tables -t mangle -A OUTPUT -d fe80::/10 -j RETURN

  # 2. Proxy bypass group
  if getent group xray-direct >/dev/null 2>&1; then
    ip6tables -t mangle -A OUTPUT -m owner --gid-owner xray-direct -j RETURN
  fi

  # 3. DNS routing
  ip6tables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 42
  ip6tables -t mangle -A OUTPUT -p tcp --dport 53 -j MARK --set-mark 42

  # 4. Optional: WebRTC bypass on IPv6 (only if not already bypassing all UDP)
  if [ "$BYPASS_WEBRTC" = true ] && [ "$BYPASS_UDP" = false ]; then
    echo "  → WebRTC bypass rules applied (IPv6)"
    ip6tables -t mangle -A OUTPUT -p udp --dport 3478 -j RETURN
    ip6tables -t mangle -A OUTPUT -p udp --dport 3479 -j RETURN
    ip6tables -t mangle -A OUTPUT -p udp --dport 5349 -j RETURN
    ip6tables -t mangle -A OUTPUT -p udp --dport 19302:19309 -j RETURN
    ip6tables -t mangle -A OUTPUT -p udp --dport 50000:65535 -j RETURN
  fi

  # 5. Optional: Full UDP bypass on IPv6
  if [ "$BYPASS_UDP" = true ]; then
    echo "  → Full UDP bypass rules applied (IPv6)"
    ip6tables -t mangle -A OUTPUT -p udp -j RETURN
  fi

  # 6. Mark everything else → tunnel
  ip6tables -t mangle -A OUTPUT -j MARK --set-mark 42
fi

echo ""
echo "Global proxy is active. Check ${LOG_FILE} if connection drops."
