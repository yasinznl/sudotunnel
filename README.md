sudotunnel

A minimal installer that creates a persistent GRE tunnel using systemd.

-   Works after reboot
-   Interactive + non-interactive install
-   GRE is NOT encrypted (use WireGuard or GRE over IPsec if you need
    encryption)

------------------------------------------------------------------------

Requirements

-   Linux with systemd
-   iproute2 (ip command)
-   curl or wget

------------------------------------------------------------------------

## Quick Install
```bash
curl -fsSL https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh | sudo bash
```


Safer 2-step alternative:
```bash
curl -fsSL -o install.sh
https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh
sudo bash install.sh
```
------------------------------------------------------------------------

Install (non-interactive)
```bash
sudo bash <(curl -fsSL
https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh)
–local-ip 193.111.111.111
–remote-ip 185.222.222.222
–tun-ip 10.10.0.0
–peer-ip 10.10.0.1
–cidr 31
```
Recommended: use /31 for point-to-point /31 avoids network/broadcast
mistakes (common with /30).

Example: - Server A: 10.10.0.0/31 - Server B: 10.10.0.1/31

------------------------------------------------------------------------

Setup on the second server

Run the installer on BOTH servers.

Server A: sudo bash <(curl -fsSL
https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh)
–local-ip A_PUBLIC_IP
–remote-ip B_PUBLIC_IP
–tun-ip 10.10.0.0
–peer-ip 10.10.0.1
–cidr 31

Server B: sudo bash <(curl -fsSL
https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh)
–local-ip B_PUBLIC_IP
–remote-ip A_PUBLIC_IP
–tun-ip 10.10.0.1
–peer-ip 10.10.0.0
–cidr 31

------------------------------------------------------------------------

Manage the service

sudo systemctl status sudotunnel –no-pager sudo systemctl restart
sudotunnel sudo systemctl stop sudotunnel

------------------------------------------------------------------------

Test

From Server A: ping 10.10.0.1

From Server B: ping 10.10.0.0

------------------------------------------------------------------------

Uninstall
```bash
sudo ./install.sh –uninstall
```

Or (if installed via curl): 
```bash
sudo bash <(curl -fsSL
https://raw.githubusercontent.com/yasinznl/sudotunnel/main/install.sh)
–uninstall
```
------------------------------------------------------------------------

Troubleshooting

1)  GRE must be allowed (IP protocol 47) GRE is IP protocol 47 (not
    TCP/UDP). Your firewall and/or provider must allow it.

2)  Check logs journalctl -u sudotunnel –no-pager -n 80

3)  Check tunnel interface ip a show sudotunnel ip tunnel show

4)  MTU issues (optional) If you see packet loss or strange behavior,
    try lowering MTU: sudo ./install.sh –mtu 1450 sudo systemctl restart
    sudotunnel

------------------------------------------------------------------------

Security Note

GRE does NOT encrypt traffic. If you need encryption, consider: -
WireGuard - GRE over IPsec
