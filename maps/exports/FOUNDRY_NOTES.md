# Foundry: current export (handoff for the full environment build)

Exported 2026-10-30 from the Studio review place. **Not published.** This is the working Foundry map exactly as it stands in Studio: the original team-build model plus Claude's first detail pass (`DetailPass_v1`). Claude has paused further Foundry decoration while the full environment build happens elsewhere.

## Files

| File | What it is |
| --- | --- |
| `maps/exports/Foundry_Current.rbxmx` | The complete map as XML. Insert from File in Studio. |
| `maps/exports/Foundry_Current.rbxm` | The same map in binary, straight from `SerializationService:SerializeInstancesAsync` on a clone. This is the byte-exact source. |
| `maps/exports/screenshots/foundry/*.jpg` | 11 Studio screenshots: overhead, spawn views and eye-height route views. |
| `maps/exports/drafts/FoundryDetail_v2_UNRUN_DRAFT.luau` | **Never run, untested.** Claude's planned second detail pass (signage, crane, pipework, backdrop buildings, proposed spawn-bay cover). Reference only; nothing from it is in the map. |
| `maps/team_maps/models/Foundry.rbxmx` | The untouched original (team-build-v1, 326 parts). A backup also lives in Studio at `ServerStorage.TeamMapOriginals.Foundry`. |

**How the .rbxmx was made.** The working map was not modified: a `:Clone()` was serialized to binary .rbxm. That file was transferred out of Studio and checksum-verified. It was then converted to XML with the rbx-dom libraries (`rbx_binary` → `rbx_xml`), so every property Studio saved is present.

| Check | Result |
| --- | --- |
| rbxm sha256 | `b627ee68b21c1b8e873869e87b781d39d53608457e29737f5256200f08e67dd1` |
| rbxmx sha256 | `76172661d0dd1d9df1ad001307985896781c75cb99a1f60de87e8a99fb0c673b` |
| Instances | 425 (1 Model, 10 Folder, 390 Part, 12 PointLight, 4 SurfaceGui, 4 TextLabel, 3 StringValue, 1 IntValue), matching the Studio count |

## Hierarchy

```text
Foundry (Model, PrimaryPart = Metadata.MapOrigin, pivot = identity at 0,0,0)
├── Ground        13 Part   FoundationSlab, Concrete, 2 thick, top surface at Y = 0. Collide + query.
├── Boundary      28 Part   Boundary_N/E/S/W perimeter walls, 14 tall, 1 thick, outside the floor. Collide + query.
├── Architecture   6 Part   Machine_00/01 (furnaces), Wall_02..05 (tall blockers). Collide + query.
├── Cover          2 Part   Wall_06/07, low cover 6 x 3.2 x 4, Concrete. Collide + query.
├── Details      357 inst   Decoration only. All 336 Parts: CanCollide = CanQuery = CanTouch = false.
│   ├── (original details) BoundaryCoping, BoundaryPier, BulkheadMount + WarmDiffuser (8 PointLights),
│   │   MachineCap, VentPanel/VentSlat, MachineAccessPanel/Handle, WallCap, ConcreteJoint,
│   │   CoverSafetyInset, SupportedRoofBeam x4 (Y 14.4), Blue/RedSpawnTile,
│   │   Sign_BLUE_/_2v2, Sign_RED_/_2v2 (SurfaceGui + TextLabel)
│   └── DetailPass_v1 (Folder, 64 Parts + 4 PointLights): Claude's only change, see below
├── Spawns
│   ├── Blue  BlueSpawn01, BlueSpawn02
│   └── Red   RedSpawn01, RedSpawn02
└── Metadata  MapOrigin (Part), MapId = "Foundry", PrimaryMode = "2v2", TeamSize = 2, BuildVersion = "team-build-v1"
```

No scripts, SpawnLocations, meshes, unions, decals, textures or SurfaceAppearances are in the model.

## Origin, dimensions and orientation

- Pivot and `MapOrigin` are at (0, 0, 0) with no rotation; the floor top is at Y = 0. Move the whole model with `PivotTo`, and read spawn CFrames after moving. Never hard-code world coordinates.
- Bounding box: 106.3 x 17.4 x 94.3 studs (X x Y x Z). The playable footprint from the plan is 104 x 92.
- Heights:
  - Boundary walls: 14, plus coping.
  - Tall blockers and furnaces: 12.
  - Low cover: 3.2.
  - Roof beams: at Y 14.4. The roof is open.
