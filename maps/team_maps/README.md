# Six built team arenas — editable Roblox models

**All six models now exist as `.rbxmx` files.** They follow the redesigned v2 route footprints, not the superseded central-box concept art. These are first-pass native-part environment builds with built-in materials and architectural details, ready for Studio import/review. They are not six playtested/production-finished maps, and they do not implement team modes.

The current Studio game/source is maintained separately by Claude; this batch does not replace a working arena or edit combat, UI, matchmaking, rounds, respawn or player-data code.

## Files and roster

| First intended mode | Model | Footprint | Parts |
| --- | --- | --- | ---: |
| 2v2 | [FreightTerminal.rbxmx](models/FreightTerminal.rbxmx) | 112 × 88 studs | 167 |
| 2v2 | [Foundry.rbxmx](models/Foundry.rbxmx) | 104 × 92 studs | 326 |
| 3v3 | [CanalWorks.rbxmx](models/CanalWorks.rbxmx) | 138 × 114 studs | 259 |
| 3v3 | [MetroExchange.rbxmx](models/MetroExchange.rbxmx) | 120 × 96 studs | 216 |
| 4v4 | [Skyline.rbxmx](models/Skyline.rbxmx) | 144 × 96 studs | 307 |
| 4v4 | [Crosscut.rbxmx](models/Crosscut.rbxmx) | 128 × 112 studs | 33 |

[TeamMapTemplates.rbxmx](TeamMapTemplates.rbxmx) is an alternative SINGLE import containing all six models in a Folder. Use the bundle OR the loose files, not both.

`models/*.geometry.json` records actual exported part dimensions, poses, source blocks, floor rectangles, perimeter runs, marker names/facing and mode metadata. [The v2 plans](../concepts/v2/) remain the design source. Models have an invisible `MapOrigin` PrimaryPart at the plan center; floor surface is Y=0. Original plan X/Z coordinates are translated by minus half the footprint. Spawn cell indices become cell centers (+0.5 stud) at root height Y=3.

## What makes each build different

- **Freight Terminal:** covered loading-hall approach versus broken open yard. A solid dispatch office has inset windows/sills; cargo islands have corrugated sides. Brick perimeter, concrete coping, asphalt yard, flush dock markings and mounted warm fixtures.
- **Foundry:** two linked machine halls, upper/lower transfers and a dogleg connection. Metal machine housings have aligned vents/access panels. Brick/concrete walls and supported overhead beams define the halls. No molten metal or hazards.
- **Canal Works:** winding service passages, two pocket loops and a short cross-link. Concrete enclosure, sage utility palette, flush service grates and a supported high conduit run. No deep water, pits or slippery mechanics.
- **Metro Exchange:** L-shaped concourse with maintenance cuts. Tiled-joint floor treatment, wainscot, solid column landmarks, supported overhead frames and maintenance signage. All one floor; no accessible rails, stairs or moving trains.
- **Skyline:** staggered rooftop courts, diagonal approaches and two plant enclosures. Opaque HVAC housings, inaccessible exhaust details, roof expansion seams and tall enclosed boundary. No fall routes or traversable secondary roofs. City skyline scenery is not included.
- **Crosscut:** exactly the approved simple direction: basic blocks, offset wall runs and native **SurfaceType.Studs** on top surfaces. No individual stud meshes, research props, snow theme or detailed industrial art. Crosscut replaces Alpine.

This is restrained Roblox-native architecture, not photorealistic mesh scenery. Built-in Brick/Concrete/Metal/Asphalt materials and in-world text render in Studio; the plotted preview cannot reproduce them. No imported meshes/textures, untrusted Toolbox assets, randomized obstacles, weathering decals, sound or global Lighting changes are included. Final art polish/readability still needs an in-engine review.

## Structure and collision

```text
MapModel
├── Ground        -- exact nonoverlapping floor slabs
├── Boundary      -- enclosing walls outside the planned floor
├── Architecture  -- tall opaque source blockers
├── Cover         -- low cover, where present
├── Details       -- noncolliding/nonquery trims, signs and fixtures
├── Spawns
│   ├── Blue
│   │   └── BlueSpawn01 ... BlueSpawn02/03/04
│   └── Red
│       └── RedSpawn01 ... RedSpawn02/03/04
└── Metadata      -- MapOrigin + MapId/PrimaryMode/TeamSize/BuildVersion
```

