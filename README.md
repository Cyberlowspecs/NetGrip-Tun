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
sudo mv tun2socks-linux-amd64 /usr/local/bin/tun2socks
sudo chmod +x /usr/local/bin/tun2socks
```

### 2. Download the Script
Clone this repository or download the script directly:
```bash
git clone [https://github.com/YOUR_USERNAME/Vanguard-Global-Proxy.git](https://github.com/YOUR_USERNAME/Vanguard-Global-Proxy.git)
cd Vanguard-Global-Proxy
sudo chmod +x global-proxy.sh
```

---

## 🚀 How to Use (Non-Xray Users)
*Use this guide if you are connecting to a standard SOCKS5 proxy (like an SSH tunnel or a commercial proxy).*

**To Start the Proxy:**
Run the script with `start`, followed by your Proxy IP and Port.
```bash
sudo ./global-proxy.sh start 192.168.1.50 1080
```
*(If you run `sudo ./global-proxy.sh start` without an IP and port, it defaults to `127.0.0.1` and `10808`)*.

**To Stop the Proxy and Restore Normal Internet:**
```bash
sudo ./global-proxy.sh stop
```

That's it! Once started, all applications on your system (including Flatpaks and Wine games) are now securely routed through your SOCKS5 proxy.

---

## ⚡ How to Use (Xray / V2Ray Users)
*Use this guide if you are running Xray-core locally. We must configure a bypass group so Xray itself doesn't get routed into the proxy, which would cause an infinite traffic loop.*

### Step 1: Create the bypass group
We need to create a dedicated Linux user group named `xray-direct`.
```bash
sudo groupadd xray-direct
```

### Step 2: Configure Xray to run under this group
You must start your Xray client under this specific group so the firewall knows to let its traffic pass through normally.

**Method A: Running manually**
```bash
sudo -g xray-direct xray run -c config.json
```

**Method B: Systemd Service (Recommended)**
If you run Xray as a background service, edit your systemd file. Open the file using `vim` (or your preferred editor):
```bash
sudo vim /etc/systemd/system/xray.service
```
Under the `[Service]` section, add the `Group` parameter:
```ini
[Service]
...
Group=xray-direct
...
```
Then reload and restart the service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart xray
```

### Step 3: Start the Global Routing
Now that Xray is safely bypassing the tunnel, start the script. (Assuming Xray's inbound SOCKS port is the default `10808`):
```bash
sudo ./global-proxy.sh start
```

To revert back to normal:
```bash
sudo ./global-proxy.sh stop
```

---

## 🔍 Troubleshooting

If your internet drops completely after starting the script:
1. Ensure your SOCKS5 proxy is actually running and accepting connections.
2. Check the script's log file to see what `tun2socks` is reporting:
   ```bash
   cat /var/log/tun2socks.log
   ```
3. **Xray Users:** Ensure you correctly ran Xray under the `xray-direct` group. If Xray runs as `root` without the group flag, its traffic gets caught in the proxy loop and your internet will freeze. 
