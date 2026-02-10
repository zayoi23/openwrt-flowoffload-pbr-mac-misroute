#!/usr/bin/env sh
set -euo pipefail

# Installs flow offload guard for PBR/NAT on OpenWrt (firewall4).
# Usage: ssh root@router 'sh -s' < apply.sh

RULESET="inet fw4 ft"
MARK_RULE="meta mark != 0 return"
NAT_RULE="ct status { dnat, snat } return"

log() { echo "[mitigation] $*"; }

ensure_chain() {
  if ! nft list chain inet fw4 ft >/dev/null 2>&1; then
    echo "fw4 flowtable chain not found; is firewall4 running?" >&2
    exit 1
  fi
}

rule_absent() {
  ! nft list chain $RULESET 2>/dev/null | grep -F "$1" >/dev/null 2>&1
}

install_rule() {
  local rule="$1"
  if rule_absent "$rule"; then
    nft insert rule $RULESET $rule
    log "inserted: $rule"
  else
    log "present: $rule"
  fi
}

main() {
  ensure_chain
  install_rule "$MARK_RULE"
  install_rule "$NAT_RULE"
  /etc/init.d/firewall reload || /etc/init.d/firewall restart || true
  log "mitigation active (PBR/NAT flows stay off flowtable)"
}

main "$@"
