# One in the Chamber — Studio handoff (2026-10-30)

This is the record of what is built in the Roblox Studio place, how it fits together, and what has and has not been tested. The Studio place (Team Create, not published) is the source of truth. `src/` is a read-only snapshot of every script, exported from Studio on 2026-10-30. A change made only in `src/` does not reach the game; edit in Studio, then export again.

## Setup

- Place: "One In The Chamber" (placeId 123618973539191), Team Create on, auto-saved to the cloud. **Not published.**
- Studio test settings that were used: *Server & Clients* with 2 or 3 clients for anything involving matches; plain *Play* for solo checks.
- Players spawn in the lobby. `Players.CharacterAutoLoads` is off; `RespawnService` loads every non-match character.
- Backups in `ServerStorage.Backups` (scripts disabled):
  - `PreMatchLoop_2026-10-29`, `PreBestOfFive_2026-10-30` — from earlier stages.
  - `PreShopPractice_2026-10-30` — all scripts, shared config and the lobby model, saved before this round of work.
- Script Sync to a local folder was requested earlier and still has to be switched on by the user in Studio. **Unverified.**

## Where things are

| Instance | Purpose |
|---|---|
| `Workspace.Lobby/OITC_IndustrialLobby_COMPLETE_VISUAL_MODEL` | Lobby (116 × 124 studs, centred on the origin). `03_Shop.ShopZone` and `04_PracticeRange.PracticeEntrance` / `LobbyReturn` are invisible, non-colliding markers added in this round. The lobby's look was not changed. |
| `Workspace.TestingGrounds` | Original tested arena, centre (0, 0, 300). **Still the arena matches use** (`MatchConfig.Map`). |
| `Workspace.TestingGroundsNew` / `ContainerYard` / `PumpHouse` | The three new maps, centred at z = 600 / 900 / 1200. Integrated and tested; selected by changing `MatchConfig.Map`. |
| `Workspace.PracticeArea` | Practice room, centred at (400, 0, 0): enclosed and roofed, 64 × 44 studs. |
| `ServerStorage.Dev.TestDummy` | Dummy rig used for practice targets (and the old TestMode). |
| `ServerStorage.SourceAssets` | Raw 1911 and karambit imports. |
| `ReplicatedStorage.Assets.Weapons` | `Service1911`, `Karambit` tools. |
| `ReplicatedStorage.Remotes` | `Fire`, `Melee`, `ShotAccepted`, `SwingAccepted`, `WeaponEffect`, `Queue`, `Inventory` (equip requests, see `docs/PLAYER_DATA.md`). |
| `ServerScriptService.Data` | Player-data modules (config, schema, ProfileStore, MemoryStore, tests). See `docs/PLAYER_DATA.md`. |
| `ArenaMaps` (older ChatGPT package) | Set aside, untouched, as asked. |

## Architecture

Everything that matters is decided on the server. Clients send only "I pulled the trigger (aim direction)" and "I swung". The server reports state back through **player attributes**, which clients only read.

### Player state (attributes)

| Attribute | Owner | Meaning |
|---|---|---|
| `Location` | `LocationService` | `"Lobby"`, `"Practice"` or `"Match"`. The only place this is decided. |
| `MatchId`, `Team`, `Round`, `ScoreBlue`, `ScoreRed`, `MatchPhase`, `PhaseEndsAt`, `RoundResult`, `MatchResult` | `MatchService` | Match state. |
| `InMatch` | `MatchService` | Alive in the current round, holding weapons. |
| `Queue`, `QueueSource` | `MatchmakingService` | Mode id (e.g. "1v1") while queued; "Pad" or "Menu". |
| `DataStatus` | `DataService` | `Loading` / `Ready` / `Failed` / `Locked` / `Incompatible` / `Corrupt` / `SessionLost`. |
| `Skin_Service1911`, `Skin_Karambit` | `InventoryService` | Skin shown on each weapon (always a valid id). Tools also carry a `SkinId` attribute. |
| `Ammo` | `CombatService` | Read-only copy of the server's bullet count. |
| character `SpawnCFrame` | `MatchService` / `LocationService` | Which way the client turns the camera after a move. |

`Shared/PlayerState.IsArmed(player)` = `InMatch` **or** `Location == "Practice"`. Loadout, first-person camera, HUD, viewmodel and click-to-fire all key off this, so practice reuses every weapon system without ever setting `InMatch`.

### Server services (`ServerScriptService.Services`, started by `Init`)

