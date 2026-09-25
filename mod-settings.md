# Mod settings

Which mods are installed is declarative: the `MODS` list in
[deploy/mods.txt](deploy/mods.txt), installed by the `mods`
initContainer in [deploy/statefulset.yaml](deploy/statefulset.yaml).

Their *settings* are not. The BepInEx `.cfg` files under `/config/bepinex/` on
the `data` PVC are edited in place, because the auto-generated comments in them
are the only documentation these mods have — regenerating them from environment
variables would strip that. This file is the record of every value we changed;
anything not listed here is at its default.

To change a setting: edit the file in the pod, then restart. Stop the server
process first so the running plugins don't write their in-memory config back
over your edit.

```sh
kubectl -n valheim exec valheim-0 -c valheim -- supervisorctl stop valheim-server
kubectl -n valheim exec -it valheim-0 -c valheim -- vi /config/bepinex/<file>.cfg
kubectl -n valheim delete pod valheim-0   # not rollout restart — see CLAUDE.md
```

Deleting a `.cfg` regenerates it at defaults on next start, which is the way
back if one of these turns out to be a bad idea.

The one exception to editing in place is ValheimTune, whose settings *are*
declarative — see `VTCFG_*` and `POST_BEPINEX_CONFIG_HOOK` in the ConfigMap.
The image's `env2cfg` merges those into the cfg on every boot, so editing
`akoozie.valheimtune.cfg` by hand will not survive a restart.

## World modifiers

Vanilla world modifiers are *not* mod settings, but they are server state that
isn't otherwise in git, so they belong here. These are set declaratively via
`SERVER_ARGS` in [deploy/config.env](deploy/config.env), which the image
appends to the server command line.

| Modifier      | Default     | Set to   |
| ------------- | ----------- | -------- |
| `Resources` | `Default` | `Most` |
| `DeathPenalty` | `Default` | `Easy` |

Options are `MuchLess`, `Less`, `Default`, `More`, `Most` for `Resources`, and
`Casual`, `VeryEasy`, `Easy`, `Default`, `Hard`, `Hardcore` for `DeathPenalty`.

Two things to know about these:

- **They are applied to the world on startup and written into the world file.**
  Deleting a modifier from `SERVER_ARGS` does *not* revert the setting — the
  world keeps whatever was last applied. To undo, set it to `Default`
  explicitly (e.g. `-modifier DeathPenalty Default`), start once, and only then
  remove it.
- **A misspelled name or value is loud, not silent.** The server logs
  `Key enum couldn't be parsed!` / `Value enum couldn't be parsed!` and carries
  on with the previous value, so check the logs after a change.

Other modifiers available on the same syntax: `Combat`, `Raids`,
`Portals`, `PlayerEvents`. Left at default deliberately — the game is balanced
and tested at default, and we'd rather not stray far.

## Non-default values

### ArgusMagnus.ServersideQoL.Player.cfg

Installed 2026-09-09 for the carry-weight option. Every feature in this mod is
off by default.

| Setting                        | Default   | Set to   |
| ------------------------------ | --------- | -------- |
| `CanSacrificeMegingjord`     | `false` | `true` |
| `CanSacrificeCryptKey`       | `false` | `true` |
| `InfiniteEncumberedStamina`  | `false` | `true` |
| `InfiniteBuildingStamina`    | `false` | `true` |
| `InfiniteFarmingStamina`     | `false` | `true` |
| `InfiniteMiningStamina`      | `false` | `true` |
| `InfiniteWoodCuttingStamina` | `false` | `true` |
| `InfiniteSneakingStamina`    | `false` | `true` |
| `InfiniteSwimmingStamina`    | `false` | `true` |

The infinite-stamina options don't disable the stamina bar — it still drains,
and tops back up just enough to continue when nearly empty. Combat stamina is
untouched. For genuinely infinite stamina everywhere the mod points at the
world's `StaminaRate` global key instead.

### ArgusMagnus.ServersideQoL.AutoPortalHub.cfg

| Setting                | Default   | Set to   |
| ---------------------- | --------- | -------- |
| `AutoNameNewPortals` | `false` | `true` |

### ArgusMagnus.ServersideQoL.AutoStore.cfg

| Setting                               | Default      | Set to       |
| ------------------------------------- | ------------ | ------------ |
| `StackInventoryIntoContainersEmote` | `-1` (off) | `ThumbsUp` |

