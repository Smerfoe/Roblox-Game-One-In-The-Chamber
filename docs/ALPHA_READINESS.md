# PC 1v1 alpha readiness

Based on Claude's pushed checkpoint `3df8955` (player data and skins). These are reported implementation/test results, not an independent full code or Studio audit.

## Proposed first release scope

A limited PC 1v1 alpha: one approved map, the 1911 and Karambit, best-of-five matches, lobby/practice, queue UI, inventory and cosmetic skin equipping. Keep team modes unavailable. Extra weapons/maps, crates, paid purchases, ranked play and dedicated console/mobile releases are not prerequisites for this small scope.

## Present evidence

- Best-of-five 1v1 and shared pad/menu queue have reported two-client Studio passes.
- Save/data ownership and equip validation are implemented. Claude reports 13 automated checks and Studio error/lock/schema tests passing using a test-store adapter.
- Practice Tool/viewmodel skins and unchanged ammo were checked in Studio.
- **Real DataStore persistence has not been tested.** In-memory tests do not prove cross-server or server-restart persistence.
- Inventory screen click-through/screenshots and a two-client match with skins remain untested.
- New environment models are external review builds, not Studio-approved art or performance results.
- Additional weapon rigs remain prototypes and must not be substituted into live combat simply because their model files exist.

## Next work for Claude

1. Finish Inventory UI click-through, screenshots, equip/failure feedback and reopen-state checks.
2. Run a two-client match with different skins. Confirm server Tool, local viewmodel and opponent-visible weapon agree, all rounds reload correctly, and combat values remain unchanged.
3. Test actual Roblox DataStore persistence with the isolated Studio store once API access is available. Verify leave/rejoin, saved equips, session ownership and recovery/error paths. Never use production keys for these tests. Keep this explicitly untested if access is unavailable.
4. Run a continuous complete session: join lobby → practice → return → inventory/equip → pad/menu queue → best-of-five → living-player spectating → results → lobby → leave/rejoin. Include queue disconnect, match forfeit, drawn round, timeout and save failure. Fix failures and record evidence.
5. Check that failed/locked loads and delayed saves are understandable to the player; never imply cosmetic changes persisted when they did not. Confirm developer test grants are disabled for the intended release configuration.

Store/crates work should wait until this evidence is complete; it adds economy complexity without resolving the current release gaps.

## Remaining release work areas

- **Reliability:** real saving plus the complete-session tests above.
- **Presentation/performance:** approve one actual Studio map and the existing weapons/HUD; check frame times, visibility, audio/readability and spawn/movement behavior on representative PCs.
- **Release preparation:** agree alpha scope, review available/unavailable UI, prepare game title/description/icon and control/help text, then arrange a small private-server playtest before wider release.

Publishing or changing place access remains a separate explicit user decision. Nothing in this document authorizes publishing, purchases or a production data migration. No dependable calendar estimate or completion percentage is available until the unresolved tests and resulting fixes are known.
