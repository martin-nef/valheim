# Valheim server

Dedicated Valheim server on Kubernetes, namespace `valheim`, StatefulSet
`valheim` (pod `valheim-0`, containers `valheim` + `mods` initContainer).
Manifests live in `deploy/` and are reconciled by **Flux** — config changes go
through git, never `kubectl edit`/`apply` by hand.

Server env lives in `deploy/config.env`, the mod list in `deploy/mods.txt`.
Both feed a `configMapGenerator` with a content-hash name suffix, so committing
a change to either rolls the pod on its own (the `mods` initContainer re-runs
too). A preStop hook stops the game via supervisorctl first, bounded by
`SHUTDOWN_GRACE_PERIOD_SEC`, so the world saves on any pod teardown.

## Restarting the server

Use `scripts/restart.sh` when nothing in git changed (e.g. to pick up a new
mod release without a version pin). It stops the game process via
supervisorctl, verifies the save landed before touching the pod, deletes the
pod so the `mods` initContainer re-runs, and confirms BepInEx loaded the
plugins.

- **Never `kubectl rollout restart`** — Flux strips the `restartedAt`
  annotation and the pod gets bounced a second time minutes later.
- `supervisorctl restart valheim-server` alone restarts the game process
  without re-running the mods init container; fine for cfg edits, not for
  mod changes.

## Mod settings

See [mod-settings.md](mod-settings.md).
