# Review: Claude shop/practice/UI checkpoint

Reviewed head: `df7af34f6402691640f6d1f215b7d7e1e93b654d` (`claude/shop-practice-maps`).
Compared against main: `78e0366c347ff21bf51f1d5cf141ac89aaab1885`.

Scope: two commits adding the Studio script snapshot, shop/practice/location policies, existing spectating/map integration handoff, and UI foundation/lobby/Store checkpoint. The shared pad+menu queue, random teams, new skin system, six team-map integration and living-opponent spectating are explicitly NOT completed in this checkpoint.

Recommendation: fix the two findings below, update the Studio snapshot/docs, and review through a PR. Do not merge or publish automatically. `src/` is documented as a Studio export; edits to it alone do not update the place.

## Findings

### P2 — Store/Profile can extend beyond narrow viewports

Files: `src/StarterPlayer/StarterPlayerScripts/UI/Components.luau:59-63`, `UI/Theme.luau:39-40`, `Controllers/ShopController.luau:196`.

The shared scaling formula clamps to a minimum of 0.6, but Store uses a fixed 900-pixel panel and Profile a fixed 760-pixel panel. On a 390-pixel-wide portrait viewport, even assuming UIScale is applied as intended, these remain 540 and 456 pixels wide. A centered Store extends 75 pixels beyond each screen edge before safe-area deductions; controls/content can be clipped or inaccessible. The checkpoint explicitly says small phone viewports were not tested.

Correction: constrain menus to actual safe available dimensions, introduce appropriate reflow/scrolling, and preserve readable text/touch controls. Verify the UIScale parent/container arrangement in Studio. Do not simply shrink everything until text becomes unreadable. Test narrow portrait, short landscape and desktop, including close/back and switching menus.

Validation here: arithmetic using the actual 1280x720 base, minimum 0.6 and panel widths. Roblox rendering/device behavior was not executed here.

### P2 — A stale spawn-facing task can rotate a replacement character's camera

File: `src/StarterPlayer/StarterPlayerScripts/Controllers/CameraController.luau:44-60`.

`faceSpawn` captures the old character/root/SpawnCFrame, yields while waiting for arrival and yields once more, then unconditionally writes to the current camera. It never verifies that the character is still `player.Character`, that the spawn request is still current, or that arrival actually succeeded rather than timing out. A reset/replacement or newer transfer during a pending task can cause the old spawn orientation to override the current camera. Multiple `SpawnCFrame` notifications can race as well.

Correction: use a generation/token per current character and spawn request; invalidate on replacement/removal or newer spawn-facing request. Recheck validity after every yield and immediately before writing the camera. Stop safely on timeout/missing camera/root instead of applying stale facing. Respect spectating camera ownership.

Validation here: executed the exact extracted `faceSpawn` function using official Luau and lightweight task/vector/camera mocks. The mock replaces `player.Character` during the final wait. The old task still overwrites the current camera with the old spawn's LookVector. This establishes the stale-task logic error, not an in-engine visual reproduction. Retest actual death/reset and practice entry/return with delayed replication in Studio.

## Checks completed

- Fetched the published head and main; no source changes made to Claude's branch.
- `git diff --check` passed.
- `git merge-tree --write-tree` completed with no conflicts against the main commit above. No branches were merged.
- All **31** `.luau` files compile with official Luau 0.699. This is syntax/bytecode compilation, not full Roblox type/API analysis or runtime validation.
- Read both handoff/checkpoint documents and reviewed the server match, queue, combat, practice/location/loadout flow and UI/menu/camera/spectator controllers.
- Claude's reported Studio passes are attributed to its documents; they were not independently rerun here.

## Documentation and follow-up

- Remove the now-resolved GitHub 403/bundle blocker from `docs/CHECKPOINT.md` and `docs/HANDOFF.md`. Keep historical context if useful, but identify it as resolved.
- Living-player 1v1 spectating is still pending. The current SpectateController intentionally follows teammates or falls back to overview, and requires InMatch=true for targets; RoundEnd clears that flag. When implementing the approved design, use same-match living characters and actual phase policy, not this old eligibility unchanged.
- The new six-map package uses ROOT-height spawn markers at Y=3. The current MatchService adds another 3 studs and always uses points[1]. Before team-map integration, explicitly reconcile marker-height conventions and assign a distinct marker to each teammate. Do not quietly claim current code supports the new team spawn contract.
- Keep the shared-queue task next: pad/menu deduplication, balanced random teams once per match, leave/status behavior, practice-entry race and full 1v1 regressions. Do not mark it completed by this PR.
- Source snapshots do not include the full Studio place/assets; this PR does not make the game independently runnable from a clean code checkout.

## Proposed pull request

Title: **Add Studio gameplay snapshot and lobby UI foundation**

Body:

> Adds the current Studio scripts and handoff documentation for isolated practice travel/combat, shop interaction, existing map integration and the lobby UI foundation. The new shared menu owner, profile/hotbar and preview Store reuse server attributes; unavailable progression/purchases remain clearly labeled.
>
> Includes Claude's recorded Studio test results and screenshots. Independent review confirmed clean merge compatibility and compilation of 31 Luau files; Studio tests were not rerun by the reviewer. Address the narrow-screen panel sizing and stale spawn-camera task findings in `reviews/claude-shop-practice-maps.md` before merge.
>
> Shared pad/menu queueing, random teams, living-player 1v1 spectating, skin persistence and new team-map/mode integration remain follow-up work. No publication.

## PR creation status

Not created by this session. Git fetch/push work, but the GitHub API request through `gh` returned `Forbidden`; `api.github.com` is absent from this environment's enforced effective network allowlist. This is an API access limitation, not evidence that Claude's branch push failed. No credentials were requested or changed.

Create/reuse the PR through Claude's GitHub connection or the GitHub comparison screen:
https://github.com/Smerfoe/Roblox-Game-One-In-The-Chamber/compare/main...claude/shop-practice-maps?expand=1

Check for an existing PR first. Keep it unmerged while the findings are addressed.
