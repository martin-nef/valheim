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

| Modifier      | Default     | Set to   | Why                                                                                                 |
| ------------- | ----------- | -------- | --------------------------------------------------------------------------------------------------- |
| `Resources` | `Default` | `Most` | Maxed-out drop amounts. Fewer gathering trips per project; compounds with the smelter auto-feeding. |
| `DeathPenalty` | `Default` | `Easy` | One notch below default: smaller skill loss on death. Softens the sting of a bad run without removing the corpse run. |

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

| Setting                        | Default   | Set to   | Why                                                                                                                                                                 |
| ------------------------------ | --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CanSacrificeMegingjord`     | `false` | `true` | Destroy a megingjord in an obliterator to permanently unlock its carry-weight bonus. Costs the item and frees the belt slot, rather than handing out free capacity. |
| `CanSacrificeCryptKey`       | `false` | `true` | Destroy a crypt key in an obliterator to permanently open sunken crypt doors, freeing the inventory slot.                                                           |
| `InfiniteEncumberedStamina`  | `false` | `true` | Being over-weight is slow instead of a full stop.                                                                                                                   |
| `InfiniteBuildingStamina`    | `false` | `true` |                                                                                                                                                                     |
| `InfiniteFarmingStamina`     | `false` | `true` |                                                                                                                                                                     |
| `InfiniteMiningStamina`      | `false` | `true` |                                                                                                                                                                     |
| `InfiniteWoodCuttingStamina` | `false` | `true` |                                                                                                                                                                     |
| `InfiniteSneakingStamina`    | `false` | `true` |                                                                                                                                                                     |
| `InfiniteSwimmingStamina`    | `false` | `true` |                                                                                                                                                                     |

The infinite-stamina options don't disable the stamina bar — it still drains,
and tops back up just enough to continue when nearly empty. Combat stamina is
untouched. For genuinely infinite stamina everywhere the mod points at the
world's `StaminaRate` global key instead.

### ArgusMagnus.ServersideQoL.AutoPortalHub.cfg

| Setting                | Default   | Set to   | Why                                                                                                                                              |
| ---------------------- | --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `AutoNameNewPortals` | `false` | `true` | The hub identifies portals by tag; untagged portals get an entry with a blank sign. Auto-naming gives`Meadows 01`, `Swamp 03` etc. for free. |

### ArgusMagnus.ServersideQoL.JustSleep.cfg

| Setting                      | Default | Set to | Why                                                                |
| ---------------------------- | ------- | ------ | ------------------------------------------------------------------ |
| `RequiredPlayerPercentage` | `100` | `50` | At 100 a single AFK player blocks skipping the night for everyone. |

### ArgusMagnus.ServersideQoL.AutoStore.cfg

| Setting                               | Default      | Set to       | Why                                                                             |
| ------------------------------------- | ------------ | ------------ | ------------------------------------------------------------------------------- |
| `StackInventoryIntoContainersEmote` | `-1` (off) | `ThumbsUp` | Emote to stack your inventory into nearby chests that already hold those items. |

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

| Setting                                | Default   | Set to   | Why                                                                                                        |
| -------------------------------------- | --------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| `AssignShipsToCaptain`               | `false` | `true` | Ownership to whoever is steering. Removes desync-driven collisions with terrain and waves (not with mobs). |
| `AssignInteractablesToClosestPlayer` | `false` | `true` | Smelters, cooking stations etc. to the nearest player, to stop losing materials to networking issues.      |

Deliberately left off: `AssignMobsToClosestPlayer`. Ships and workstations have
one natural owner, but "closest player" is ambiguous when several people fight
one mob, and the mod says it eliminates desync *for that player* — which may
move the problem onto everyone else. Worth revisiting once we've seen how group
fights feel.

Note the author documents no reason for any of these being off by default; the
reasoning above is ours.

### ArgusMagnus.ServersideQoL.Skills.cfg

| Setting                                       | Default | Set to | Why                                                                                                                                                                                                                                                                                                                                                                          |
| --------------------------------------------- | ------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[Pickaxe] RockCollapseThresholdAtMinSkill` | `100` | `40` | Percentage of a rock/ore deposit's parts that must be destroyed before the rest collapses, at pickaxe skill 0. Scales linearly to`RockCollapseThresholdAtMaxSkill` (kept at `0`) at skill 100. At the default, a fresh character gets no benefit at all and the feature only pays off late; starting at 40% means mining is already ~2.5x faster from the first pickaxe. |


### ArgusMagnus.ServersideQoL.TameAssist.cfg

| Setting                                | Default   | Set to   | Why                                                                                                        |
| -------------------------------------- | --------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| `[TameAssist] MakeCommandable`       | `false` | `true` | Every tame can be told to follow/stay like a wolf, so boars and lox can be moved around instead of herded. |
| `[TameAssist] FedDurationMultiplier` | `1`     | `4`    | Tames stay fed four times as long after eating, so pens need topping up far less often.                    |

### ArgusMagnus.ServersideQoL.Backpack.cfg

| Setting               | Default           | Set to   | Why                                                                                               |
| --------------------- | ----------------- | -------- | ------------------------------------------------------------------------------------------------- |
| `OpenBackpackEmote` | `Wave`          | `Vibe` | Wave is used socially; Vibe is a dedicated trigger so the backpack doesn't pop open mid-greeting. |
| `MaxBackpackWeight` | `0` (unlimited) | `600` | Weight cap so the backpack is a pocket for odds and ends, not a second unlimited inventory. Raised from 300 on 2026-09-19. |
| `BackpackOnDeath` | `SameAsInventory` | `Keep` | Backpack contents survive death instead of going to the tombstone, so odds and ends aren't lost on a corpse run. |

### ArgusMagnus.ServersideQoL.AutoDoors.cfg

| Setting                      | Default | Set to | Why                                                                                                   |
| ---------------------------- | ------- | ------ | ----------------------------------------------------------------------------------------------------- |
| `AutoCloseMinPlayerDistance` | `4`     | `8`    | Doors stay open while anyone is still nearby, so they don't shut on a player who's just stepped away. |
| `AutoCloseMinOpenSeconds`    | `2`     | `30`   | Doors stay open long enough to carry things through or for a group to follow, instead of closing almost immediately. |

### com.Fire.FiresGhettoNetworkMod.cfg

Enabled 2026-09-19. Unlike the ServersideQoL family this mod may rewrite its
cfg on shutdown, so edit it with the game stopped (`scripts/restart.sh` flow).

| Setting                         | Default | Set to | Why                                                                                                                         |
| ------------------------------- | ------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| `Enable Server-Side Simulation` | `false` | `true` | Make the dedicated server authoritative over zones, monster AI and events. The EXPERIMENTAL ZDO ownership-transfer toggles stay off, so peers still own their ZDOs (`sim: ON · own: vanilla peer` in the FGN load summary). |

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
