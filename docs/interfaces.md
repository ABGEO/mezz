# Picking interface names

Mezz's `.env` has four interface variables. Three name real devices on the host (`WAN_IFACE`, `WIFI_IFACE`,
optionally `LAN_IFACE`); one is the bridge Mezz creates (`BR_IFACE`). Getting these right is the most common reason a
fresh setup fails to come up, so do it carefully.

This page assumes Linux with `iproute2` and `iw` available. Both ship in every modern distro. On Debian/Ubuntu they're
in `iproute2` and `iw` respectively.

## List what you have

```bash
ip -br link
```

You'll see something like:

```
lo               UNKNOWN        00:00:00:00:00:00
eth0             UP             aa:bb:cc:11:22:33
wlan0            DOWN           aa:bb:cc:44:55:66
enp3s0           DOWN           aa:bb:cc:77:88:99
```

Naming varies by distro and kernel: `eth0`/`wlan0` on older systems, predictable names like `enp3s0`/`wlp2s0` on
systemd, sometimes `wlx<mac>` for USB wifi adapters. Don't assume. Read what's actually there.

## `WAN_IFACE` (your uplink)

The interface that already has internet. Find it from the default route:

```bash
ip route show default
# default via 192.168.1.1 dev eth0 proto dhcp
```

The `dev` value is `WAN_IFACE`. This stays attached to your home network; Mezz only adds NAT and forwarding rules on
top of it.

> [!WARNING]
> Don't put your uplink into `LAN_IFACE`. `net-init` enslaves `LAN_IFACE` to the bridge, which would kill your internet
> the moment Mezz comes up. There's an explicit guard against `LAN_IFACE == WAN_IFACE`, but if you give them different
> names that both happen to be your uplink (e.g. via a bond or VLAN), the guard won't catch it.

## `WIFI_IFACE` (the AP radio)

A wifi NIC that supports AP mode. List wifi devices:

```bash
iw dev
```

Each block ends with `Interface <name>`. That name goes in `WIFI_IFACE`. Then check the radio supports AP:

```bash
iw list | grep -A 10 "Supported interface modes"
```

Look for `* AP` in the output. If it's missing, this adapter can act as client only and won't work as Mezz's access
point. See [realtek.md](realtek.md) for the most common culprits, or pick a different adapter (Atheros `ath9k`/`ath10k`
and Mediatek `mt76` are reliable picks).

The wifi NIC must be free when Mezz starts. If `NetworkManager` or `wpa_supplicant` is using it for a normal
client connection, hostapd will fail with `nl80211: Could not configure driver mode`. To release it:

```bash
sudo nmcli dev set wlan0 managed no            # NetworkManager-based distros
sudo systemctl stop wpa_supplicant@wlan0       # if you've got a per-iface unit
sudo rfkill unblock wifi                       # in case it's soft-blocked
```

`nmcli dev set ... managed no` is not persistent across NetworkManager restarts. To make it stick, drop a file in
`/etc/NetworkManager/conf.d/`:

```ini
# /etc/NetworkManager/conf.d/mezz.conf
[keyfile]
unmanaged-devices=interface-name:wlan0
```

Then `sudo systemctl restart NetworkManager`.

## `LAN_IFACE` (optional wired clients)

A second wired NIC for plugging RJ45 IoT devices into the same LAN. Mezz puts this in the bridge alongside the wifi
AP, so wired and wireless clients share one subnet, one DHCP pool, one DNS server.

Pick any wired interface that is not your uplink:

```bash
ip -br link | grep -v "$(ip route show default | awk '{print $5}')"
```

Leave `LAN_IFACE` empty for wifi-only setups; nothing else has to change.

## `BR_IFACE` (the Mezz bridge)

A name Mezz creates. Default `br0` works on most hosts. Make sure that name isn't already taken:

```bash
ip link show br0   # should print "Device 'br0' does not exist"
```

If it does exist (Docker default bridge, libvirt, an old setup), pick another name like `mezzbr0`.

## Quick identification cheatsheet

```bash
# what's wifi vs wired
iw dev                      # wifi only
ls /sys/class/net/*/wireless 2>/dev/null   # wifi only, alt method

# which driver and chipset (handy for AP-mode questions)
ethtool -i wlan0            # driver, firmware
lspci -k | grep -A 3 -i net # PCIe NICs
lsusb                       # USB wifi dongles

# does this radio do AP?
iw list | grep -A 10 "Supported interface modes"

# regulatory domain (affects which channels you can use)
iw reg get
```

If `iw reg get` shows `country 00`, set `WIFI_COUNTRY_CODE` in `.env` to your country. Some channels (especially in
the 5 GHz band) are illegal to transmit on without a regulatory domain set, and hostapd will refuse to start.
