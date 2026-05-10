# Troubleshooting

Common ways Mezz fails to come up, and how to diagnose them. Most issues are environmental (a daemon holding the wifi
NIC, an interface name typo, or a chipset that doesn't do AP mode), not Mezz itself.

For driver-level wifi problems (especially Realtek USB adapters), see [realtek.md](realtek.md).

## First, look at the logs

```bash
docker compose ps                   # which services are up / healthy
docker compose logs net-init        # one-shot setup; should exit 0
docker compose logs ap              # hostapd
docker compose logs lan             # dnsmasq
docker compose logs mitm            # only when COMPOSE_PROFILES=mitm
```

`net-init` runs once and exits. `ps` will show it `Exited (0)` if it succeeded. A non-zero exit means nothing else
will start, so always check it first.

## `net-init` exits non-zero

### `LAN_IFACE ($X) must differ from WAN_IFACE ($Y)`

You set the two to the same interface. Pick a different `LAN_IFACE`, or leave it empty for wifi-only.

### `Cannot find device "wlan0"` (or any other interface)

The name in `.env` doesn't match a real device. List what's there with `ip -br link` and update
`WIFI_IFACE`/`WAN_IFACE`/`LAN_IFACE`. See [interfaces.md](interfaces.md).

### `RTNETLINK answers: File exists` when creating the bridge

`BR_IFACE` (default `br0`) is already in use. Common owners are Docker's default bridge, libvirt, or an old run of
Mezz that didn't tear down cleanly. Either teardown the old state:

```bash
docker compose run --rm net-init teardown
```

or change `BR_IFACE` in `.env` to something free, e.g. `mezzbr0`.

### `Operation not permitted` on `sysctl` or `iptables`

The container needs `privileged: true` (already set in the shipped compose file). If you've customized the compose
file, check that flag is still there on `net-init`. Writing `/proc/sys/net/ipv4/ip_forward` needs RW `/proc/sys`, and
plain `CAP_NET_ADMIN` doesn't grant that.

## `ap` (hostapd) won't start or keeps restarting

```bash
docker compose logs ap
```

### `nl80211: Could not configure driver mode`

Something else on the host already owns the wifi NIC. Usually NetworkManager or `wpa_supplicant`.

```bash
sudo nmcli dev set wlan0 managed no            # NetworkManager
sudo systemctl stop wpa_supplicant@wlan0       # stop client mode
sudo rfkill unblock wifi                       # in case it's blocked
docker compose up -d --force-recreate ap
```

To make the NetworkManager opt-out persistent, see the snippet in [interfaces.md](interfaces.md#wifi_iface-the-ap-radio).

### `Could not set channel for kernel driver` / `kernel reports: Driver does not support this`

Either the radio doesn't support AP mode at all, or it doesn't support AP mode on the channel you picked.

Check AP support:

```bash
iw list | grep -A 10 "Supported interface modes"
```

Look for `* AP`. If it's missing, this adapter is client-only. Pick a different NIC, or for Realtek check the
[Realtek doc](realtek.md).

If AP mode is supported but the channel still fails, try a known-good 2.4 GHz channel:

```ini
WIFI_HW_MODE=g
WIFI_CHANNEL=1
```

5 GHz (`WIFI_HW_MODE=a`) often needs DFS support and a correct `WIFI_COUNTRY_CODE`. Start on 2.4 GHz to isolate the
problem.

### `country_code=XX: Invalid country code` / channel rejected as not allowed

Set `WIFI_COUNTRY_CODE` in `.env` to your actual country (e.g. `US`, `DE`, `JP`). Verify with `iw reg get`. Some
channels are illegal without a regulatory domain set, and hostapd refuses to start rather than transmit.

### Healthcheck fails but hostapd looks fine in logs

The healthcheck pings the hostapd control socket. If hostapd is running but the socket isn't where it expects, the
container will be marked unhealthy. Compose still keeps it running. If clients can associate, you can ignore the
unhealthy state for now and report the chipset/driver combo as a bug.

## Clients associate but get no IP

DHCP is `dnsmasq`, which runs in the `lan` container.

```bash
docker compose logs lan | grep -i dhcp
```

Common causes:

- **`net-init` didn't finish.** `lan` `depends_on` `net-init`, but if `net-init` exited non-zero, dnsmasq never bound
  to the bridge. Re-check `docker compose logs net-init`.
- **DHCP range outside the LAN subnet.** `LAN_DHCP_START` and `LAN_DHCP_END` must be inside the subnet implied by
  `LAN_IP` + `LAN_NETMASK`. Default `10.15.0.1/24` with `10.15.0.10`..`10.15.0.100` is fine; if you change the subnet,
  update both.
- **Bridge IP not assigned.** `ip addr show $BR_IFACE` should show `LAN_IP`. If it's missing, `net-init` failed mid-way.
  Run teardown and bring everything up again.

## Clients have an IP but no internet

```bash
# from a client:
ping 1.1.1.1                    # IP routing OK?
nslookup example.com 10.15.0.1  # DNS via dnsmasq OK?
```

Check the host:

```bash
# IPv4 forwarding actually on?
sysctl net.ipv4.ip_forward       # must be 1

# NAT rule installed?
sudo iptables -t nat -S POSTROUTING | grep MASQUERADE

# forwarding chain accepts the bridge -> WAN?
sudo iptables -S FORWARD
```

If forwarding is off or rules are missing, `net-init` didn't run successfully. Its very first job is to set those
exact things. Check its logs.

If everything looks right but clients still can't reach the internet, the host's WAN provider may filter by source MAC
(some hotels and ISPs do this). Mezz can't fix that side of the link.

## DNS resolves nothing

Stream dnsmasq logs and trigger a query from a client:

```bash
docker compose logs -f lan
```

Look for `dnsmasq: failed to send packet: Network is unreachable`. That means the upstream `LAN_DNS_UPSTREAM` isn't
reachable from the host. Try `1.1.1.1` or `9.9.9.9` (Mezz's defaults) first to rule out a captive upstream resolver.

If queries go out and time out, the host firewall (iptables, ufw, firewalld, nftables) may block outbound traffic
from containers in `network_mode: host`. Mezz can't sandbox around host firewall rules.

## mitm: web UI is unreachable

Mezz binds mitmweb on `0.0.0.0:${MITM_WEB_PORT}` (default 8081). If it's not reachable:

- `docker compose logs mitm`. Confirm it actually started and didn't bail on the password env var.
- The host firewall may be blocking 8081. `sudo ss -tlnp | grep 8081` should show python listening.
- `MITM_WEB_PASSWORD` empty means mitmweb prints a random token at startup that you must use to log in. Set a static
  password in `.env` if that's annoying.

## mitm: no traffic in the proxy

If clients can browse but the mitmproxy flow list is empty:

- Check `MITM_ENABLED=true` is set in `.env`. `COMPOSE_PROFILES=mitm` alone only starts the container; the iptables
  redirect on tcp/{80,443} is gated separately.
- `sudo iptables -t nat -S PREROUTING | grep REDIRECT` should show the rule.

## mitm: HTTPS shows up but nothing decodes

Modern apps and most IoT firmwares pin certificates. They'll either reject mitmproxy's CA outright (`SSL handshake
failed` in mitmproxy) or silently fail and stop talking. There's no client-side workaround you can apply from the AP
side; pinned-cert traffic is out of scope for transparent interception.

For browsers and a small number of cooperating apps, install the mitmproxy CA on the client (download from
`http://mitm.it` while connected to Mezz).

## After teardown the host has no internet

`docker compose run --rm net-init teardown` flushes iptables, removes the bridge, and brings the wifi NIC down. It
does **not** re-attach the wifi NIC to NetworkManager. If you set `unmanaged-devices` per
[interfaces.md](interfaces.md#wifi_iface-the-ap-radio), the host won't reconnect automatically. Either:

- bring the host back online via your wired uplink (which Mezz never managed), or
- temporarily re-manage the wifi: `sudo nmcli dev set wlan0 managed yes`.

If your wired uplink is also broken after teardown, restart NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

That re-applies the host's normal config and clears any leftover state.

## IPv6 stopped working on the host

`net-init` disables IPv6 globally on the host (`net.ipv6.conf.all.disable_ipv6=1`) because the Mezz LAN is IPv4-only
and we don't want IPv6 leaking through unNATted. To re-enable on the host after teardown:

```bash
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
```

Make it persistent via `/etc/sysctl.d/` if you regularly cycle Mezz.

## Reset everything

When in doubt:

```bash
docker compose down
docker compose run --rm net-init teardown
sudo systemctl restart NetworkManager     # if you use NM
docker compose up -d
```