- In the top-down screenshot, +X is to the right and +Z is down. Blue is top-left (-X, -Z) and Red is bottom-right (+X, +Z).
- Key structures (centre position and size, in studs):

  | Part | Centre | Size |
  | --- | --- | --- |
  | Machine_00 (Furnace 1) | (-23.5, 6, -4) | 7 x 12 x 24 |
  | Machine_01 (Furnace 2) | (23.5, 6, 4) | 7 x 12 x 24 |
  | Wall_02 | (-5, 6, -3.5) | 4 x 12 x 5 |
  | Wall_03 | (5, 6, 3.5) | 4 x 12 x 5 |
  | Wall_04 (Blue bay screen) | (-37.5, 6, -29) | 7 x 12 x 2 |
  | Wall_05 (Red bay screen) | (37.5, 6, 29) | 7 x 12 x 2 |
  | Wall_06 (low cover) | (-37, 1.6, 14) | 6 x 3.2 x 4 |
  | Wall_07 (low cover) | (37, 1.6, -14) | 6 x 3.2 x 4 |

- The two closed brick boxes in the centre (x -4..4, z -18..-6 and z 6..18) are void holes enclosed by Boundary walls, not Architecture parts.
- The layout is point-symmetric: (x, z) maps to (-x, -z) between the Blue and Red halves.

## Spawn conventions

- Markers are invisible 1x1x1 Parts:
  - Transparency 1, CanCollide/CanQuery/CanTouch false, Anchored.
  - Each marker's Y = 3 is the HumanoidRootPart height, not pad height.
- Facing is the marker's LookVector:

  | Marker | Position | Facing |
  | --- | --- | --- |
  | BlueSpawn01 | (-44.5, 3, -38.5) | (0.76, 0, 0.65), north-east toward Red |
  | BlueSpawn02 | (-38.5, 3, -32.5) | (0.76, 0, 0.65), north-east toward Red |
  | RedSpawn01 | (39.5, 3, 33.5) | (-0.76, 0, -0.65) |
  | RedSpawn02 | (45.5, 3, 39.5) | (-0.76, 0, -0.65) |

- Spawn bays:
  - Blue: x -52..-30, z -46..-24.
  - Red: x 30..52, z 24..46.
  - Wall_04 and Wall_05 screen each bay from the map.
  - The coloured floor tiles and the "BLUE / 2v2" and "RED / 2v2" signs are decoration only.
- The game reads `Spawns/Blue` and `Spawns/Red` children. Teams are assigned at random by the server, never by marker colour.
- Spawn protection: in Claude's review, none of the 48 Blue-to-Red eye-level and jump-peak ray pairs had a clear line (0/48). Keep any new geometry from opening those lines.

## Collision and decoration rules

1. Only Ground, Boundary, Architecture and Cover collide and stop bullets (`CanCollide` and `CanQuery` true). The combat raycasts use `CanQuery`.
2. Everything under `Details` must stay `CanCollide = false`, `CanQuery = false`, `CanTouch = false` and Anchored. Otherwise a sign or vent becomes an invisible shield or a snag.
3. Decoration inside the playable space must be flush (no more than 0.3 studs proud of the surface) or above head height (more than 8 studs). That way a non-solid prop never looks like cover that players can walk or shoot through.
4. Any new solid prop is a gameplay change. Put it in its own folder and flag it for approval. It must not create a climb route: from the floor a player can mantle about 8.6–9 studs, and from the 3.2-stud low cover about 11.7. The 12-stud blockers and 14-stud walls rely on that limit.
5. Keep route widths, spawn screens and firing lanes as they are. Busy detail belongs near machinery and service walls; keep movement spaces readable.

## Changes since the original model

Compared property by property against `maps/team_maps/models/Foundry.rbxmx`, after normalising -0 to 0 and Color3 to Color3uint8:

- All 356 original instances are unchanged: geometry, materials, colours, collision, spawns and metadata.
  - The only difference is that the two sign SurfaceGuis now save an explicit `Brightness = 1`, which is the default.
- **Added:** `Details/DetailPass_v1`, with 64 decoration Parts and 4 PointLights, all non-colliding, non-query and non-touch:

  | Item | Count | Detail |
  | --- | --- | --- |
  | MachineBand | 4 | DiamondPlate bands at Y 2.2 and 10.2 around each furnace. |
  | MachineBaseStripe | 2 | Yellow base stripe on each furnace. |
  | SightGlass + SightGlassFrame | 4 + 4 | Neon orange glass below the vents at Y 4. The 4 PointLights (orange, range 8) sit in the glass. |
  | ExhaustStack + ExhaustCollar | 2 + 2 | On the furnace tops, above head height. |
  | FloorSafetyLine | 8 | Flush yellow outline 1.2 studs out from each furnace. |
  | CraneTrolley, CraneCable, CraneHook | 2 each | Hung from the roof beams above the furnaces, all above head height. |
  | WallPlinth | 32 | Concrete base trim, 0.9 tall and 0.15 proud, on the Boundary and Architecture walls. |