- **MatchService** — best-of-five 1v1, phases Starting → Countdown → Combat → RoundEnd → … → Result → lobby. `CanAttack` and `CanDamage` hold the match combat rules. Change this round: `StartMatch` refuses a player whose `Location` is `"Practice"`.
- **MatchmakingService** — the single server-owned queue (rewritten 2026-10-30, Stage 3; the pre-change copy is in `ServerStorage.Backups.PreUnifiedQueue_2026-10-30`).
  - Pads and the Play Game menu (`Remotes.Queue`: `"Join", modeId` / `"Leave"`) both join the same per-mode queue. A player can be queued once; a second join is rejected ("Already queued").
  - **Teams are no longer chosen by pad colour.** When enough players are queued and the arena is free, the longest-waiting players are shuffled and split into Blue and Red. `MatchService` keeps those teams for every round. This is an intentional change from the earlier "Blue pad = Blue team" rule.
  - **Pad behaviour:** standing on either pad of a mode joins that mode's queue (source "Pad"). **Stepping off the pads removes a pad-joined player.** A menu-joined player is not affected by pads.
  - Pressing Leave while standing on a pad does not requeue the player: pads ignore them until they have stepped off all pads once.
  - A player also leaves the queue on death, disconnect, practice entry (`Release`) or being put in a match.
  - Menu requests are rejected with a reason for: disabled mode, not in the lobby, dead, in a match, already queued, or less than 0.5 s since the last request.
- **CombatService** — pistol and knife validation, server raycasts, eliminations and the one-bullet reward. Changes this round: `AddPolicy({CanAttack, CanDamage})` lets other services add narrow extra rules, which are checked after the match rules; `RefillAmmo(player)` was added.
- **LoadoutService** — gives or removes the pistol and knife when `IsArmed` changes.
- **RespawnService** — the only loader of non-match characters (death in the lobby or in practice → a new lobby character after 3 s).
- **LocationService** (new) — owns `Location`. It polls the entrance and return zones (0.1 s) and moves players with a server pivot inside the same place.
  - Entry is refused if the player is in a match, not alive, already moving, on cooldown, or the spawn marker is missing.
  - Before moving, the player is taken off the queue and marked Practice, with no yield in between, so matchmaking can never grab a half-moved player.
  - A new character always resets `Practice` to `Lobby`.
- **PracticeService** (new) — places dummies at `PracticeArea.TargetMarkers` (two pistol lanes and a knife bay), each marked `PracticeTarget`. Eliminated dummies respawn after 3 s.
  - Registers the practice combat policy: a living Practice player may attack, and may damage **only** dummies inside `PracticeArea.ActiveTargets`, never a player.
  - The reset station (ProximityPrompt, E / gamepad / touch) restores all targets and the user's bullet. Entering practice restores the bullet.
- **TestModeService / TestDummyService** — old free-for-all dev mode; `DevConfig.TestMode = false`.

### Client controllers (`StarterPlayerScripts.Controllers`, started by `ClientInit`)

Camera, Weapon, Knife, Hud, Viewmodel and WorldEffects (as before, now using `IsArmed`), Spectate, and **Shop** (new).

- **ShopController** — opens the menu while the character's root is inside `ShopZone`.
  - Hysteresis: the root must be 0.5 studs inside to open and 1.5 studs outside to close.
  - X (or controller B) closes the menu until the player leaves and comes back.
  - Lobby players only; death, respawn, practice or a match closes it. One `ShopGui` per session.
  - Movement and camera stay free.
  - The catalog is `Shared/Config/ShopCatalog`: an explicit **preview**. Every item shows "UNAVAILABLE"; there is no currency, price, ownership or purchase code.
- **CameraController** — when first person ends without a new character (practice → lobby), the camera now zooms back out to third person.
- **SpectateController** — after elimination (Combat or RoundEnd), it follows a living teammate (Q/E, arrows, L1/R1, click, on-screen arrows). With no teammate left, it shows an overview of the arena in `MatchConfig.Map`.

### Other change

- `StarterPlayer.StarterCharacterScripts.Health` (empty script) replaces Roblox's default health regeneration. Before this, a player hit by the knife for 50 healed about 1 HP/s, so two front hits could fail to eliminate. This was found during map testing.

## Map and spawn requirements

`MatchService` reads `workspace[MatchConfig.Map].Spawns.Blue|Red` and places each player at the first child (sorted by name), lifted 3 studs. A map must have:

- `Spawns/Blue/Spawn1` and `Spawns/Red/Spawn1`: anchored, transparent, non-colliding parts 0.5 studs above the floor top, with their front facing the map centre. Add `Spawn2…` for future team sizes.
- A model in `Workspace` under the name given in `MatchConfig.Map`, with no overlap with other maps or the lobby. The spectator overview is framed from the model's bounding box.
- Structural parts collidable and queryable (they stop bullets); decoration `CanCollide = CanQuery = CanTouch = false`.
- One active match at a time; only one map is used, chosen by `MatchConfig.Map`. There is no rotation or voting.

### Changes made to the three new maps (from `maps/models` @ c56b556)

All three were imported unchanged, then given these edits:

| Change | Why (confirmed in Studio) |
|---|---|
| Both sightline shields 9 → 12 studs tall (all maps) | With our jump (JumpHeight 7.2) a player could climb onto a 9-stud shield from the floor in 8/8 tries. In Container Yard the shield top led on to the container roofs (3/3). |
| Testing Grounds interior baffle 9 → 11 tall | Same climb (2/2); now matches the 11-stud house walls. |
| Container Yard cargo crates 3.5 → 2.5 tall (top bands moved down with them) | From a 3.5-stud crate a player reached a container roof in 3/3 tries. Now 0/3. |
| Blue spawn turned 180° (all maps) | It faced away from the centre. |
| Spawn markers converted to `Spawns/Blue/Spawn1`, `Spawns/Red/Spawn1` at floor + 0.5, facing the centre; `PrimaryPart = Ground.Foundation` | Our existing spawn interface. No match code was changed. |
| Renamed the new Testing Grounds to `TestingGroundsNew` | Keeps the original `TestingGrounds` intact as the working arena and backup. |

