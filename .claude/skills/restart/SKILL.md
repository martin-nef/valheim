---
name: restart
description: Safely restart the Valheim server — saves the world, rolls the pod so new mods install, verifies plugins loaded. Use for "restart the server", "reload mods", "roll the pod".
---

Run `scripts/restart.sh` from the repo root with Bash (timeout 600000) and
report: the save timestamp it verified, the list of plugins BepInEx loaded,
and any `[Error`/`[Fatal` lines. If it aborts because the save could not be
verified, do not delete the pod by hand — show the user the script's output.

Never use `kubectl rollout restart` (see CLAUDE.md).
