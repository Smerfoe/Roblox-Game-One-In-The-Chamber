# Expanded player profile — latest visual direction

Reference: **[concepts/PlayerProfile.png](concepts/PlayerProfile.png)**. This is the latest requested expanded profile, replacing the earlier overview/statistics/loadout-tab concept. It opens when the player clicks their compact top-left profile badge or the hotbar Stats tile.

This delivery is a design/behavior handoff, not an implemented ScreenGui. Keep Claude's working UI framework and current Stage 3 queue work intact. Implement this in a separate UI stage after the shared queue checkpoint is stable. Read the current Studio code before adapting it; don't replace existing controllers blindly.

## Layout

One centered sleek charcoal window with a clear title and X close button. Use the current shared Theme/Components/MenuController, restrained blue selection, readable off-white text and fine gray borders. No achievement cards, Revives field, rank badge or extra progression feature.

- **Upper left:** actual avatar thumbnail, display name, @username, level and XP progress. Coins directly beneath XP as part of this profile group.
- **Lower left:** Wins, Losses, Eliminations, Deaths, K/D, **Backstabs**, Best Win Streak. Adjacent compact Time Played and Current Streak cards.
- **Right:** **CURRENT LOADOUT** — one pistol card and one knife card, each showing its current selected model, skin name and equipped status. These are NOT the rest of the owned inventory. Use real model previews/approved thumbnails instead of copying the illustration.
- **Own profile action:** Open Inventory closes Profile and opens Inventory through the same menu owner. It must not stack windows. If Inventory is unavailable, disable the action with an explicit explanation.
- **Footer:** Competitive statistics; practice does not count.
- **Bottom:** retain the shared hotbar; Stats is selected. Hide Play Game while this window is open. Avoid a second standalone wallet or XP strip; the compact profile may be hidden while the expanded window is open and restored on close.

The concept's avatar, finishes, XP, coin balance and numeric statistics are SAMPLE DATA. Do not hard-code them as real player values. Backstabs replaces Revives; there are no revive mechanics to implement.

## Authoritative data and meanings

Use the approved server-owned player-data layer when it exists. Missing/not-loaded data is unavailable/loading, not zero. Do not create a competing datastore for this GUI. Do not let a client submit statistic increments or equipped asset IDs.

| Field | Display / source contract |
| --- | --- |
| Avatar, display name, username | Roblox player identity/thumbnail, with safe placeholder on thumbnail failure |
| Level / XP | Read real progression state and threshold, clamp fill to [0,1]; show unavailable until implemented |
| Coins | Read own authoritative balance, never infer from the sample image |
| Wins / Losses | Completed competitive match result; no duplicate result awards; cancellation is neither a win nor a loss; drawn matches aren't losses |
| Eliminations / Deaths | Confirmed competitive combat outcomes, no practice dummies, test grants or client claims |
| K/D | Derived from recorded eliminations/deaths; show two decimals for deaths > 0, otherwise a clear em dash rather than NaN/Infinity |
| Backstabs | Proposed explicit definition: confirmed competitive **backstab eliminations**, counted once by the server, not every swing/preview |
| Current / Best streak | Consecutive match wins under the approved result rules; do not infer from the number of round wins |
| Time Played | Display recorded playtime; document whether lobby/practice counts before adding the backend field. Excluding practice from combat stats doesn't automatically define session playtime |
| Current loadout | Server-selected pistol/knife + compatible selected skin IDs, resolved via catalog names/approved previews |

Document any existing approved definition that differs, rather than silently changing statistics. This UI handoff does not authorize inventing rewards or retroactive stats for sessions without records.

## Current loadout, not full inventory

The player normally has no combat Tools in the lobby. Therefore read the authoritative SELECTED LOADOUT, not whichever Tool happens to be in Character/Backpack. If the game still has one fixed default loadout, resolve it from actual server/game configuration and show that honestly.

When equipping a skin requires next spawn, keep the backend distinction between selected configuration and active match appearance; disclose 'Applies next spawn' if needed. Don't mark a pending/rejected selection as equipped. Never add stat bars or imply skin advantages. Profile does not equip merely by displaying a card.

Click Open Inventory (or a supported loadout-card action) and preselect the relevant weapon. Weapon -> Skins -> owned compatible skins -> Preview -> Equip remains the agreed flow. Other owned/unowned weapons do not appear in the current loadout section.

## Own vs other profiles

This task implements the LOCAL player's profile. Viewing other players is not automatically included. If that feature is already explicitly implemented, reuse its permission-filtered public profile data: public statistics/current loadout only, no private wallet/owned-item list, and no Open My Inventory button masquerading as an action for that other player. A screenshot must not authorize exposing private inventory or adding social-profile remotes.

## Lifecycle and input

- Use the existing single menu owner; one profile GUI instance per player session.
- X/Back closes consistently; switching to Store/Inventory closes Profile.
- Hide/close during match, practice and spectating, and on death/reset. Restore lobby UI/input correctly without camera locks left behind.
- Main target is PC now; verify common full-screen/windowed resolutions. Build selectable controls and controller Confirm/Back navigation where practical. Mobile adaptability is planned, not fully implemented/tested by this handoff.
- Keep safe areas and readable text. Reflow into a vertical scroll layout at narrow sizes instead of relying on a fixed minimum scale that clips the close button. Dedicated physical console/mobile verification remains a later stage.
- Longer display names, localization-length labels, large stat values and a missing avatar must not overlap layout.

## Required tests and report

1. Profile badge and Stats open the same window; repeated clicks and menu switches never stack copies.
2. X, keyboard/gamepad Back and inventory transition behave consistently, with correct focus restoration.
3. Values are actual data or explicitly unavailable/loading; no false zero balances; K/D handles zero deaths.
4. Profile tracks accepted equipment changes and next-spawn state; rejected changes leave prior values intact.
5. Competitive backstab elimination counted once; ordinary knife damage, practice targets and client requests cannot increment it.
6. Death, respawn, queue match start and practice entry close/hide it and restore the lobby state afterward.
7. Desktop full-screen/windowed sizes, long names and thumbnail failure. Record physical controller/console/mobile checks as unrun unless actually tested.

No Studio implementation or these tests were run by ChatGPT for this profile delivery. Show screenshots after building before claiming it matches the visual reference. Do not publish.
