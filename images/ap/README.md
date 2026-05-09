# mezz-ap

Runs `hostapd` to provide the wifi access point for Mezz. Supports WPA2 + WPA3-SAE transition mode, IEEE 802.11d/n with
WMM, and exposes the hostapd control socket for healthchecks. Bridges the wifi interface onto the same Linux bridge the
wired LAN joins, so wired and wireless clients share one subnet.

## About Mezz

This image is part of [Mezz](https://github.com/ABGEO/mezz), a self-contained wifi sandbox for inspecting your own IoT
devices. Mezz turns a Linux host with a wifi NIC and a wired uplink into a small isolated network so you can watch
exactly what your devices do.

See the [project README](https://github.com/ABGEO/mezz#readme) for the full system description, setup, and source.
