# Environment revamp — review builds

Nine editable Roblox `.rbxmx` maps, with reproducible builders and geometry previews. **These are external builds, not Studio-tested or approved production maps.** No game scripts, queues, inventories, remotes or live places are changed.

The models contain the actual geometry shown in the previews. The Blender renderer uses flat material colors, approximate sign typography and studio-style viewport lighting. Roblox brick/asphalt/wood textures, native studs, local lights, SurfaceGui formatting and live-place Lighting must be reviewed in Studio. These are not AI-generated concept images or claimed Studio screenshots.

## Contents and intent

| Model | Environment work | Collision baseline |
| --- | --- | --- |
| Foundry | Furnace doors, controls and seams; extraction system; open industrial canopy and framing; wall services; cabinet skins over existing low cover; exterior workshops, tanks and staged supplies | Claude's `ff4a0ff` export, including DetailPass_v1; every original instance property preserved |
| ContainerYard | Entirely new Shipment-reference-inspired yard: 10×28×12 container shells, corrugation, locking bars, corner castings, open interiors, stacked containers; solid cargo groups and a parked forklift; container-clad perimeter, drains, port buildings, cranes, floodlight towers and exterior forklifts | **New 136×136 layout**; requires complete gameplay review |
| FreightTerminal | Cargo construction, dispatch-office roof unit, warehouse canopy and trusses, wall protection, crate skins over existing cover; surrounding loading buildings, stored containers and forklift equipment | Existing team-map source preserved |
| CanalWorks | Concrete/tide finishes, wall utility cabinets and water mains; maintenance bridges, canals, external pump plant and service building | Existing team-map source preserved |
| MetroExchange | Station wall bands, tiles and information boards, suspended wayfinding, clerestory/roof structure, ceiling fixtures; exterior rails, trains and station buildings | Existing team-map source preserved |
| Skyline | Mechanical-plant facades and fan guards, ductwork, antennae, flashing and utility skins; supporting tower facade and surrounding buildings | Existing team-map source preserved |
| Crosscut | Restrained wall caps and a native-studded surrounding base | Existing simple studded layout preserved; deliberately not industrialized |
| TestingGrounds | Training signage, joints/tie details; compound buildings, secured exterior stores and lighting masts | **Repository's original 1v1 source**, not a new export of Claude's corrected live version |
| PumpHouse | Tank seams/vents, high pipelines and flanges, controls; supporting waterworks buildings and exterior reservoirs | **Repository's original 1v1 source**, not a new export of Claude's corrected live version |

All eight additive builds preserve their source instances including spawns, collision and geometry. Preserving a source is not proof that an older source matches Studio. In particular, **do not replace the current live Testing Grounds/Pump House with these complete models**: transfer their `EnvironmentRevamp` folder onto the corrected Studio baseline after comparison.

Container Yard is a substantially larger original layout guided by the user's MW19 reference images. It is not an exact replica or a promise of identical pacing. Review its footprint and combat distances before integration. All supplied geometry and text are original; no imported external assets are required.

## Import for review

1. Save the review place and keep the original models backed up.
2. Insert **one** model from `models/` into an isolated review place. Every model uses origin (0,0,0); importing them all at once overlaps them.
3. For Foundry, compare against `sources/Foundry_Current.rbxmx` (the original export is unchanged). For the other team maps compare against `maps/team_maps/models/`.
4. Walk both spawn bays and every route at player height with the game's real FOV and movement settings. Review wall attachments, corners, doors, apparent cover and silhouette visibility.
5. Check jumping/climbing and raycasts against roof equipment, boundary dressing and cover skins. New non-solid detail is flush to existing surfaces, above head height or outside the playable complex; inspect for any exceptions or visually misleading cover.
6. Test frame time, memory and rendering in the actual game. Container Yard currently has **6,052 Parts** including its port backdrop; it needs profiling and may need decorative mesh consolidation or backdrop simplification before production. Other maps are roughly 40–1,400 Parts. No FPS claim is made.
7. Review under the live game's Lighting. Tune local lights/exposure only after inspecting player visibility. The builder does not change place-wide Lighting.
8. Save the reviewed place to disk, send actual Studio screenshots and record any issues. Do not publish or switch live map templates automatically.

## Container Yard integration notes

- Root `Spawns/Blue/BlueSpawn01`, `Spawns/Red/RedSpawn01` are invisible anchored Parts at **HRP Y=3**, facing inward. `Metadata/MapOrigin` is the PrimaryPart; use `PivotTo` and read spawn CFrames after moving the model.
- These markers are **not** floor-height pads. If the adapter adds +3 to all markers, it must account for this convention. No adapter is changed here.
- `EnvironmentRevamp/GameplayShell`, `ContainerConstruction`, `NewGameplayCargo`, and `NewGameplayForklift` contain deliberate visible collision. Their `CanQuery` matches `CanCollide`.
- New solid cargo and a parked forklift sit on the outer routes and is an intentional gameplay addition. Check it for climbing, snagging, head glitches and spawn-exit pressure. Do not assume it is approved cover.
- Backdrop, cranes, decorative ribs/locks and floor markings are non-colliding and non-query. Aiming along decorative trim should not cause an invisible bullet stop.
- Only 1v1 marker slots are supplied. Do not enable team modes on it without an explicit spawn/team review.

## Verification and reproduction

```bash
python maps/revamp/tools/build_environments.py
python maps/revamp/tests/validate_environments.py
blender -b -t 4 --python maps/revamp/tools/render_geometry.py -- Foundry
python maps/revamp/tools/prepare_previews.py  # Pillow; after rendering all nine maps for the board
```

Build and structural validation need only Python's standard library. Blender and Pillow are optional, used only for external geometry previews and their labelled JPEG/board derivatives. The generator is deterministic and does not edit the older source files.

`previews/AllMaps_GeometryReview.jpg` is the overview board. Individual JPEGs are labelled external viewport previews. Spawn views deliberately retain the supplied source facing, including cramped views documented by Claude; do not treat those views as approved camera placement.

`VALIDATION.txt` records property preservation, referent integrity, finite positive dimensions, orthonormal transforms, anchored parts, no scripts/SpawnLocations, and collision/query consistency. Container Yard additionally has conservative three-stud-wide ground connectivity between spawn bays and 18 sampled blocked spawn-to-spawn rays at standing/jump-view heights. Those checks are **not** full-map climbing, team balance, performance or Studio integration tests.

`BUILD_REPORT.json` and individual manifests contain exact part counts and source SHA-256 hashes. `sources/FOUNDRY_NOTES.md` preserves Claude's original handoff and reported earlier tests; those reported Studio tests apply to his source, not to these new environment exports.

## Still required before approval

- Studio visual review of all nine models, including actual built-in materials and player visibility.
- Player movement/corner checks and jump/roof-access review after dressing.
- Container Yard combat-distance, routes, new-cover and match tests.
- Reconcile the two original 1v1 baselines with Claude's corrected versions.
- Profile native-part counts; optimize where measurements justify it.
- User review of the actual Studio result. This first complete environment pass is not labelled finished production art.
