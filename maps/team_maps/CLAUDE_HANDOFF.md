# Claude: review the six built team maps

Continue your current checkpoint first; this batch is isolated under `maps/team_maps/` and requires no change to existing UI/combat work. Preserve local changes before pulling. Read this folder's README, then inspect the new models in a separate review place.

## Important scope

All SIX models are built; their team modes are not implemented by this package. Do not assume the game supports 2v2/3v3/4v4 just because a map has markers. Don't replace the tested 1v1 arena, enable every map in a menu, change the one-active-arena rule or publish from this handoff.

Use `TeamMapTemplates.rbxmx` OR loose `models/*.rbxmx`. Store all templates under ServerStorage and instantiate one at a time. Their coordinates overlap at the origin. `MapOrigin` is the pivot. Read actual Spawns/Blue and Spawns/Red Parts after moving a model; do not use old global constants. Metadata/PrimaryMode and TeamSize describe the initial test target, not an authorization to create teams.

## Review every model, no silent skips

1. Confirm XML imports, all expected folders/materials/signs appear, all geometry stays anchored and no unrelated scripts load. Report errors verbatim. Match the right files; old concept art and older two-map packages are not this batch.
2. Compare the actual floor/wall structure with `maps/concepts/v2/*_Plan.png`. Keep the six different layouts intact. Don't "clean up" them into another central-room/perimeter pattern.
3. Check floor slab seams, boundary joins, corners, office window/vent alignment, beam/fixture support, lighting and collision at avatar eye height. Nonquery details must not hide a hole in structural cover. Tile joints and drain grates are flush details, not physical steps.
4. Crosscut must visibly use native studs and remain basic. Studio may render stud surfaces differently from an illustrative concept. Don't approximate studs with thousands of Parts.
5. Walk/sprint/crouch/slide through EVERY connection with the real movement controller. Try jumping from low cover to tall blocks, coping, beams or outer walls. Stop unintended roof/void access without silently changing firing lanes.
6. Spawn test: Blue/Red count and root clearance for the intended team size, correct facing after pivot, no initial spawn shot, usable exits, no players stacked into the same marker. The current physical team pockets are identified by paint, not queue pads.
7. Raycast with actual combat: floors/boundaries/tall cover stop shots; low cover peeks work as intended; noncolliding decorative vents/signs do not become hidden shields. Test corners and possible long-barrel origins without giving a weapon extra reach through a wall.
8. Compare opening travel times, first contested corners, crossfire and rotations from BOTH teams. These asymmetric proposals have not been proven fair. Record and propose specific changes before moving major walls.

## Team-mode and gameplay validation

When the existing team match implementation is ready, integrate ONE approved map via the current loader/spawn contract. Adapt marker discovery minimally; don't replace tested services to match arbitrary folder assumptions. Keep server-random balanced team assignment, stable teams between rounds, friendly-fire rejection, three-minute timer and first-to-three match rules. Inspect current game rules first; don't overwrite newer approved changes with old chat assumptions.

Test the intended player count: 4 clients for 2v2, 6 for 3v3, 8 for 4v4. A two-client session is useful inspection but not a passed team-mode test. Verify multiple spawn positions, single elimination ammo award, teammate/enemy damage rules, living-player spectator targets, target disconnect, drawn round, timeout, forfeit, next-round health/ammo/loadout reset and exactly one match result before lobby return.

One map can be inspected independently of team-mode readiness; don't claim full integration while team code is missing or tests are unrun. Keep all templates available for visual review without enabling unfinished modes in the player UI.

## Report and preserve

Record per map: import result, screenshots, geometry defects, movement/sightline issues, planned fixes, tested player count, pass/fail/unrun tests and exact next step. Save review copies separately. Retain originals/backups and don't publish. No game-code change or final production-readiness claim is included in ChatGPT's geometry checks.