Re-checked after the fixes: 0/36 open spawn-to-spawn sight lines on each map, standing and at jump height. Shields, baffle and container roofs could not be climbed in any attempt. The Testing Grounds flank barriers do not reach the house walls (6/6 attempts). Pump House tanks collide as true cylinders, and the tops of the plinths and tanks could not be reached.

## Test results (2026-10-30)

**Passed — tested in Studio:**

- **Shop (solo):**
  - Enter opens and walking out closes the menu. Edge jitter across the boundary gave 0 flips in 20 samples.
  - X and controller B dismiss it until reentry; walking around inside or to the edge does not reopen it.
  - Death closes it; the respawned character reopens it only after walking back in.
  - One GUI copy throughout.
  - With 3 clients: the menu was open when the player walked to a pad and a match started. It stayed closed through the match and the return to the lobby.
- **Practice (solo + 3 clients):**
  - Entry through the lobby entrance and return through the LOBBY door.
  - Loadout, first-person camera and HUD in practice. On return, tools are removed, the camera goes back to third person (12 studs) and no viewmodel remains.
  - Pistol eliminates a target and restores the bullet. A miss switches to the knife. Knife front hit (50) and backstab work. The reset station restores targets and ammo. Dummies respawn.
  - Re-trigger spam is refused (cooldown / not in lobby). Missing spawn marker: entry refused and the player stays in the lobby.
  - Death in practice → lobby character with `Location = Lobby`.
  - A practice player standing on a pad is never queued, and `StartMatch` refuses a practice player.
  - Race: a queued player walked into practice in the same server step that the opponent stepped on a pad → no match; one Practice player and one queued player.
  - A player in a match dragged into the entrance during the countdown stayed in the match.
  - A practice shot and backstab on another practicing player did 0 damage; a shot and backstab on a lobby player standing in the room did 0 damage.
  - Practice ran during a live match without changing its score.
- **Spectating (3 clients, recorded every frame on the eliminated client):**
  - The overview appears about 0.2 s after elimination and the normal camera returns at the next round.
  - When the final elimination ends the match, the camera goes straight to the result with no overview flash.
  - Lobby camera restored after the match.
- **Best-of-five on Testing Grounds (3 clients):**
  - Round results covered: elimination, timeout draw (round time temporarily 25 s), death during the countdown awarding the round, and both players eliminated at once (drawn round).
  - Matches covered: a 3–2 Victory/Defeat, then a match ended by a disconnect ("opponent left").
  - Loadout removed and players returned to the lobby both times.
- **New maps (2 clients each), TestingGroundsNew, ContainerYard and PumpHouse:**
  - Both players placed exactly on their spawns, grounded and facing the centre.
  - Spectator overview framed on the right map.
  - 3–1 or 3–0 matches completed, then the return to the lobby.
  - Container Yard: a pistol shot through a container was blocked by `Container_0_12EastShell`. Knife front hits landed.
  - Pump House: health stayed at 50 for 6 s after the regeneration fix.
- Temporary test values (`RoundTime = 25`, `Map`) were restored: `Map = "TestingGrounds"`, `RoundTime = 180`.

**Not tested / unverified:**

- Teammate spectating and team friendly fire (no 2v2 yet; only tested earlier with a fake harness).
- Real touch screens and a physical gamepad (B close and the reset prompt were checked with simulated input only).
- A disconnect during the middle of a combat round in this session (it happened in RoundEnd; mid-combat disconnects passed in earlier sessions).
- Map climbing was tested with a server-driven humanoid using our real jump settings, not a human at the keyboard.
- Map visuals at eye height beyond the screenshots, lighting in Container Yard's tunnels (very dark), and performance on devices.
- Script Sync.

## Known issues

1. The lobby still has the old in-lobby range on the right. Its floor area is now the practice entrance zone. The concept's "PRACTICE / TRAINING ACCESS" doorway, and the rest of the lobby rebuild, **wait for visual approval**.
2. The practice room is plain, functional geometry (charcoal concrete, lane dividers, signs, warm lights). It has not had a visual pass.
3. Container Yard tunnels are very dark inside, which hurts readability.
4. The 1911's grip cannot be coloured separately (single mesh).
5. Fixed 2026-10-30: the camera used to show the old position (lobby pad) for a moment when a round started. A dark "SpawnCover" now covers loading until the camera has reached the spawn.
6. Map choice is a manual setting; only one match can run at a time.
7. Pushes from Claude's session to GitHub are refused; see the commit note in the PR or bundle.

## Recommended next task

A small, explicit **map-selection step**: `MatchService` picks the map per match from a list in `MatchConfig` (round-robin, no voting), keeping one active match. After that comes the approved lobby rebuild, then the 2v2 pads (teammate spectating and friendly-fire tests become possible).
