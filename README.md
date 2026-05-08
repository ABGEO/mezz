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

## Quick start

Grab the compose file and a starter `.env` from this repo, then bring it up:

```bash
mkdir mezz && cd mezz

curl -O https://raw.githubusercontent.com/ABGEO/mezz/main/docker-compose.yaml
curl -o .env https://raw.githubusercontent.com/ABGEO/mezz/main/.env.example

# Optional: edit .env to override interfaces, SSID, password, subnet, etc.
$EDITOR .env

docker compose up -d
```

To revert host network state:

```bash
docker compose run --rm net-init teardown
```

## Extending dnsmasq

Drop `*.conf` files into a local directory and mount it over `/etc/dnsmasq.d` in the `lan` service (see the commented
`volumes:` block in `docker-compose.yaml`). Useful for static DHCP leases, custom upstream rules, etc.
