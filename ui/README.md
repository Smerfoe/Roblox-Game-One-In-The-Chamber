# One in the Chamber — UI design handoff

The user approved the revised UI direction and requested delivery to Claude through GitHub. These files are concept art and implementation specifications, not executable ScreenGuis, sliced assets, or tested game UI. Implement with native Roblox UI and real in-game weapon previews; do not use an entire screenshot as a functional interface. Inspect existing Studio controllers first and preserve working behavior.

## Latest references and precedence

1. `concepts/LobbyHotbar.png`: lobby navigation layout and grouped profile.
2. `concepts/Store.png`: shop grid, category tabs, item cards.
3. `concepts/QueueAndWeaponSkins.png`: latest Play Game and inventory/skin workflow. Supersedes older team-selection and flat inventory designs.
4. `concepts/MatchAndPractice.png`: latest sleek round result, match result, active HUD and practice. Supersedes the older bulky results board.
5. `concepts/Spectating.png`: latest dedicated 1v1 spectator view.

Written requirements below override image-generation inaccuracies. Background scenery, weapon artwork, avatar appearances, prices, XP and balances are illustrative, not approved assets or actual player data. Do not replicate the incidental map/lobby changes in these images. Keep the approved single-floor lobby and existing match geometry.

## Shared design and implementation

Use slim charcoal translucent surfaces, thin muted gray/steel-blue borders, off-white readable text, consistent spacing, subtle angular accents in match UI and restrained team red/blue. Avoid glow-heavy borders. Keep text legible at small resolutions; don't imitate excessively spaced tiny image lettering.

Proposed implementation tokens (starting values, adjust after Studio review): background #171C22, panel #222930, text #F0F1ED, secondary #B8C0C8, border #55616C, blue #4D9DD5, red #D06B6B. Spacing 8/16/24 px, menu title 28 px, body 18 px, secondary 16 px at desktop baseline. Keep light-gray square lobby hotbar tiles, dark icons and a restrained selected accent. Create one consistent original icon set, including one/two PISTOLS for Modes, never rifles or crosshair.

Use safe-area-aware layouts so the profile and close buttons never overlap Roblox core UI. Scale panels with constraints, use layouts and scrolling containers, keep selected/focused/disabled states distinct, avoid text overflow. Concepts omit phone controls intentionally; do not place the reference game's touch overlays in the custom GUI. Preserve Roblox's normal device input and test touch/controller access where supported. Do not disable default mobile movement as a side effect.

Use one menu state owner: opening one menu closes another; close/back behavior is predictable. No repeated event connections or stacked ScreenGuis on respawn. Lobby menus must close and release input when entering match/countdown/spectating. Use existing controllers and server attributes instead of competing state loops. Menu previews cannot authorize any gameplay action.

## Lobby and profile

Bottom center: prominent **PLAY GAME** button above five tiles **STORE / INVENTORY / MODES / STATS / SETTINGS**. Modes uses a pistol or two pistols; Play Game and Modes open the SAME mode-selection screen, not separate queue systems. Selected tab should remain clear. Hide Play Game while a menu is open; hotbar may stay on ordinary lobby menus, but hide it on the focused queue screen and all match/practice screens.

Top-left compact profile: avatar, display name, level, XP bar, and coins directly below within that profile group. No separate coin wallet elsewhere, no top-center XP strip, no gems. Clicking profile expands statistics and equipped cosmetics. Stats tile opens this same profile statistics view rather than creating an inconsistent duplicate. Never show made-up balances/progress as live data: bind existing server-provided values, or label unavailable fields clearly and omit rewards until progression exists.

## Store

Accessible through Store tile and walk-in shop zone; same menu for both. Header tabs with text labels, clear close, generous consistent 3-column grid on desktop, responsive scrolling at smaller sizes. Categories Featured, Pistol Skins, Knife Skins, Player Cards only if supported; don't implement fake catalogs just to fill a screenshot.

Item selection opens detail/preview, with one price row when actual catalog pricing exists. Sample names/prices are NOT requirements to create skins or set economy values. Keep currency balance in profile only. No duplicate wallets, premium currency, urgency countdown or crates monetization by default. If purchasing is unimplemented, show preview catalog and disable purchase actions clearly. Future server purchases validate catalog item, price, funds, ownership and eligibility. See `lobby/CLAUDE_HANDOFF.md` for shop-entry lifecycle and dismiss-until-reentry behavior.

## Play Game and matchmaking — latest rule

Four large cards: 1v1, 2v2, 3v3, 4v4. Exactly one mode selected. Only enable modes actually implemented/tested (currently confirmed 1v1); other modes say Coming Soon, not level-locked. Back and Queue for Match actions; queued state shows status and Leave Queue. No fake wait time or online count.

**NO Blue Team/Red Team choice. Server randomly assigns balanced teams when loading the selected game.** For 1v1, choose randomly which matched player becomes Blue, with the other Red. Do not re-randomize teams each round. Client cannot provide its team. Existing color-specific pad queues must be reconciled deliberately: keep pad visuals but treat entry as mode queue membership rather than a color guarantee, deduplicate membership with menu queueing, and use the same authoritative matching owner. Do not run a new menu queue beside the existing pad queue. Preserve single-active-arena behavior and all existing forfeit/round rules. Document this intentional change from earlier team-pad assignment.

