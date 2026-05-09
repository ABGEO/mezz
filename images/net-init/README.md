# mezz-net-init

Sets up the host networking that the rest of Mezz runs on: enables IPv4 forwarding, suppresses IPv6, creates the bridge
interface, brings up the wifi and (optional) wired LAN interfaces, and installs iptables NAT and forwarding rules. Runs
once on `docker compose up`, exits, and is also used (`docker compose run --rm net-init teardown`) to revert host
network state.

## About Mezz

This image is part of [Mezz](https://github.com/ABGEO/mezz), a self-contained wifi sandbox for inspecting your own IoT
devices. Mezz turns a Linux host with a wifi NIC and a wired uplink into a small isolated network so you can watch
exactly what your devices do.

See the [project README](https://github.com/ABGEO/mezz#readme) for the full system description, setup, and source.
