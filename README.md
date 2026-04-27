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

## 🔍 Troubleshooting

If your internet drops completely after starting the script:
1. Ensure your SOCKS5 proxy is actually running and accepting connections.
2. Check the script's log file to see what `tun2socks` is reporting:
   ```bash
   cat /var/log/tun2socks.log
   ```
3. **Xray Users:** Ensure you correctly ran Xray under the `xray-direct` group. If Xray runs as `root` without the group flag, its traffic gets caught in the proxy loop and your internet will freeze. 

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
