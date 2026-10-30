# Checkpoint — 2026-10-30 (Stage 3: Play Game and unified queue)

Studio place: "One In The Chamber", Team Create, **not published**. The Studio scripts match `src/` (byte lengths checked after every edit). Architecture and earlier results are in `docs/HANDOFF.md`.

Backups in `ServerStorage.Backups`:
- `PreUIFoundation_2026-10-30`
- `PreUnifiedQueue_2026-10-30`: all services, shared config, client controllers and UI, saved before this stage.

## Completed

**Stale spawn camera (fixed).** `CameraController` now has a dark "SpawnCover" screen. It shows while a round is loading (Starting), and during the Countdown until the camera itself has reached the spawn. The match HUD ("ROUND n") still draws on top of it.

**Unified queue: `MatchmakingService` rewritten.**
- One server-owned queue per mode, shared by the pads and the menu, with duplicate-join rejection.
- Join requests are validated and rate-limited.
- Teams are assigned at random by the server and stay fixed between rounds; pad colour no longer decides the team.
- Pad rules:
  - stepping off removes a player who joined on a pad;
  - Leave pressed while on a pad doesn't requeue until the player steps off;
  - menu-joined players are unaffected by pads.
- New `Remotes.Queue`.
- `MatchConfig.Modes`: 1v1 is enabled; 2v2, 3v3 and 4v4 are listed but disabled.

**Play Game screen: new `PlayController` (menu "Play").**
- PLAY GAME and the MODES tile open it, and the hotbar hides while it is open.
- Four mode cards: 1v1 is selectable; the others show COMING SOON.
- QUEUE FOR MATCH / LEAVE QUEUE.
- Status shows not queued, joining/leaving (pending), "In the 1v1 queue (joined on a pad / joined here)", and rejected with the server's reason. A pending request that gets no answer times out.
- No team choice and no fake wait times or counts.
- Screenshots: `docs/screenshots/ui_play_screen.jpg`, `ui_play_queued.jpg`.

## Tests

**Passed**

- Solo:
  - Play screen opens and the hotbar hides. Join leads to "In the 1v1 queue (joined here)". Two quick clicks did Join and then Leave, never a double join.
  - A menu-joined player stepping on a pad stays a menu entry; stepping off doesn't remove them.
  - A duplicate menu join is rejected.
  - Pad join, then Leave while on the pad: not requeued while standing there, nor after moving to the other pad. After stepping off and back on, they join again.
  - A pad-joined player who steps off is removed.
  - Join while in practice is rejected ("Return to the lobby to queue"). Join for 2v2 is rejected (not available).
- 2 clients:
  - Random teams: over 4 matches, the Blue-pad player was Red twice, Blue once, then Red again.
  - Race: a menu-queued player walked into practice in the same server step the opponent stepped on a pad. Result: Practice for one, still queued for the other, no match. After returning, the match started normally.
  - Teams were identical in all 5 rounds of a 3–2 match.
  - Full best-of-five 3–2 and 3–1 matches completed and returned to the lobby.
  - Both perspectives: a Red player won (Victory) and a Blue player lost (Defeat), each from their own side.
  - Spawn cover: 0 frames of stale camera on either client across a 5-round match. (The first attempt still showed 1 frame before the round started; that is fixed and retested.)
- Earlier stages (shop, practice, the UI foundation, the lobby screen) are unchanged by this stage, apart from the HUD visibility rule for the Play screen.

**Not run / untested platforms**

- Mobile/touch and gamepad on real devices (controller B closes the Play screen; only simulated in Studio).
- Small phone viewports.
- 2v2–4v4 (disabled; MatchService is still 1v1 only).
- Disconnect while queued was only covered by code review (`PlayerRemoving` removes the player).

**Failed:** none outstanding.

## Next stage (approved)

Build the **player-data save system** as its own stage before persistent inventory:
- a `DataService` using Roblox DataStoreService;
- a versioned schema (inventory, equipped skins, room for progression);
- `UpdateAsync` for safe writes, with retry and backoff;
- session locking, and a "loaded" flag so a failed load never saves over good data;
- a separate Studio store name or scope, so tests never touch production data;
- developer-only test grants, with no crates or purchases.

After that comes Stage 4, inventory and skins.

## Foundry export for the environment build (2026-10-30)

- Exported the working Foundry (original + `DetailPass_v1`) to `maps/exports/Foundry_Current.rbxmx` / `.rbxm`. The notes are in `maps/exports/FOUNDRY_NOTES.md` and the screenshots in `maps/exports/screenshots/foundry/`.
- **Foundry decoration is paused** while the full environment build happens elsewhere. The v2 builder in `maps/exports/drafts/` was never run.
- The review place is saved locally as `Documents\Place1OITC_TeamMapReview_2026-10-30.rbxl`; the original Foundry is kept in its `ServerStorage.TeamMapOriginals`.
- Merged `main` (team map models) into this branch; there were no conflicts.