## Inventory -> weapon -> skins -> equip

Inventory lists base weapons/cosmetics, with category filters All/Pistols/Knives/Cosmetics, scrollable grid, search and sort only when backed by real item data. Select **Service 1911**, then **Skins** to open a dedicated owned-skins view for THAT weapon. Breadcrumb/back path: Inventory > Service 1911 > Skins. Select a skin to preview; **Equip Skin** confirms. Clicking a preview alone does not equip. Default remains available. Show an equipped badge only from authoritative equipped state.

Filter by server-owned inventory and weapon compatibility. No unowned store skins in owned list; no other weapon types. Server validates ownership, compatibility and allowed equip state. Retain previous skin until equip acknowledgement; show pending/error states and avoid rapid duplicate requests. Cosmetic selection must not change stats, hitboxes, reach or animations with timing advantages. Apply appearance consistently to viewmodel/world weapon via existing systems, ideally on the next loadout if live switching is unsafe. Clearly disclose when a change takes effect. Persist only through the project's existing data layer; don't invent a parallel datastore.

**Remove the weapon-stat bars added by the concept renderer.** No rifles, trading, deletion, wear/condition filters or capacity upsells. The images' skins are illustrative and do not imply those assets exist.

## Match and practice

Active match: slim top-center team score/timer, round and first-to-three label, small crosshair, health, ammo, active weapon and pistol/knife slot indication. Keep lobby wallet/profile/hotbar offscreen. Ammo/weapon visuals must follow accepted server state, not client-hit assumptions.

Round result: brief slim Won/Lost/Draw banner, authoritative score and next-round countdown. Match result: Victory/Defeat/Draw, team/final score, available server-recorded statistics, automatic lobby-return timer. Result color must reflect the LOCAL player's outcome, not always Blue=Victory. The sample images assume local player Blue; Red players must also see correct perspective. Include timeout, disconnect/forfeit and cancelled-match messages. Do not label a match cancelled as a defeat. Don't award fake XP/coins or add unsupported rematch actions.

Use existing MatchPhase, PhaseEndsAt, RoundResult, MatchResult and server timing (e.g. synchronized server clock); don't change tested 3-second round-end and 4-second result timings merely for animations. Last-round transitions must not promise a next round after match victory. Clear banners on next phase, respawn, return or disconnect. Countdown can only show combat enabled when the server does.

Practice: share crosshair/ammo/loadout styling; slim Practice indicator, Reset Training, Return to Lobby. No competitive score/rewards. Buttons request validated practice actions through existing server policies; no client-authoritative ammo grant. See lobby handoff for practice/queue/race isolation.

## Spectating — latest user correction

Eliminated players FOLLOW A LIVING PLAYER, not a fixed arena overview as the normal experience. The dedicated Spectating image replaces the earlier static-overview proposal.

For 1v1, follow the surviving opponent using a third-person follow camera. Since an elimination normally ends a 1v1 round immediately, this is primarily the brief round-end interval, not prolonged ongoing combat. Show the actual phase: live timer only during combat; next-round countdown only in RoundEnd when another round is scheduled; final-round match results take precedence. Do not keep a fictional combat timer running after the round ended.

Show Spectating, target display name, team, score and appropriate phase status. Hide the eliminated player's crosshair, health, ammo and viewmodel, plus lobby menus. Follow a valid living character in the SAME match/round only. Don't expose controls or replicate equipment for the dead player to attack.

For future team modes, prefer living teammates and allow previous/next controls only if multiple eligible targets exist. Do not spectate opponents while teammates remain alive. If only opponents remain and the round has ended, allow a surviving-player follow for the result interval; don't change round-win rules to prolong spectating. The explicit surviving-opponent permission in 1v1 must not become unrestricted opponent spectating during ongoing team combat.

Revalidate when the target dies, disconnects or replaces its character. Switch to another eligible living target if one exists; otherwise use an arena overview fallback. If the camera anchor is also missing, use a safe fixed fallback rather than throwing or leaving a dangling CameraSubject. Clear target references/connections on match change and restore the correct character camera on respawn, next round and lobby return. No leave button that silently forfeits; an intentional leave-match action, if added, needs a clear forfeit confirmation.

## Remaining small screens/states

- Start countdown; waiting/loading with timeout/error handling.
- Queue accepted/full/busy/left, duplicate join prevention, server rejection.
- Drawn round/match, cancelled match, disconnect/forfeit.
- Empty inventory, no owned skins, search no results, equip pending/failure.
- Profile expanded; settings with sensitivity/audio/reduced camera motion only where behavior exists. No false persistence claims.
- No progression rewards, purchase confirmation, ranked UI or additional modes until those features are explicitly implemented.

## Validation and handoff

Implement reusable native modules/components in the existing UI architecture. This package does not supply executable UI or final image assets. Native text, icons and ViewportFrames should replace illustrative art. No third-party UI framework is required.

Test menu switching/close/back, shop enter/exit/dismiss, queue via pad AND menu, balanced random server teams, no reassignment between rounds, inventory filtering and equip ownership rejection, camera/input restoration, phase timing, both local team perspectives, death/reset/disconnect, two-client full matches and practice isolation. Test layouts at desktop and smaller viewport sizes with supported inputs. Preserve all best-of-five regressions; never publish. Save screenshots and a status report distinguishing completed, failed and unrun checks.
