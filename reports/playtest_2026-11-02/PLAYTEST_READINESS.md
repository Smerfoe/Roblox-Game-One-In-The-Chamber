# Playtest readiness: full match loop, combat rules, first person, HUD

**Date:** 2026-11-02
**Tested by:** Claude, in Roblox Studio on PC: solo Play plus three Server + 2–3 Clients sessions
**Not done:** the place was not published, nothing was merged, and the Studio place was not saved.

The scripts under `studio_sources/` are exact copies of the Studio scripts I changed (byte count and hash checked). They live in this report folder so they do not overwrite newer files in `src/` on GitHub.

## Fixes made

| # | Problem found | Fix | Script |
|---|---|---|---|
| 1 | After a respawn the first-person view sometimes had **no hands**. The weapon was shown before the avatar's arm parts had loaded, and the arms were never rebuilt. Seen in two-client rounds. | The viewmodel retries building the arms (at most twice a second) until the arm parts exist. Smallest possible change; Codex's animation code is untouched. | `ViewmodelController` (+13 lines, `ensureArms`) |
| 2 | The **round timer floated in the middle of the screen**, over the opponent. | The timer now sits in the top bar (`BLUE 1 - 0 RED   Round 2   2:35`) and turns red in the last 10 s. | `HudController` |
| 3 | Round and match results said "ROUND WON" / "VICTORY" but **not why**. | The server now sends a reason (`RoundReason`, `MatchReason`). The HUD shows "Last player standing", "Time ran out", "Both players were eliminated", "Your opponent left the game", "First to 3 round wins", and so on, plus the final score. | `MatchService`, `HudController` |
| 4 | **Controls** were never shown. | A controls line (LMB shoot/slash · 1/2 pistol/knife · F inspect · SHIFT sprint · C slide) shows during round loading, the countdown and in practice. It is hidden during combat. | `HudController` |
| 5 | **Empty pistol** gave no guidance. | With 0 ammo the HUD shows "Out of ammo - get a knife kill to reload" under the red AMMO 0. | `HudController` |
| 6 | After a match both players **spawned stacked** on the single lobby spawn, one standing on the other's head. | On return to the lobby, a player who lands within 3 studs of another steps 3 studs sideways (Blue left, Red right). | `MatchService` (`closeMatch`) |

New attributes `RoundReason` and `MatchReason` were added to the list cleared when a player leaves a match. No balance, economy, combat-rule, map or lobby-art changes.

**Backups:** `ServerStorage.Backups.BeforePlaytestReadiness_2026_11_02` holds MatchService, HudController and ViewmodelController as they were before these fixes. Codex's `BeforeFluentAnimationV1` and `BeforeKnifeMotionV1` backups are untouched, as are all older ones.

## Test results

### Passed (seen in Studio)

**Match loop.** 4 completed matches (3–2, 3–0, 3–1, and one ended by a player leaving) plus one partial match, 16 rounds over three Server + Clients sessions. The first session ran 9 rounds back to back without a restart.

| Check | Result |
|---|---|
| Queue from a lobby pad, and from PLAY GAME → 1v1 → QUEUE FOR MATCH | Match starts about 4 s after the second player queues; the countdown is 3 s |
| Best of five, 3–2 | Rounds won by a real pistol click, a knife (two front hits of 50), a backstab, and a pistol shot sent directly to the server |
| Final result | VICTORY / DEFEAT screen, then everyone returns to the lobby; a second match started straight away |
| Round ends | Drawn round when both die together ("both eliminated"). Draw by **timeout** after 180 s with both alive. |
| Player leaves mid-match | The other player gets Victory ("opponent left") and returns to the lobby |
| Player joins during an active match | Lands in the lobby with no match state. Their queue waits, and their match started as soon as the arena was free. |
| Lobby state after a match | Match attributes cleared, no tools in hand or backpack, FOV 70, mouse unlocked, one of each HUD (no duplicates) |
| Cleanup over rounds | Server workspace count went 2616 → 2668 in combat → 2616/2617/2618 back in the lobby. No leftover slide forces, tools, viewmodels, tracers or casings. |
| Spawns | 4 per team, each on solid floor with no geometry overlap. Spawn shields block direct line of sight between the two sides. |

**Combat rules** (server log confirmed):

