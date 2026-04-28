# NetGrip-Tun Global Proxy Enforcer for Linux

**Force all Linux network traffic through a SOCKS5 proxy using tun2socks and iptables. A complete system-wide proxy enforcer.**

Are you frustrated by applications that completely ignore your system's network proxy settings? Standard desktop proxy configurations often fail to capture traffic from **Flatpaks, Wine, Lutris, Snapd**, and many standalone binaries. 

This script solves that by operating at the kernel routing level. It creates a virtual network interface (`tun0`) and uses `iptables` to forcefully route *all* outbound traffic through any SOCKS5 proxy of your choosing. 

Perfect for use with Xray, V2Ray, SSH tunnels, or any standard SOCKS5 provider.

---

## 🛠️ Compatibility & Prerequisites

This script is compatible with any modern Linux distribution using `iptables` and `iproute2`. 

Before starting, you need a few standard networking tools installed on your system. Open your terminal and run the command for your Linux distribution:

**Fedora / RHEL:**
```bash
sudo dnf install iptables iproute
```

**Debian / Ubuntu / Linux Mint:**
```bash
sudo apt update && sudo apt install iptables iproute2
```

**Arch Linux / Manjaro:**
```bash
sudo pacman -S iptables iproute2
```

---

## 📥 Installation

### 1. Download `tun2socks`
You need the `tun2socks` binary to handle the actual traffic conversion. 
1. Go to the official releases page: **[tun2socks GitHub Releases](https://github.com/xjasonlyu/tun2socks/releases)**
2. Download the correct zip file for your architecture (most likely `tun2socks-linux-amd64.zip`).
3. Extract it and move it to your system binaries so the script can find it:
```bash
unzip tun2socks-linux-amd64.zip
```
```bash
sudo mv tun2socks-linux-amd64 /usr/local/bin/tun2socks
```
```bash
sudo chmod +x /usr/local/bin/tun2socks
```

### 2. Download the Script
Clone this repository or download the script directly:
```bash
git clone https://github.com/Cyberlowspecs/NetGrip-Tun.git
```
```bash
cd NetGrip-Tun
```
```bash
sudo chmod +x netgrip-tun.sh
```

---

## 🚀 How to Use (Non-Xray Users)
*Use this guide if you are connecting to a standard SOCKS5 proxy (like an SSH tunnel or a commercial proxy).*

**To Start the Proxy:**
Run the script with `start`, followed by your Proxy IP and Port.
```bash
sudo ./netgrip-tun.sh start 192.168.1.50 1080
```
*(If you run `sudo ./netgrip-tun.sh start` without an IP and port, it defaults to `127.0.0.1` and `10808`)*.

**To Stop the Proxy and Restore Normal Internet:**
```bash
sudo ./netgrip-tun.sh stop
```

That's it! Once started, all applications on your system (including Flatpaks and Wine games) are now securely routed through your SOCKS5 proxy.

> 💡 **Having issues with voice calls or games?** Check the [Advanced Options](#-advanced-options) section below for easy fixes.

---

## ⚡ How to Use (Xray Users)
*Use this guide if you are running Xray-core locally. We must configure a bypass group so Xray itself doesn't get routed into the proxy, which would cause an infinite traffic loop.*

### Step 1: Create the bypass group
We need to create a dedicated Linux user group named `xray-direct`.
```bash
sudo groupadd xray-direct
```

### Step 2: Run Xray under the bypass group
To prevent the "infinite loop" that crashes your internet, you must start Xray using the `sg` (switch group) command. This tells the system that traffic from this specific command should bypass the proxy.

Run this command in its own terminal window:
```bash
sudo sg xray-direct -c "xray run -config /usr/local/etc/xray/config.json"
```

**📍 Finding your Config File**
The path `/usr/local/etc/xray/config.json` used in the command above is a common default. However, your config file might be in a different place depending on how you installed Xray:
* **Manual Install:** Often found in `/usr/local/etc/xray/config.json`.
* **Package Managers:** Often found in `/etc/xray/config.json`.
* **Portable/Folder:** If you just downloaded a folder, it is the `.json` file inside that folder.

**Copy-Paste Tip:** Just replace the path inside the quotes with the actual location of your config file (e.g., `"/home/yourname/xray/config.json"`).

### Step 3: Start the Global Routing
Now that Xray is safely bypassing the tunnel, start the script. (Assuming Xray's inbound SOCKS port is the default `10808`):
```bash
sudo ./netgrip-tun.sh start
```

To revert back to normal:
```bash
sudo ./netgrip-tun.sh stop
```

---

## 🎛️ Advanced Options

By default, NetGrip-Tun routes **all** traffic (IPv4, IPv6, TCP, and UDP) through your SOCKS5 proxy. This is the most private and secure mode — nothing leaks.

However, SOCKS5 proxies don't handle **UDP** traffic as well as a full VPN would. This means you might experience issues with:
- 🎙️ Voice/video calls (Discord, Google Meet, Zoom) — "I can hear them but they can't hear me" or vice versa
- 🎮 Online games — high latency, rubberbanding, or disconnects
- 📥 Torrents — slow speeds or no peers found

The following flags let you **opt-in** to specific traffic bypasses when you need them. **None of these are enabled by default.**

> ⚠️ **Privacy Warning:** When you use any bypass flag, the bypassed traffic will use your **real internet connection** instead of the proxy. The services you connect to will be able to see your **real IP address** for that specific traffic.

---

### 🎙️ Fix Voice/Video Call Issues (`--bypass-webrtc`)

**When to use this:** You're on a Discord call, Google Meet, or Zoom and you can't hear the other person, or they can't hear you, or the call just won't connect at all.

**What it does:** It lets voice and video call traffic skip the proxy and go through your normal internet connection instead. Only the specific network ports used by calling apps are affected — everything else (browsing, downloads, etc.) still goes through the proxy.

**How to use it:**

If you normally start the proxy like this:
```bash
sudo ./netgrip-tun.sh start
```

Just add `--bypass-webrtc` at the end:
```bash
sudo ./netgrip-tun.sh start --bypass-webrtc
```

If you use a custom proxy IP and port, put the flag after them:
```bash
sudo ./netgrip-tun.sh start 192.168.1.50 1080 --bypass-webrtc
```

To stop (same as always, no flag needed):
```bash
sudo ./netgrip-tun.sh stop
```

---

### 🎮 Fix Gaming / Torrenting / All UDP Issues (`--bypass-udp`)

**When to use this:** You have lag in online games, torrents aren't connecting, or `--bypass-webrtc` alone didn't fix your voice call issues.

**What it does:** It lets **all UDP traffic** (except DNS lookups) skip the proxy. This covers online games, voice/video calls, torrents, and any other real-time application. Your web browsing and downloads (which use TCP) still go through the proxy. DNS is always tunneled to prevent leaks.

**How to use it:**

```bash
sudo ./netgrip-tun.sh start --bypass-udp
```

With a custom proxy:
```bash
sudo ./netgrip-tun.sh start 192.168.1.50 1080 --bypass-udp
```

> 💡 **Note:** `--bypass-udp` already covers everything that `--bypass-webrtc` does (and more). You do **not** need to use both at the same time — just use `--bypass-udp`.

---

### 🌐 Drop IPv6 Traffic (`--drop-ipv6`)

**When to use this:** Your proxy server doesn't support IPv6 connections, or you are experiencing connectivity problems and want to rule out IPv6 as the cause.

**What it does:** Instead of routing IPv6 traffic through the proxy (which is the default behavior), it **blocks all IPv6 traffic entirely**. This is a nuclear option — IPv6-only websites and services will stop working, but it guarantees no IPv6 traffic can leak outside the proxy.

**How to use it:**

```bash
sudo ./netgrip-tun.sh start --drop-ipv6
```

---

### 📏 Custom MTU Size (`--mtu`)

**When to use this:** You're experiencing random disconnections, very slow speeds, or your connection keeps "stalling" — especially if you're already going through another tunnel like WireGuard.

**What it does:** It changes the **MTU** (Maximum Transmission Unit) — this is the maximum size of a single network packet. Think of it like choosing the size of boxes for shipping: too big and they won't fit through the door, too small and you waste trips.

The default value is `1400`, which works well for most setups. If you're having issues:
- **Try a lower value** like `1280` if you're on a slow, unreliable, or heavily tunneled connection.
- **Try a higher value** like `1500` if you're on a fast, direct connection and want maximum speed.

**How to use it:**

```bash
sudo ./netgrip-tun.sh start --mtu 1280
```

---

### 🔀 Combining Multiple Flags

You can use any combination of flags together. Just add them all after the `start` command. Here are some common combinations:

**Fix voice calls + Drop IPv6 (for proxies that don't support IPv6):**
```bash
sudo ./netgrip-tun.sh start --bypass-webrtc --drop-ipv6
```

**Fix gaming + Custom MTU + Custom proxy:**
```bash
sudo ./netgrip-tun.sh start 192.168.1.50 1080 --bypass-udp --mtu 1300
```

**All options at once:**
```bash
sudo ./netgrip-tun.sh start 192.168.1.50 1080 --bypass-udp --drop-ipv6 --mtu 1280
```

> 💡 **Remember:** The order of the flags doesn't matter. `--bypass-udp --drop-ipv6` is the same as `--drop-ipv6 --bypass-udp`. Just make sure `start`, the proxy IP, and the proxy port (if you're using them) come first.

**To see all available options at any time:**
```bash
sudo ./netgrip-tun.sh --help
```

---

## 🔍 Troubleshooting

### Internet drops completely after starting
1. Ensure your SOCKS5 proxy is actually running and accepting connections.
2. Check the script's log file to see what `tun2socks` is reporting:
   ```bash
   cat /var/log/tun2socks.log
   ```
3. **Xray Users:** Ensure you correctly ran Xray under the `xray-direct` group. If Xray runs as `root` without the group flag, its traffic gets caught in the proxy loop and your internet will freeze.

### Voice/video calls don't work (Discord, Meet, Zoom)
This is usually because SOCKS5 proxies struggle with UDP-based real-time traffic. Try these steps in order:

1. **First, try the WebRTC bypass flag:**
   ```bash
   sudo ./netgrip-tun.sh stop
   ```
   ```bash
   sudo ./netgrip-tun.sh start --bypass-webrtc
   ```

2. **If that doesn't fix it, try the full UDP bypass:**
   ```bash
   sudo ./netgrip-tun.sh stop
   ```
   ```bash
   sudo ./netgrip-tun.sh start --bypass-udp
   ```

3. **If you still have issues**, your proxy may not support IPv6 well. Try adding `--drop-ipv6`:
   ```bash
   sudo ./netgrip-tun.sh stop
   ```
   ```bash
   sudo ./netgrip-tun.sh start --bypass-webrtc --drop-ipv6
   ```

### Games are laggy or disconnecting
Online games rely heavily on UDP. Try the full UDP bypass:
```bash
sudo ./netgrip-tun.sh stop
```
```bash
sudo ./netgrip-tun.sh start --bypass-udp
```

If you're still experiencing issues, also try lowering the MTU:
```bash
sudo ./netgrip-tun.sh stop
```
```bash
sudo ./netgrip-tun.sh start --bypass-udp --mtu 1280
```

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
