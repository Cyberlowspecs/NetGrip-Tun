#!/bin/bash
# Must be run with sudo
# License: MIT
# Copyright (c) 2026 Cyberlowspecs

ACTION="${1:-start}"
PROXY_IP="${2:-127.0.0.1}"
PROXY_PORT="${3:-10808}"
LOG_FILE="/var/log/tun2socks.log"

if [ "$ACTION" == "stop" ]; then
    echo "Stopping global proxy..."
    pkill tun2socks

    # Clean up IPv4
    ip rule del fwmark 42 table 42 2>/dev/null
    ip route flush table 42 2>/dev/null
    iptables -t mangle -F OUTPUT
    
    # Clean up IPv6
    ip6tables -t mangle -F OUTPUT

    ip link delete dev tun0 2>/dev/null

    echo "Normal internet restored."
    exit 0
elif [ "$ACTION" != "start" ]; then
    echo "Usage: $0 [start|stop] [PROXY_IP] [PROXY_PORT]"
    echo "Example: $0 start 192.168.1.50 1080"
    exit 1
fi

echo "Cleaning up any stale states..."
ip rule del fwmark 42 table 42 2>/dev/null
iptables -t mangle -F OUTPUT
ip6tables -t mangle -F OUTPUT

echo "Setting up tun0 interface..."
ip tuntap add dev tun0 mode tun
ip addr add 198.18.0.1/15 dev tun0
# Set MTU to prevent fragmentation drops (1420 is safe for WireGuard/socks overhead)
ip link set dev tun0 mtu 1420
ip link set tun0 up

echo "Starting tun2socks routing to ${PROXY_IP}:${PROXY_PORT}..."
# Log to file instead of /dev/null for diagnostics
tun2socks -device tun0 -proxy socks5://${PROXY_IP}:${PROXY_PORT} > "${LOG_FILE}" 2>&1 &

echo "Configuring global routing table..."
ip route flush table 42
ip route add default dev tun0 table 42
ip rule add fwmark 42 table 42

echo "Applying iptables rules..."

# IPv4 Rules
# 1. Local traffic bypass
iptables -t mangle -A OUTPUT -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A OUTPUT -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A OUTPUT -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A OUTPUT -d 172.16.0.0/12 -j RETURN

# 2. Proxy bypass group (crucial for Xray/V2Ray to avoid traffic loops)
iptables -t mangle -A OUTPUT -m owner --gid-owner xray-direct -j RETURN

# 3. DNS routing
iptables -t mangle -A OUTPUT -p udp --dport 53 -j MARK --set-mark 42
iptables -t mangle -A OUTPUT -p tcp --dport 53 -j MARK --set-mark 42

# 4. Mark everything else
iptables -t mangle -A OUTPUT -j MARK --set-mark 42

# IPv6 Rules (PREVENT LEAKS)
# If your proxy config doesn't perfectly route IPv6, it is safer to drop it while the proxy is active.
ip6tables -t mangle -A OUTPUT -m owner --gid-owner xray-direct -j RETURN
ip6tables -t mangle -A OUTPUT -j DROP

echo "Global proxy is active. Check ${LOG_FILE} if connection drops."
