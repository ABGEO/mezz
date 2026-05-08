interface=$WIFI_IFACE
bridge=$BR_IFACE
ssid=$WIFI_SSID
country_code=$WIFI_COUNTRY_CODE
ieee80211d=1
hw_mode=$WIFI_HW_MODE
channel=$WIFI_CHANNEL
ieee80211n=1
wmm_enabled=1
auth_algs=1

# WPA2 + WPA3 (SAE) transition
wpa=2
wpa_passphrase=$WIFI_PASSWORD
wpa_key_mgmt=WPA-PSK SAE
wpa_pairwise=CCMP
rsn_pairwise=CCMP
ieee80211w=1
disassoc_low_ack=1

# Control socket for hostapd_cli (used by healthcheck)
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
