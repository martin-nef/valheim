#!/usr/bin/env bash
# Safe restart of the Valheim server: saves the world, then rolls the pod so
# the `mods` initContainer re-runs. Do NOT use `kubectl rollout restart` here —
# the namespace is Flux-managed and Flux strips the restartedAt annotation,
# which bounces the pod a second time a few minutes later.
set -euo pipefail

NS=valheim
POD=valheim-0
CTR=valheim
WORLD=$(sed -n 's/^ *WORLD_NAME: *//p' "$(dirname "$0")/../deploy/configmap.yaml")
WORLD_DIR="/config/worlds_local/$WORLD"

kx() { kubectl -n "$NS" exec "$POD" -c "$CTR" -- "$@"; }

echo "== Stopping valheim-server (triggers world save; pod grace period is only 30s)"
kx supervisorctl stop valheim-server

echo "== Verifying $WORLD saved"
OK=$(kx sh -c "ls -t $WORLD_DIR/*.ok 2>/dev/null | head -1")
if [ -z "$OK" ]; then
  echo "!! No .ok marker in $WORLD_DIR — not rolling the pod. Check logs." >&2
  kx supervisorctl start valheim-server || true
  exit 1
fi
AGE=$(kx sh -c "echo \$(( \$(date +%s) - \$(stat -c %Y $OK) ))")
if [ "$AGE" -gt 120 ]; then
  echo "!! $OK is ${AGE}s old — save did not happen on shutdown. Not rolling the pod." >&2
  kx supervisorctl start valheim-server || true
  exit 1
fi
echo "   $OK written ${AGE}s ago"

echo "== Rolling pod"
kubectl -n "$NS" delete pod "$POD"
kubectl -n "$NS" rollout status "sts/$NS" --timeout=600s

echo "== Waiting for valheim-server"
until kx supervisorctl status valheim-server 2>/dev/null | grep -q RUNNING; do sleep 5; done
until kubectl -n "$NS" logs "$POD" -c "$CTR" 2>/dev/null | grep -q "Chainloader startup complete"; do sleep 5; done

echo "== Mods loaded:"
kubectl -n "$NS" logs "$POD" -c "$CTR" | grep -o 'Loading \[[^]]*\]' | sed 's/Loading //'
kubectl -n "$NS" logs "$POD" -c "$CTR" | grep -iE '\[(Error|Fatal)' || echo "   no BepInEx errors"
echo "== Done"
