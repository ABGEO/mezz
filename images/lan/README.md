# mezz-lan

Runs `dnsmasq` to provide DHCP and DNS for the Mezz LAN. DHCP hands out leases with the bridge IP as gateway and DNS
server; DNS forwards to a configured upstream, strips AAAA records (the LAN is IPv4-only), serves a local domain so
clients resolve as `name.lan`, and logs every query and lease event for inspection.

## About Mezz

This image is part of [Mezz](https://github.com/ABGEO/mezz), a self-contained wifi sandbox for inspecting your own IoT
devices. Mezz turns a Linux host with a wifi NIC and a wired uplink into a small isolated network so you can watch
exactly what your devices do.

See the [project README](https://github.com/ABGEO/mezz#readme) for the full system description, setup, and source.