Deliberately left off: `AutoPickup`. It would drag dropped items into chests
automatically, but it activates `AutoPickupRequestOwnership`, which the mod's
own description says "will drastically decrease performance". The emote above
gets most of the benefit on an explicit player action instead of a poll.

If the emote turns out to be unreliable — specific emotes are harder to detect
on bad connections and crossplay — the mod recommends `-2`, meaning any emote
triggers it.

### ArgusMagnus.ServersideQoL.MultiplayerTweaks.cfg

Both of these reassign Valheim's network ownership of an object to a specific
player, so the person who cares most about an object's behaviour is the one
simulating it.

| Setting                                | Default   | Set to   |
| -------------------------------------- | --------- | -------- |
| `AssignShipsToCaptain`               | `false` | `true` |
| `AssignInteractablesToClosestPlayer` | `false` | `true` |

Deliberately left off: `AssignMobsToClosestPlayer`. Ships and workstations have
one natural owner, but "closest player" is ambiguous when several people fight
one mob, and the mod says it eliminates desync *for that player* — which may
move the problem onto everyone else. Worth revisiting once we've seen how group
fights feel.

Note the author documents no reason for any of these being off by default; the
reasoning above is ours.

### ArgusMagnus.ServersideQoL.Skills.cfg

| Setting                                       | Default | Set to |
| --------------------------------------------- | ------- | ------ |
| `[Pickaxe] RockCollapseThresholdAtMinSkill` | `100` | `40` |


### ArgusMagnus.ServersideQoL.TameAssist.cfg

| Setting                                | Default   | Set to   |
| -------------------------------------- | --------- | -------- |
| `[TameAssist] MakeCommandable`       | `false` | `true` |
| `[TameAssist] FedDurationMultiplier` | `1`     | `4`    |

### ArgusMagnus.ServersideQoL.Backpack.cfg

| Setting               | Default           | Set to   |
| --------------------- | ----------------- | -------- |
| `OpenBackpackEmote` | `Wave`          | `Vibe` |
| `MaxBackpackWeight` | `0` (unlimited) | `600` |
| `BackpackOnDeath` | `SameAsInventory` | `Keep` |

### ArgusMagnus.ServersideQoL.AutoDoors.cfg

| Setting                      | Default | Set to |
| ---------------------------- | ------- | ------ |
| `Enabled`                    | `true`  | `false` |
| `AutoCloseMinOpenSeconds`    | `2`     | `30`   |

### com.Fire.FiresGhettoNetworkMod.cfg

Enabled 2026-09-19. Unlike the ServersideQoL family this mod may rewrite its
cfg on shutdown, so edit it with the game stopped (`scripts/restart.sh` flow).

| Setting                         | Default | Set to |
| ------------------------------- | ------- | ------ |
| `Enable Server-Side Simulation` | `false` | `true` |

### torokal.afkmanager.cfg

Installed 2026-09-25 (`Torokal/AFKManager`). Not part of the ServersideQoL
family, so edit it with the game stopped.

| Setting                | Default | Set to  |
| ---------------------- | ------- | ------- |
| `AfkAfterMinutes`      | `10`    | `5`     |
| `AnnounceInChat`       | `true`  | `false` |
| `AnnounceNotification` | `true`  | `false` |
| `ManualAfkEmote`       | `rest`  | `sit`   |

### ArgusMagnus.ServersideQoL.PortalProgression.cfg

| Setting       | Default | Set to |
| ------------- | ------- | ------ |
| `PortalRange` | `4`     | `2`    |

## Notable defaults we are keeping

Worth knowing about, since they're already doing a lot of work:

- **PortalProgression** gates metals through portals behind the matching boss —
  copper/tin after Elder, iron after Bonemass, silver after Moder, black metal
  after Yagluth, flametal after Fader. Setting a metal to `--` removes its
  requirement entirely. Left as-is: this is the one grind that's doing real
  pacing work, and single metals can be relaxed later if one becomes a slog.
- **AutoProcess** already auto-feeds smelters from containers within 4m.
  `CapacityMultiplier` and `TimePerProductMultiplier` are the knobs if ore
  throughput becomes the bottleneck.
- **SmartDefense** already auto-rearms traps and reloads ballistas from nearby
  containers, and stops them targeting players and tames.
