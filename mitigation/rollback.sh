#!/usr/bin/env sh
set -euo pipefail

# Removes flow offload guard rules added by mitigation/apply.sh

RULESET="inet fw4 ft"
MARK_RULE="meta mark != 0 return"
NAT_RULE="ct status { dnat, snat } return"

log() { echo "[rollback] $*"; }

remove_rule() {
  local rule="$1"
  if nft list chain $RULESET 2>/dev/null | grep -F "$rule" >/dev/null 2>&1; then
    nft delete rule $RULESET $rule
    log "removed: $rule"
  else
    log "not present: $rule"
  fi
}

main() {
  if ! nft list chain inet fw4 ft >/dev/null 2>&1; then
    log "fw4 ft chain missing; nothing to rollback"
    exit 0
  fi
  remove_rule "$MARK_RULE"
  remove_rule "$NAT_RULE"
  /etc/init.d/firewall reload || /etc/init.d/firewall restart || true
  log "rollback complete"
}

main "$@"
