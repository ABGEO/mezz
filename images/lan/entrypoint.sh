#!/bin/bash

set -euo pipefail

LOG_TAG=lan
. /usr/local/lib/mezz/helpers.sh

require_var \
  BR_IFACE \
  LAN_IP \
  LAN_DHCP_START \
  LAN_DHCP_END \
  LAN_NETMASK \
  LAN_DNS_UPSTREAM \
  LAN_DOMAIN

log info "rendering /etc/dnsmasq.conf"
envsubst < /etc/dnsmasq.conf.tpl > /etc/dnsmasq.conf

log info "validating dnsmasq config"
/usr/sbin/dnsmasq --test --conf-file=/etc/dnsmasq.conf

exec "$@"
