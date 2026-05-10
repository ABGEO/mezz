# Realtek wifi adapters

Realtek USB wifi sticks are cheap and everywhere, which makes them the most common cause of "Mezz starts but no SSID
shows up." Many of them either don't support AP mode at all, or only support it with out-of-tree drivers.

If you can swap to an Atheros (`ath9k`/`ath10k`) or Mediatek (`mt76`) adapter, do that first. They speak `nl80211`
natively and work as APs out of the box. The rest of this page is for when you can't.

## Identify the chipset

```bash
lsusb                                   # USB dongles
lspci -k | grep -A 3 -i net             # PCIe / M.2 cards
ethtool -i wlan0                        # driver + firmware
```

Match the output against the table below. The driver field is the most reliable signal; vendor strings sometimes lie
about which silicon is actually inside.

| Chipset family    | Mainline kernel driver | AP mode in mainline                      | Recommended driver                                                     |
|-------------------|------------------------|------------------------------------------|------------------------------------------------------------------------|
| RTL8188CU/8192CU  | `rtl8192cu`            | Broken, uses legacy `wext` not nl80211   | [pvaret/rtl8192cu-fixes](https://github.com/pvaret/rtl8192cu-fixes)    |
| RTL8188EU         | `r8188eu`              | Partial / unstable                       | [aircrack-ng/rtl8188eus](https://github.com/aircrack-ng/rtl8188eus)    |
| RTL8812AU/8821AU  | `rtw88` (some boards)  | Often missing                            | [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au)      |
| RTL8814AU         | none                   | n/a                                      | [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au)      |
| RTL8821CU/8811CU  | `rtw88_8821c`          | Spotty                                   | [morrownr/8821cu-20210916](https://github.com/morrownr/8821cu-20210916) |
| RTL8852AE/8852BE  | `rtw89`                | Yes on recent kernels (6.x and newer)    | mainline `rtw89`                                                        |
| RTL8723BU/DE      | `rtl8723bu`            | Often broken                             | community drivers, varies                                              |

## Verify AP mode

Whatever driver you end up with, the test is the same:

```bash
iw list | grep -A 10 "Supported interface modes"
```

Look for `* AP`. If it's missing, hostapd will refuse to start and Mezz can't use this adapter. No Mezz config change
will fix that. You need a working driver or a different NIC.

## Installing a community driver (DKMS)

DKMS rebuilds the driver every time the kernel updates, so you don't have to redo this after `apt upgrade`.

**Debian/Ubuntu prerequisites:**

```bash
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) dkms git
```

**Arch:**

```bash
sudo pacman -S base-devel linux-headers dkms git
```

**Fedora:**

```bash
sudo dnf install kernel-devel kernel-headers dkms git make gcc
```

Then build and install. The exact module version differs per repo, so read the project's README. As an example, for
RTL8812AU:

```bash
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
sudo make dkms_install
```

After install:

```bash
sudo modprobe -r <old_driver>           # e.g. rtl88XXau, rtw88_8822be
sudo modprobe <new_driver>              # name printed by the build
iw list | grep -A 10 "Supported interface modes"
```

If two drivers compete for the same chipset (common on Ubuntu, where the in-tree `rtw88` variant grabs the device
before the DKMS one does), blacklist the in-tree one:

```bash
echo "blacklist rtw88_8822be" | sudo tee /etc/modprobe.d/mezz-rtw-blacklist.conf
sudo update-initramfs -u                # Debian/Ubuntu
sudo reboot
```

Replace `rtw88_8822be` with whichever module `lsmod | grep rtw` shows is loaded but not the one you want.

## Power management

Realtek drivers default to aggressive power-save, which causes hostapd to drop clients or fail to beacon. Disable it:

```bash
# /etc/modprobe.d/mezz-realtek-pm.conf
options 8821au rtw_power_mgnt=0 rtw_enusbss=0
options 8812au rtw_power_mgnt=0 rtw_enusbss=0
```

Then `sudo modprobe -r <driver> && sudo modprobe <driver>` (or reboot).

The `rtw_*` option names depend on the driver. Check the README of whichever community driver you installed for the
exact knobs.

## Hostapd protocol mismatch

Some very old Realtek drivers only speak the legacy `wext` protocol, while hostapd expects `nl80211`. The community
drivers above all switched to `nl80211` years ago, so this only comes up if you're stuck on a vendor driver. The fix
is a Realtek-patched hostapd, but at that point getting a different NIC is genuinely cheaper than the maintenance
cost. Mezz doesn't ship a patched hostapd, and we don't recommend running one.

## Last resort: try lower-impact settings

If the radio works but is unreliable as an AP, narrow the surface area before debugging deeper:

```ini
# .env
WIFI_HW_MODE=g     # 2.4 GHz only; better driver coverage than 5 GHz
WIFI_CHANNEL=1     # known-good channel; avoid auto-select
```

This won't fix a missing AP mode, but it does eliminate a couple of common channel/regulatory edge cases that the
weaker Realtek drivers handle badly.
