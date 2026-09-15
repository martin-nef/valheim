# Valheim server

Dedicated Valheim server on Kubernetes, namespace `valheim`, StatefulSet
`valheim` (pod `valheim-0`, containers `valheim` + `mods` initContainer).
Manifests live in `deploy/` and are reconciled by **Flux** — config changes go
through git, never `kubectl edit`/`apply` by hand.

## Restarting the server

Use `scripts/restart.sh`. It stops the game process via supervisorctl (which
forces a world save — the pod's 30s grace period is too short to rely on
SIGTERM), verifies the save landed, deletes the pod so the `mods`
initContainer re-runs, and confirms BepInEx loaded the plugins.

- **Never `kubectl rollout restart`** — Flux strips the `restartedAt`
  annotation and the pod gets bounced a second time minutes later.
- `supervisorctl restart valheim-server` alone restarts the game process
  without re-running the mods init container; fine for cfg edits, not for
  mod changes.

## Mod settings

See [mod-settings.md](mod-settings.md).
