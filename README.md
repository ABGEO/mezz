# Mezz

Mezz is a self-contained wifi sandbox for inspecting your own IoT devices. The name comes
from [mezzanine](https://en.wikipedia.org/wiki/Mezzanine), the half-floor between two main floors of a building. This
network sits in the same place: between your devices and the rest of your home network.

> [!CAUTION]
> Mezz is provided for educational purposes and authorized penetration testing only. Use it on networks and devices you
> own, or on which you have explicit written permission to test. The author accepts no responsibility for any misuse or
> for damage caused by use of this software.

## What it does

Turns a Linux host with two NICs (one wifi, one wired uplink) into a small isolated network:

- a wifi access point on its own subnet
- DHCP and DNS for any client that connects (wifi or wired)
- NAT out through your wired uplink
- a local domain, so clients resolve as `kitchen-pi.lan` etc.
- per-query DNS logging, so you can see exactly what your fridge is talking to

It's defensive only. Made for inspecting devices you own, not for impersonating someone else's network.

## Prerequisites

- a Linux host (kernel with `iptables`, `bridge`, and `nl80211`; any modern distro is fine)
- Docker Engine 20.10+ with the Compose v2 plugin
- a wifi NIC that supports **AP mode**. Verify with `iw list | grep -A 10 "Supported interface modes"` and look for
  `* AP`. If your radio doesn't list AP mode, it can't be Mezz's access point. Realtek USB sticks are the most common
  offenders; see [docs/realtek.md](docs/realtek.md).
- a wired uplink (`WAN_IFACE`) for NAT
- (optional) a second wired NIC if you want to plug RJ45 IoT devices into the same LAN as the wifi clients
- root on the host. `net-init` runs `privileged` because writing `/proc/sys/net/ipv4/ip_forward` needs RW `/proc/sys`

If `NetworkManager` or `wpa_supplicant` is currently using the wifi NIC for a normal client connection, release it
first or hostapd will fail to start. The exact incantations are in
[docs/interfaces.md](docs/interfaces.md#wifi_iface-the-ap-radio).

## Quick start

Grab the compose file and a starter `.env` from this repo, then bring it up:

```bash
mkdir mezz && cd mezz

curl -O https://raw.githubusercontent.com/ABGEO/mezz/main/docker-compose.yaml
curl -o .env https://raw.githubusercontent.com/ABGEO/mezz/main/.env.example

# Edit .env. At minimum set WAN_IFACE / WIFI_IFACE to match your host.
# See docs/interfaces.md for how to find the right values.
$EDITOR .env

docker compose up -d
```

To revert host network state:

```bash
docker compose run --rm net-init teardown
```

If something doesn't come up, start with [docs/troubleshooting.md](docs/troubleshooting.md). Most issues are
environmental (a daemon holding the wifi NIC, a misnamed interface, or an adapter that doesn't do AP mode).

## Extending dnsmasq

Drop `*.conf` files into a local directory and mount it over `/etc/dnsmasq.d` in the `lan` service (see the commented
`volumes:` block in `docker-compose.yaml`). Useful for static DHCP leases, custom upstream rules, etc.

## Optional services

Mezz ships extra containers behind Docker Compose profiles. Pick what you want with `COMPOSE_PROFILES` in `.env` (
comma-separated, e.g. `mitm` or `mitm,tcpdump`). The base set (`net-init`, `ap`, `lan`) always runs.

| Profile | What it adds                                                  |
|---------|---------------------------------------------------------------|
| `mitm`  | mitmproxy in transparent mode for LAN HTTP/HTTPS interception |

### mitm

Set both in `.env`:

```
COMPOSE_PROFILES=mitm
MITM_ENABLED=true
```

`COMPOSE_PROFILES=mitm` brings up the mitmproxy container; `MITM_ENABLED=true` tells `net-init` to add the iptables
redirect (LAN tcp/{80,443} -> mitmproxy). Without the env flag the container runs but no traffic reaches it. Web UI is
on `http://<host>:${MITM_WEB_PORT}` (default `8081`); set `MITM_WEB_PASSWORD` to skip the random token mitmweb prints
on startup.

Only clients that trust the mitmproxy CA produce decryptable traffic. Pinned-cert apps (most modern phones, many IoT
clouds) won't show up in clear.

## Documentation

- [docs/interfaces.md](docs/interfaces.md): picking values for `WAN_IFACE`, `WIFI_IFACE`, `LAN_IFACE`, `BR_IFACE`,
  including how to verify your wifi adapter supports AP mode and how to release it from NetworkManager
- [docs/troubleshooting.md](docs/troubleshooting.md): common failure modes (`net-init` exit codes, hostapd refusing
  to start, clients with no IP / no internet, mitm caveats) with diagnostic commands and fixes
- [docs/realtek.md](docs/realtek.md): chipset-specific guidance for Realtek wifi adapters, which often need
  out-of-tree drivers to support AP mode
