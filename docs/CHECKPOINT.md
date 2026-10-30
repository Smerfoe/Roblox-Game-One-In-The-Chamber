# Checkpoint — 2026-10-30 (UI stages 1–2)

Studio place: "One In The Chamber", Team Create, **not published**. The Studio scripts match `src/` exactly (lengths were checked after every edit). See `docs/HANDOFF.md` for the full architecture and the earlier shop/practice/map results.

## Completed this session

**UI stage 1: shared foundation**

New modules:
- `StarterPlayerScripts/UI/Theme`: the colour, spacing and text tokens from `ui/README.md`.
- `UI/Components`: shared building blocks.
  - ScreenGui factory with safe-area insets (`CoreUISafeInsets`), uniform scaling for small screens, and one GUI per session.
  - Buttons with primary, secondary and disabled styles.
  - Standard menu panel (title, tab row, X).
  - SOON / PREVIEW tags.
- `UI/Icons`: one original icon set drawn from Frames: Store, Inventory, Modes (two pistols), Stats, Settings.
- `Controllers/MenuController`: the single owner of which menu is open.
  - Opening one menu closes the current one.
  - Open menus close automatically when the player is in a match, in practice or dead.
  - Menus never lock the camera or input.

**UI stage 2: lobby**

- `Controllers/LobbyHudController` (new):
  - Top-left profile: avatar, name, level, XP bar and coins. Progression and coins don't exist yet, so they say "not available yet".
  - Bottom PLAY GAME button with five tiles.
  - Profile/Stats menu: statistics show "Not available yet"; the equipped section shows the real standard 1911 and karambit.
  - Hidden outside the lobby. PLAY GAME is hidden while a menu is open.
- `Controllers/ShopController` (rewritten):
  - It is now the "Store" menu: centred, with a 3-column grid of preview cards that use live ViewportFrame renders of the real 1911 and karambit.
  - The hotbar tile and the walk-in shop zone open the same menu.
  - Closing while inside the shop keeps the menu closed until the player leaves and comes back; hysteresis and controller B are kept.
  - Everything is marked UNAVAILABLE / PREVIEW.
- Backup taken before the changes: `ServerStorage.Backups.PreUIFoundation_2026-10-30` (old controllers).
- Screenshots: `docs/screenshots/ui_store_menu.jpg`, `ui_profile_menu.jpg`, `ui_lobby_hud_after_match.jpg`, `practice_room.jpg`.

## Tests

**Passed**

- Solo:
  - Store tile opens the Store; the Stats tile replaces it with the Profile menu (one menu at a time). X closes.
  - The profile card opens Profile.
  - Walking into the shop opens the Store. After Profile replaced it inside the shop, walking around inside did not reopen it. Leaving and re-entering reopened it.
  - Entering practice hides the HUD and closes menus; returning through the LOBBY door shows them again.
  - Death with a menu open closes it; respawn shows the HUD again.
  - No duplicate GUIs.
- 2 clients (recorded every frame on Player2):
  - The Store was open when the match started; it closed at match start.
  - Hotbar, profile and PLAY GAME stayed hidden through Starting, Countdown, Combat, RoundEnd, spectating and Result.
  - First person in combat and Classic camera otherwise.
  - The 3–1 match completed, and the HUD came back in the lobby. No duplicate GUIs.

**Not run**

- Real touch screen and a physical gamepad.
- Very small phone viewports. Scaling was only seen at Studio's window size.
- Visual check of the Modes / Inventory icons at large size.

**Failed:** none outstanding.

## Not started (in order)

- Stage 3: Play Game mode cards and a unified menu+pad queue with server random teams.
- Stage 4: inventory and skins.
- Stage 5: store details and categories.
- Stage 6: sleek match/practice HUD.
- Stage 7: spectate-a-living-player.
- From the newer brief: weapon prototype review, Python skin workflow, six team maps, team modes.

Docs from the newer brief not yet read: `weapons/README.md`, `weapons/WESTERN_AND_KNIVES.md`, `maps/team_maps/CLAUDE_HANDOFF.md`.

## Blockers / limitations

- **Git push from Claude's session is refused** (the Claude GitHub App has no write access to `Smerfoe/Roblox-Game-One-In-The-Chamber`). The commits are on local branch `claude/shop-practice-maps`, rebased on `main` @ d04f671, and delivered as a git bundle. To land them, run `git fetch <bundle> claude/shop-practice-maps` and push, or install/re-link the Claude GitHub App.
- No player-data/progression service exists. That makes level, XP, coins, stats, skin ownership and persistence unavailable, and stage 4 needs a decision on the data layer: the brief says "persist only through the existing data layer", and there isn't one.

## Exact next task

Stage 3, unified queue:
1. Replace the colour-specific 1v1 pad slots in `MatchmakingService` with one server-owned mode queue. The pads become "join 1v1 queue" (keep the visuals); the Play Game/Modes menu sends Join/Leave through one new RemoteEvent; duplicate joins are rejected.
2. In `MatchService.StartMatch`, assign Blue/Red randomly once per match; teams stay fixed for all rounds.
3. Build the mode-card screen (1v1 enabled; 2v2–4v4 "Coming soon") with queue status and Leave.
4. Test with 2 clients: pad+menu deduplication, leaving, races with practice entry, both team perspectives, and the full best-of-five regressions.
