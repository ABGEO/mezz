#!/bin/bash

set -euo pipefail

LOG_TAG=net-init
. /usr/local/lib/mezz/helpers.sh

# Clear any prior bridge/iface state. Tolerates missing interfaces, so safe
# to call from both init and teardown.
reset_interfaces() {
  {
    ifconfig "$BR_IFACE" 0.0.0.0
    ifconfig "$BR_IFACE" down
    ifconfig "$WIFI_IFACE" 0.0.0.0
    ifconfig "$WIFI_IFACE" down

    if [ -n "${LAN_IFACE:-}" ]; then
      ifconfig "$LAN_IFACE" 0.0.0.0
      ifconfig "$LAN_IFACE" down
    fi

    brctl delbr "$BR_IFACE"
  } 2>/dev/null || true
}

do_init() {
  require_var \
    BR_IFACE \
    WAN_IFACE \
    WIFI_IFACE \
    LAN_IP \
    LAN_NETMASK

  # Enslaving the WAN interface to the bridge would kill the uplink. Catch
  # the typo before touching any state.
  if [ -n "${LAN_IFACE:-}" ] && [ "$LAN_IFACE" = "$WAN_IFACE" ]; then
    log error "LAN_IFACE ($LAN_IFACE) must differ from WAN_IFACE ($WAN_IFACE)"
    exit 1
  fi

  log info "enabling IPv4 forwarding; suppressing IPv6"
  sysctl -w net.ipv4.ip_forward=1
  sysctl -w net.ipv6.conf.all.forwarding=0
  sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1

  log info "resetting prior bridge/iface state"
  reset_interfaces

  log info "bringing up base interfaces"
  ifconfig "$WIFI_IFACE" up
  ifconfig "$WAN_IFACE" up

  if [ -n "${LAN_IFACE:-}" ]; then
    ifconfig "$LAN_IFACE" up
  fi

  log info "creating bridge $BR_IFACE"
  brctl addbr "$BR_IFACE"

  if [ -n "${LAN_IFACE:-}" ]; then
    brctl addif "$BR_IFACE" "$LAN_IFACE"
  fi

  ifconfig "$BR_IFACE" up
  ifconfig "$BR_IFACE" inet "$LAN_IP" netmask "$LAN_NETMASK"

  log info "configuring iptables (NAT/forwarding)"

  for t in filter nat mangle raw; do
    iptables -t "$t" --flush
    iptables -t "$t" -X
  done

  iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i "$BR_IFACE" -o "$WAN_IFACE" -j ACCEPT

  log info "net-init done"
}

do_teardown() {
  require_var \
    BR_IFACE \
    WIFI_IFACE

  log info "flushing iptables (all tables) and removing user-defined chains"
  for t in filter nat mangle raw; do
    iptables -t "$t" --flush || true
    iptables -t "$t" -X || true
  done

  log info "tearing down bridge $BR_IFACE and bringing down $WIFI_IFACE"
  reset_interfaces

  log info "net-teardown done"
}

cmd="${1:-init}"
case "$cmd" in
  init)     do_init ;;
  teardown) do_teardown ;;
  *)        echo "usage: $0 {init|teardown}" >&2; exit 2 ;;
esac
