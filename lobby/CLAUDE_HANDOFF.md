# Lobby revision — design and implementation handoff

## Scope and approval

The user requested a revised visual concept and a handoff for walk-in shop UI and a practice entrance that transfers players to a separate training area. This document specifies behavior; it does not implement it. The revised image is a proposal pending visual approval. Do not replace or rebuild the existing lobby from it without review. Inspect the actual Studio project first; the repository does not contain the current Studio-only services.

Preserve working combat, best-of-five matches, queue pads, respawning and camera systems. No publishing. Do not build progression, economy or additional modes as part of this change.

## Visual layout

- Single-floor converted industrial training facility, slightly lower ceiling than the first concept; charcoal walls, concrete floor, warm-white lights, orderly beams, restrained wear.
- Center spawn faces four matchmaking bays: 1v1, 2v2, 3v3, 4v4. Each bay has a flush blue pad on the left and red pad on the right. Preserve existing functional pad locations/interfaces unless a specific change is approved.
- Left: walk-in quartermaster shop with a wide entrance, counter and restrained weapon/cosmetic displays.
- Right: a clearly marked PRACTICE / TRAINING ACCESS doorway. No active firing range in the lobby. No glowing portal is needed.
- Behind spawn: WINS, ELIMINATIONS, WIN STREAK leaderboards.
- A separate practice room has pistol lanes with real backstops, a partitioned knife dummy bay and an obvious LOBBY return doorway.

The art is not a dimensioned plan. Review avatar scale and circulation before geometry changes. Do not add stairs, a second floor, flags, excessive neon or random clutter.

## Shop behavior

1. Use one explicit anchored, invisible shop zone volume. Inspect existing zone/UI conventions before adding a dependency or RemoteEvent. Geometry must not block characters or weapon rays.
2. On local-player entry, open one shop ScreenGui. On exit, close it. Determine entry/exit from the character root position in the zone, with boundary hysteresis so edge jitter does not flicker the menu; do not rely solely on Touched/TouchEnded.
3. Include an X close button. Closing while inside suppresses reopening until the player fully leaves and re-enters. No stacking copies or repeated open tweens.
4. Keep movement available so walking out works. Do not use a modal overlay that traps the player or locks them in first person. Restore any temporarily changed input state on close, death, match entry or UI destruction.
5. Match entry, death or character replacement closes the UI. A respawn should not accidentally open it from a stale character reference. Only enable it for eligible lobby players.
6. Reuse an existing inventory/catalog if present. If none exists, show an explicitly labeled preview catalog; disable purchases with a clear unavailable state rather than inventing currency, prices, ownership or rewards.
7. Cosmetic variants must not change damage, hitboxes, reach, fire rate or visibility advantages. Any future purchase/equip action must validate item IDs, price, balance, ownership and eligibility on the server. The UI does not authorize transactions.
8. Desktop, touch and controller close/navigation must work. Offer an interaction fallback for navigation/accessibility if the project's input design needs it; do not add a new input framework unnecessarily.

## Practice travel

Default to a separate arena within the SAME Roblox place, stored away from lobby and match geometry. Use a server-controlled character pivot, not TeleportService or a new place, unless the existing project requires otherwise. A same-place transfer needs no new Roblox place ID or credentials.

1. Place explicit server-side PracticeEntrance, PracticeSpawn, PracticeReturn and LobbyReturn markers/zones, using existing map conventions where possible. PracticeSpawn must have body clearance, safe ground and a defined facing.
2. Server detects entrance eligibility: living lobby character, not in a match, not already transferring. Practice entry must not race with matchmaking. Remove the player from a queue and make them ineligible for matching before moving; recheck the current match state within the same transition. If match entry already won, reject practice entry.
3. Use one authoritative location/state owner and derive client presentation from it. Do not let separate scripts disagree about Lobby/Practice/Match. Inspect the current Player attributes and MatchmakingService before choosing an attribute name or changing state flow.
4. Position practice so it cannot be shot from the lobby or match arena. Validate shots, melee and dummy damage on the server against practice eligibility and targets. Practice attacks must never damage lobby players, match players or other practicing players. A dedicated space alone is not sufficient isolation.
5. Reuse existing server-validated combat and loadout code only through an explicit practice policy. Current loadouts depend on InMatch and CanAttack/CanDamage, so a character teleport alone will not enable training. Do not set InMatch=true to bypass this: it would corrupt match eligibility and HUD/camera behavior.
6. Proposed training rules for review: first-person while practicing; one starting pistol bullet; a confirmed dummy elimination restores the bullet once; an empty miss equips knife. A visible reset action/station restores training targets and ammo so practice cannot soft-lock after a miss. Practice targets have no competitive rewards.
7. Do not switch DevConfig.TestMode on globally. Inspect the existing dev dummy code and isolate/reuse appropriate pieces without exposing test modes to matches.
8. Returning through the LOBBY doorway uses server-owned LobbyReturn, removes practice loadout and restores third-person lobby behavior. Return outside the practice trigger and queue pads to avoid loops or unintended queue entry.
9. Gate/debounce both transfers and prevent reentry until leaving the destination trigger. Handle simultaneous characters, repeated touch events, failed/missing destination, death, respawn, disconnect and match transition. Clear transient state on failure; never leave someone permanently marked as transferring.
10. RespawnService already owns non-match spawning with CharacterAutoLoads off. Default practice death/reset returns to the lobby using that existing owner; do not introduce a second character-loading loop. Coordinate cleanup with loadouts, UI and camera.
11. No practice progress, currency, elimination count, streak or match score changes. No RemoteEvent supplied destination CFrames or client-authoritative entry decisions.

## Delivery sequence

1. Read existing Studio services and report integration points; preserve a local backup.
2. Get visual approval of the revised lobby image before altering its design.
3. Implement shop zone/menu lifecycle with preview catalog if purchases do not exist. Test independently.
4. Implement server-owned practice travel and location eligibility; test queue/match races before enabling weapons.
5. Add isolated practice combat, dummy reset and return cleanup through existing systems. Keep changes narrow and explain why tested modules must change.
6. Show screenshots and complete the tests below before declaring it ready. Do not publish.

## Required Studio validation

- Shop: enter/exit, edge jitter, dismiss while inside, reenter, death/reset, match start while open, no duplicate GUIs, keyboard/touch/controller navigation.
- Practice: entry and return, trigger retrigger spam, missing destination handling, two users entering together, queue cancellation, practice entry simultaneous with match countdown.
- Confirm training works while InMatch remains false, cannot enter/attack during a match, and cannot damage other players. Verify practice cannot touch score/rewards or count dummy kills as competitive eliminations.
- Hit/miss, knife front/back damage as appropriate for practice dummy, one bullet award per dummy elimination, manual reset after a miss, repeatable dummy reset.
- Death/reset/disconnect during practice or transfer leaves no stuck state. Camera and loadout restore on return and next match. No lobby weapon damage.
- Rerun existing two-client best-of-five regressions: 3–0, 3–2, drawn round, timeout, countdown death, disconnect/forfeit, loadout reset and return to lobby.

These checks have NOT been run by ChatGPT. This package contains a concept image and handoff, not executable shop/practice code or a finished lobby model.