- **Tested after v1:**
  - Spawn sight lines stayed at 0/48 open.
  - All decoration has collision, query and touch off.
  - Jumping from low cover still can't reach a standing spot on the furnaces, blockers, boundary or beams.

## Place-wide Lighting (review place, Studio defaults; nothing custom)

The map adds no Lighting changes; its own lights are the 12 PointLights in `Details`. To match the screenshots:

- **Lighting:**
  - Ambient = OutdoorAmbient = (70, 70, 70).
  - Brightness 3, ClockTime 14.5, GeographicLatitude 0.
  - EnvironmentDiffuseScale = EnvironmentSpecularScale = 1.
  - GlobalShadows on, ShadowSoftness 0.2, ExposureCompensation 0.
  - FogEnd 100000; ColorShift_Top and ColorShift_Bottom black.
  - Technology is the Studio default for a new place; it couldn't be read from a plugin.
- **Atmosphere:** Density 0.3, Offset 0.25, Color (199, 199, 199), Decay (106, 112, 125), Glare 0, Haze 0.
- **Effects:** Bloom (Intensity 1, Size 24, Threshold 2), SunRays (Intensity 0.01), DepthOfField at defaults.
- **Sky** (Roblox default sky asset IDs):

  | Property | Asset |
  | --- | --- |
  | SkyboxBk, SkyboxFt, SkyboxLf, SkyboxRt | rbxassetid://6444884337 |
  | SkyboxDn | rbxassetid://6444884785 |
  | SkyboxUp | rbxassetid://6412503613 |
  | SunTextureId | rbxassetid://6196665106 |
  | MoonTextureId | rbxassetid://6444320592 |

  SunAngularSize 11, CelestialBodiesShown true.
- **External assets in the map:** none. All materials are built-in (Concrete, Brick, Metal, DiamondPlate, SmoothPlastic, Neon), and the fonts are standard Roblox fonts in the TextLabels.

The live game place may use different Lighting. Check it there before tuning map lights.

## Screenshots (`maps/exports/screenshots/foundry/`)

Edit-mode camera, 70° FOV; eye height is Y 4.5 (root + 1.5).

| File | View |
| --- | --- |
| `01_overhead_topdown.jpg` | Straight down. +X is right, +Z is down. Blue is top-left, Red bottom-right. |
| `02_blue_spawn01_view.jpg` | From BlueSpawn01 along its facing. |
| `03_red_spawn01_view.jpg` | From RedSpawn01. It faces the Wall_05 bay screen at close range. |
| `04_red_spawn02_view.jpg` | From RedSpawn02. |
| `05_west_aisle_looking_north.jpg` | West aisle, x -36, Furnace 1 on the left. |
| `06_west_furnace_bay.jpg` | Approach to Furnace 1 from the south strip. |
| `07_central_crossing_looking_east.jpg` | Through the Wall_02/Wall_03 crossing between the core boxes. |
| `08_east_aisle_looking_south.jpg` | East aisle, x 36. |
| `09_east_furnace_bay.jpg` | Approach to Furnace 2 from the north strip. |
| `10_south_strip_looking_east.jpg` | South strip toward the east side. |
| `11_north_strip_looking_west.jpg` | North strip toward the west side. |

## Known issues / open items

- The detail level is still sparse away from the furnaces. Long brick runs, empty bays, an empty backdrop (the map floats over a void and the baseplate grid), and generic spawn bays are the gaps the full environment build should address.
- RedSpawn01 faces the Wall_05 screen about 4 studs away (see screenshot 03). This is part of the approved layout. Camera facing is handled by the game's spawn camera, but the view is cramped.
- `DetailPass_v1` WallPlinths sit 0.15 proud on the wall faces. That is within the flush limit, but they are visible at floor level, so keep them or replace them consistently.
- Not yet tested on this map: real team modes (2v2 needs 4 clients), mobile/gamepad, and play with the live game's Lighting. Team modes are not implemented yet; the map is reviewed in a separate Studio place.
- `maps/team_maps/tests/validate_team_maps.py` checks the generator's referent IDs, so it can't validate a Studio export. The property-by-property comparison above stands in for it: the structural parts are identical to the version that passed.