All parts are anchored. No scripts, RemoteEvents, active SpawnLocations, NPCs or gameplay services are embedded. Spawn markers are invisible Parts, not auto-spawn pads. Each team has exactly the number of markers for the primary mode and they face toward the other spawn area. Random team assignment remains server-controlled; colored markings do not grant team choice.

Collision and query are enabled only on structural floor/walls/cover. Details have CanCollide/CanTouch/CanQuery=false so a vent or coping trim cannot snag players or block bullets. Tall blockers are the exact 12-stud plan boxes; low cover is 3.2 studs. Exterior and inner-void boundary walls are 14 studs high and placed entirely OUTSIDE the floor boundary so they do not narrow the approved passages. Those heights still need testing with actual jump/sprint/slide abilities.

## Safe Studio import — Claude or user

1. Preserve local changes before pulling GitHub. Save a local `.rbxl` backup of current work. Open a SEPARATE review place for this batch.
2. Import `TeamMapTemplates.rbxmx` using Insert from File / supported Explorer import, preferably into **ServerStorage**. If Studio inserts it into Workspace, move the Folder to ServerStorage before Play. All six models are centered at the same origin: leaving the bundle in Workspace overlaps them.
3. Alternatively import ONE loose model into Workspace. Do not import loose copies as well as the bundle into the same storage folder.
4. For the bundle, duplicate/clone exactly ONE selected model from ServerStorage/TeamMapTemplates into Workspace. Keep other templates stored. Do not move/delete any original working game map.
5. Remove or move the default Baseplate only in this review place if it overlaps model floors. Don't mistake it for generated floor overlap. Do not change the active game's Baseplate or spawn system from these instructions.
6. In the review place, position a temporary review SpawnLocation at floor level within a chosen team pocket, or have Claude move the test character root to one marker's CFrame. The marker is Y=3 ROOT height, not spawn-pad height. Do not rely on default spawning at world origin: origin can be an obstruction/void in some maps.
7. Check Model.PrimaryPart is MapOrigin. Move the WHOLE model with its pivot if required. Spawn marker CFrames move with it; never hard-code old JSON world coordinates after moving.
8. Walk all routes at actual avatar scale. Inspect seams, material appearance, signs, fixture support, shadows and tiny surface offsets. The complete import has not been verified in Studio here: capture any import error before editing XML or replacing a working asset.
9. Review screenshots at player eye height and overhead before integrating anything. See `CLAUDE_HANDOFF.md` for the required tests.

No user-facing localhost web preview is needed. `previews/Built_*.png` shows the actual exported XML geometry using a plotting tool, NOT concept art or Roblox engine screenshots. Native studs are engine surfaces; plotted dots are only a visual guide, not exported cylinder meshes.

## Tests completed here

`tests/validate_team_maps.py` reads the ACTUAL XML and independently compares it with the v2 floor/collision definitions:

- valid positive finite dimensions, anchored parts, unique references and script-free models;
- exact source-plan floor coverage with no overlapping foundation slabs;
- no added/removed route collision at grid resolution;
- closed perimeter along every floor/void edge, matching marker positions and inward-facing rotations;
- ground-space connectivity with conservative body-clearance erosion, all intended team spawn slots reachable;
- initial opposing spawn-slot eye-level rays occluded by tall structure or the assumed enclosing walls; low cover does not count as eye-level blockage;
- part budget under 600 per model, appropriate collision/query flags and native Crosscut stud surfaces;
- six-model bundle matches individual models and generation is byte-repeatable.

See `VALIDATION.txt` for the output. This does not simulate Roblox Humanoids, real engine raycasts, jump/slide exploits, network movement, gameplay, first-contact timing or competitive balance. **Studio import, visual review and multiplayer tests remain unrun here.**

Rebuild (Python standard library; reuses the existing XML writer only):

```sh
python3 maps/team_maps/tools/build_team_maps.py
```

Verify (requires numpy):

```sh
python3 maps/team_maps/tests/validate_team_maps.py
```

Optional plotted previews (numpy/matplotlib):

```sh
python3 maps/team_maps/tools/render_team_maps.py
```

Rebuilding overwrites only generated files under this batch. It does not modify original 1v1 models or Studio scenes. No new runtime dependencies are needed to use the `.rbxmx` models.
