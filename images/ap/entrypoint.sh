#!/bin/bash

set -euo pipefail

LOG_TAG=ap
. /usr/local/lib/mezz/helpers.sh

require_var \
  WIFI_IFACE \
  BR_IFACE \
  WIFI_SSID \
  WIFI_PASSWORD \
  WIFI_COUNTRY_CODE \
  WIFI_HW_MODE \
  WIFI_CHANNEL

mkdir -p /var/run/hostapd

log info "rendering /etc/hostapd/hostapd.conf"
envsubst < /etc/hostapd/hostapd.conf.tpl > /etc/hostapd/hostapd.conf

exec "$@"
