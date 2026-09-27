---
name: configure
description: Show and change a mod's BepInEx settings — reads the mod's .cfg from the pod, lists every knob with its description, allowed values, default and current value, then applies the changes the user picks. Use for "configure <mod>", "what can I tweak in <mod>", "set <mod> setting X to Y". Takes the mod name as an argument, e.g. /configure ArgusMagnus/ServersideQoL_Backpack.
---

The argument is a mod name, usually in the Thunderstore `Author/Name` form
from `deploy/mods.txt`. Steps:

## 1. Find the cfg file

Cfg files live in `/config/bepinex/` in the pod. Their names come from the
plugin GUID, not the Thunderstore name, so resolve by matching:

```sh
kubectl -n valheim exec valheim-0 -c valheim -- ls /config/bepinex/ | grep -i '\.cfg$'
```

Drop the author and the `ServersideQoL_` prefix-style underscores, then pick
the file whose name contains the remaining words case-insensitively
(`ServersideQoL_Backpack` → `ArgusMagnus.ServersideQoL.Backpack.cfg`,
`NetworkPerformanceSystem` → `MidnightsFX.NetworkPerformanceSystem.cfg`).
Never pick a `.default` or `.old` file. If nothing matches or several files
do, show the listing and ask. If the mod is not in `MODS` at all, say so and
stop — configuring a mod that isn't installed is a mistake.

Special case: `akoozie.valheimtune.cfg` is **not** edited in place. Its
values are declarative via `VTCFG_*` in `deploy/config.env` and
regenerated on every boot (see mod-settings.md). Present the knobs the same
way, but apply changes as a git edit to the ConfigMap instead of step 3.

## 2. Present the knobs

`cat` the file. The BepInEx format is:

```
[Section]

## Description line(s)
# Setting type: Int32
# Default value: 4
# Acceptable values: A, B, C        (optional; or "# Acceptable value range: 0 to 100")
Key = value
```

Render one table per `[Section]` with columns **Setting · What it does ·
Type / allowed values · Default · Current**. Summarize long descriptions;
keep the substance, drop the author's examples. Mark rows where Current ≠
Default so the user sees what's already been tuned, and cross-check those
against `mod-settings.md` — if a non-default value is not recorded there,
say so.

Then ask what, if anything, they want to change. Do not edit anything on the
first pass; this skill is also used just to browse.

## 3. Apply changes

Only after the user names a setting and value. Validate the value against
the type / acceptable values in the file before touching anything.

Edit in place on the pod with `sed` on the exact `Key = ` line, then `grep`
it back to confirm:

```sh
kubectl -n valheim exec valheim-0 -c valheim -- sed -i 's/^Key = .*/Key = NEWVALUE/' /config/bepinex/<file>.cfg
kubectl -n valheim exec valheim-0 -c valheim -- grep -n '^Key = ' /config/bepinex/<file>.cfg
```

Keys can repeat across sections; if the key appears in more than one, anchor
the sed on the section instead (`/^\[Section\]/,/^\[/ s/.../.../`).

Whether the server must be stopped first depends on the mod. The
ServersideQoL family never writes its cfg back at runtime, so a live edit is
safe and takes effect on the next restart (nightly at 05:10, or via the
`restart` skill). For any other mod, assume it may overwrite the file on
shutdown: stop the server with `supervisorctl stop valheim-server` first,
edit, then run `scripts/restart.sh` — never `kubectl rollout restart` (see
CLAUDE.md). Tell the user which case applied and whether a restart is
pending.

## 4. Record it

`mod-settings.md` is the record of every non-default value. Add or update the
row under `### <file>.cfg` in "Non-default values" (create the subsection if
the file has none), with Setting / Default / Set to. If they set something back to its
default, remove the row. Do not commit unless asked.
