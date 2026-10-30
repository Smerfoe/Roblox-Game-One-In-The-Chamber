# One in the Chamber — three editable arena builds

These are first-pass, native-part Roblox models built from the approved concept direction. They are not screenshots or replicas of the concept art. Built-in materials provide the base finish; custom rust, dirt, mesh props and texture work are not included. No Toolbox assets, external dependencies, embedded scripts, active SpawnLocations, or global Lighting changes are included.

## Files

- `models/TestingGrounds.rbxmx`: 76 × 68 studs, 76 parts. Roofless concrete training house, staggered six-stud doors, interior sightline baffle, four flank barriers.
- `models/ContainerYard.rbxmx`: 76 × 76 studs, 287 parts. Six ground containers and two sealed upper containers; two ground tunnels; seven-stud gaps between container columns and an eight-stud central crossing. Shipment-inspired density with an original layout.
- `models/PumpHouse.rbxmx`: 76 × 68 studs, 127 parts. Two steel tanks, tall central equipment housing, brick perimeter, overhead pipe details and flush drainage grates.
- `LayoutPreviews.png`: overhead views drawn from the actual exported geometry.
- `models/*.geometry.json`: exact dimensions and positions for inspection and adaptation.
- `tools/build_maps.py`: deterministic stdlib-only source builder; rerunning replaces generated files in this package, not existing Studio work.
- `tests/validate_maps.py`: meaningful XML, dimensions, route, spawn sightline and reproducibility checks.

Footprints differ slightly from the early art-board labels to allow character clearance and deliberate spawn exits. All geometry is measured; decorative placement is fixed, never randomized. Collision layouts are rotationally symmetric or intentionally mirrored. Materials and labels can differ visually without giving one team different collision.

## Safe import in Studio

1. Download and extract the ZIP on the computer running Studio.
2. Save a local `.rbxl` backup of the current place. Keep Claude's tested arena and systems intact.
3. Use a separate review place first: drag ONE `.rbxmx` into Studio. If dragging is unavailable, use Explorer's **Insert from File** action where supported.
4. Each file is one Model with `Ground`, `Architecture`, `Cover` (where used), `Details`, and `Spawns` folders. All geometry is anchored. Details intentionally have collision, touch and query disabled; they must not block bullets or movement.
5. All three are authored around the same origin with floor top Y=0. Do not place them all in Workspace together: they will overlap. Store inactive models in ServerStorage or inspect one at a time.
6. The two transparent Parts in `Spawns` are marker positions, NOT automatic spawn pads. Select them in Explorer to inspect them. Blue is negative Z; Red is positive Z. The colored floor patches identify their pockets. Spawn facing should point toward the model center.
7. Use Studio's pivot tools to move the whole Model if needed. The manifest coordinates describe the original authored position; after moving, read the actual marker CFrames. Do not assume the imported model pivot equals the floor origin.
8. In the live project, place approved templates under the existing map storage convention. Claude must read the current map/spawn interface before adapting it. Do not assume these marker names match MatchService, and do not replace match scripts to accommodate the maps.

## Handoff for Claude

Inspect each imported model before integrating. This package cannot access or verify the current Studio-only game code. Preserve MatchService, CombatService, loadout, camera, queue and HUD behavior. Keep the working Testing Grounds as a recoverable backup.

First verify one model loads correctly and inspect its Size, materials and collision. If Studio reports an XML import error, capture that error before changing the generator. The files have passed XML structural checks but have not been imported into the Roblox engine in this environment.

Use the current arena loader/spawn contract if one exists. If the game is hardwired to Testing Grounds, propose the smallest map-selection adapter before changing a tested service. This package does not add a rotation system or change matchmaking.

### Required Studio checks, one map at a time

- Inspect at avatar eye height, not just overhead. Check scale, seams, corners, floating details, material appearance and lighting. Retain neutral game lighting during the first pass; the included lights are restrained local fixtures.
- Walk every lane with the actual avatar, camera and movement settings. Test sprint, crouch, slide and jumping if implemented. Mathematical clearance is not a substitute for Humanoid testing.
- Try jumping from barriers, crates and spawn shields onto roofs/tanks/perimeter walls. Any route to an unintended top is a failure. Test with the game's actual JumpPower/JumpHeight and movement abilities; add precise invisible blockers only if necessary and retest bullet behavior.
- Fire the actual weapons around every doorway, container shell and tank. Decorative ribs have CanQuery=false; structural parts must stop server raycasts.
- Confirm spawns have free body/head room, face inward, and cannot see each other directly. Both exits from each pocket must work without snagging. Avoid moving spawn markers alone without rechecking the shield.
- Inspect tank collision carefully: these are Roblox cylinders, not handmade meshes. Verify their real collision and the gaps around their plinths in Studio.
- Two clients: compare opening timings, both flank approaches, tunnel camping, sound cues, visibility and exposed crossings. Check opponent readability on blue/red/green surfaces. No spawn should gain a free first shot.
- Run the existing first-to-three match regression: 3–0, 3–2, timeout, drawn round, disconnect, next-round reset, loadout and return to lobby. Do not claim the map is integrated until these pass.
- Save a review copy and record issues. Do not publish the game.

## Art direction and finishing

The goal is human-authored consistency: aligned structural pieces, repeated construction dimensions, logical supports and sparse purposeful props. Do not scatter crates, add arbitrary pipes, paint random damage, or cover mistakes with darkness/fog. Test encounter flow before increasing detail. The illustrated concept art contains more surface weathering than these models; an approved material/texture pass is still needed to approach that finish.

Testing Grounds should read as poured concrete training architecture. Container Yard should feel dense and tense through the container shells and ground tunnels, not unexplained piles of clutter. Pump House uses two tank landmarks and one opaque machinery enclosure; its high pipes are visual services, not traversal routes.

If visual changes need new meshes or textures, propose them and establish asset provenance before importing. Keep collision simple and gameplay routes unchanged unless playtesting identifies a specific problem.

## Reproduce and verify locally

From the repository root:

```sh
python3 maps/tools/build_maps.py
python3 maps/tests/validate_maps.py
```

The build and geometry tests use Python's standard library only. Optional preview regeneration requires matplotlib:

```sh
python3 maps/tools/preview_maps.py
```

Automated checks cover finite positive dimensions, boundary fit, anchored state, script absence, XML/manifest agreement, three-stud-wide ground navigation to both spawns and three route checkpoints, direct eye-level spawn occlusion, and byte-identical rebuilds. The path test is a simplified 2D approximation and does not prove three independent routes, jump safety, engine import, visual quality or competitive balance. All Studio checks above remain unrun here.