| Check | Result |
|---|---|
| Miss | Costs the bullet (AMMO 0) and auto-switches to the knife |
| Hit | Kills and refunds the bullet (AMMO 1) |
| Knife | Front hit takes 50 HP, backstab kills, a knife kill refunds the bullet |
| Fire spam | 3 fire requests at once: 1 accepted, 2 rejected for fire rate |
| Knife spam | 2 swing requests at once: 1 accepted, 1 rejected for cooldown. 4 rapid real clicks produced 1 hit. |
| Empty gun | Can't fire (rejected server-side) |
| Who can deal damage | Dead players, lobby players and players outside Combat can't (checked in code and logs). Friendly-fire check is still in place; it isn't exercised in 1v1. |
| Effects | Only the server's raycast decides damage; effects never do. One shot gives exactly one sound, flash, casing and tracer (two-client check from earlier today still applies). |

**First person** (solo, foreground, frame-by-frame recordings):

| Check | Result |
|---|---|
| Inspect → fire | Clean |
| Inspect → switch weapon | Knife holsters, then the pistol draws from below; never two viewmodels or two sets of arms |
| Attack → switch | Clean |
| Sprint → slide → walk, slash during slide | FOV 70→73.5, back down smoothly |
| Death during inspect, during an attack, during a slide | Viewmodel and arms removed at once, FOV and camera offset reset. Respawn has a clean camera with only AudioListener. |
| Arms present (fix 1) | Re-checked over 4 more two-client rounds: arms present on both clients in every frame. |

**Inventory and economy:**

| Check | Result |
|---|---|
| DataTests | 13/13 passed |
| Test-armory rules | Refuses unowned equip ("Item is not owned"), bad item ids, purchases without enough coins, and anything while in a match ("Return to the lobby first") |
| Starter loadout | 1911 + Karambit given every round |

### Not tested, or could not be tested

- **Gameplay video with audio:** my tools can only take screenshots. Sounds were checked by confirming Sound instances were created, not by listening.
- **Saved data:** the real DataStore is untested because Studio API access is off. The game is on the memory fallback, and the server log says so ("Using an in-memory store; data is lost when the test stops").
- **Team modes:** 2v2–4v4 are disabled in MatchConfig, so friendly fire, team spectating and multi-spawn placement were not tested.
- **Other paths:** death during the countdown, the 15 s player-loading timeout, and the 9-round limit were reviewed in code but not triggered.
- **Platforms and screen sizes:** mobile, console and VR untested. Only the Studio window size was checked; other desktop aspect ratios weren't.
- **Clicks in two-client tests:** some kills used server-sent shots or server-side kills to drive rounds quickly. At least one real pistol click and one real knife click were used.

## Remaining issues, ranked for today's playtest

**Blocking:** none found.

**Worth knowing (not blocking):**
1. **The 1911 model is mirrored.** Safety on the right, ejection port on the left. Waiting on a Codex fix (see PR #5).
2. **Some sounds are missing.** Pistol equip is silent, and the Cloth, RackPull, RackRelease and DryFire cues have no audio. The DryFire animation (empty-gun click) also wasn't seen: with no ammo the game switches straight to the knife.
3. **Skins don't show** on the new 1911 art (SurfaceAppearance overrides Color/Material).
4. **Arena spawn view.** A player looks straight at their spawn shield at round start. This is intentional cover, but it can feel like facing a wall.
5. **Studio-only noise.** The test armory panel and some asset-upload warnings in Studio output ("RuntimePropertySet", "TexturePack property set failed to upload") are Studio-only and not script errors.
6. **Lobby art isn't final.** The industrial lobby is unchanged and still the plain version; the new design sample is waiting on your approval.

## How to start testing

1. Open the place in Studio. **Save it first** (File → Save to Roblox); this does not publish it.
2. Test → Start Test Session → **Server and Clients**, then use Test → Add Clients on the Server window to add a second (and third) player.
3. In each client, click **PLAY GAME → 1v1 → QUEUE FOR MATCH**, or stand on the blue or red pad under the 1v1 sign. The match starts automatically.
4. **Controls:**
   - LMB shoot / slash
   - 1 / 2 pistol / knife
   - F inspect
   - Shift sprint
   - C slide (while sprinting)
5. **Rules:** one bullet. A miss empties the gun and switches you to the knife; any kill refunds the bullet. First to 3 rounds wins; a round lasts at most 3 minutes.
6. Leave anytime by closing a client window. The remaining player wins and returns to the lobby.
