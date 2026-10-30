# Team arenas — layout redesign v2

LATEST USER DIRECTION: redo ALL SIX layouts so they play differently. Replace Alpine entirely with a basic studded map. The old theme-swapped boards are superseded, including the old studded central-box Alpine proposal.

These are measured 2D layout concepts, not imported/constructed Roblox maps. This pass deliberately removes scenery so routes and solid shapes can be assessed. No existing map model, Studio service, test or combat system was changed.

## View the new plans

| First test mode | Arena | Plan | Distinct layout |
| --- | --- | --- | --- |
| 2v2 | Freight Terminal | [Plan](FreightTerminal_Plan.png) | Warehouse/yard split with three dock-door connections and an offset office/cargo field |
| 2v2 | Foundry | [Plan](Foundry_Plan.png) | Two machine halls with north/south transfers and a central dogleg connector |
| 3v3 | Canal Works | [Plan](CanalWorks_Plan.png) | Winding S-shaped service route with two side loops and a short cross-link |
| 3v3 | Metro Exchange | [Plan](MetroExchange_Plan.png) | Broad L-shaped concourse with two internal maintenance cuts |
| 4v4 | Skyline | [Plan](Skyline_Plan.png) | Staggered wings, two offset plant buildings and linked upper/lower courts |
| 4v4 | Crosscut | [Plan](Crosscut_Plan.png) | Plain studded block arena with broken wall runs, crossing gaps and small courts |

Paired boards: [2v2](Layouts_2v2.png), [3v3](Layouts_3v3.png), [4v4](Layouts_4v4.png).

Crosscut replaces Alpine Station. No snow/research theme, realistic textures, trees or detailed props. Use simple native blocks, standard materials and Roblox studded surfaces when the approved blockout is built. Do not create a separate Part for every stud.

## How to read

- Pale = traversable floor; dark interior shapes = opaque tall obstruction; dark outside = enclosed, inaccessible void.
- All exterior/void edges are assumed enclosed by opaque full-height boundary walls. They are NOT open pits or walkable gaps. The boundary thickness and actual collision still need a 3D wall plan.
- Hatched gold = 3.2-stud low cover. Other solid blockers default to 12 studs; these are starting design values, not approved jump-safe heights.
- Blue/red squares are spawn ZONES, not team selection. Black dots mark distinct proposed character spawn positions for the specified team size. The server still randomly assigns teams.
- Dashed lines show TWO EXAMPLE ground paths. They are not the only routes, painted floor arrows, one-way travel or a requirement to build two/three identical lanes. Line colors have no team ownership meaning.
- Coordinates are X/Z in studs. North/up is positive diagram Z. Future Studio conversion must preserve the stated convention or document a conversion.

## Different decisions on each map

### Freight Terminal

Players choose the narrow, predictable dock doors into a covered hall or the exposed broken yard with office/cargo corners. The truck-end flank is longer; crossing behind the office can change which side of cargo an opponent must watch. This is a wide indoor/outdoor split, not a central box with a perimeter loop.

### Foundry

Fight inside two separate machine halls. Three transfers create distinct engagements: broad north rotation, lower transfer close to the opening approach, and tight dogleg exchange between halls. A pair can hold one hall, split both, or abandon a room and reconnect. Long machinery islands prevent full-hall shots.

### Canal Works

The map bends repeatedly instead of presenting parallel lanes. The shortest chain includes blind corners; pump/valve yards open into small pockets. Side loops let a team get ahead, while the middle cross-link permits a reversal without crossing the whole map. Watch rotation time: this design must not become a long chase.

### Metro Exchange

The public concourse turns an L around an inaccessible inner block. Maintenance routes cut inside the elbow and trade a shorter journey for narrow corners/door exposure. The outer elbow offers more room to trade shots; service cuts favor close approaches. Don't turn the void into a central open arena.

### Skyline

Diagonal spawn approaches feed staggered roof wings and two connected courts. Two offset plant enclosures break crossfire rather than serving as one central landmark. A team can trade through pockets or rotate along the other court. All routes stay at ONE roof elevation; enclosed parapets prevent fall/ledge play.

### Crosscut

Basic studded geometry only. Several offset wall runs create different gaps: an inside dogleg, broad west court, east court turn and a longer upper rotation. There is no central room. Walls and blocks should teach the layout quickly without detailed art. Test open sightlines carefully so basic geometry still supports getting into knife range after a miss.

## Exact proposal data and repeatability

`layouts.json` records each footprint, floor rectangles, axis-aligned corridor centerlines/widths, solid block rectangles/heights, team spawn slots, two illustrative route waypoint chains and their checked path lengths. The floor is the union of room rectangles and corridor rectangles, minus solid cover footprints. It is NOT a list of finished Roblox Parts.

`tools/redesign_layouts.py` contains the fixed authored layout definitions and draws the plans. There is no random obstacle placement. Grid search only verifies connectivity and draws example routes; it does not design the map or demonstrate balance.

Recreate with Python, numpy and matplotlib:

```sh
python3 maps/concepts/v2/tools/redesign_layouts.py
```

## Verification completed

All six plans passed a one-stud raster ground-space check with a conservative square body-clearance erosion (two cells in every direction): no isolated traversable pocket, paths connecting both spawns through the listed example waypoints, and separate clear spawn positions for the proposed 2/3/4 players per team. All initial opposing slot pairs have blocked eye-level sightlines in the 2D model, treating floor boundaries as opaque walls and low cover as non-occluding at eye height. Route lines are loop-erased so a tiny grid-search artifact is not mistaken for a required backtrack.

These checks do not model Humanoids, collision corners, jump/slide exploits, true 3D rays, cover peeks, networked movement, first-contact timing or team balance. They do not establish that two route examples are vertex-disjoint. No Roblox import, construction, gameplay or multiplayer checks were run.

## Before building and testing

1. Review the six shapes/routes with the user. Resolve any desired changes before the scenery pass.
2. Select ONE map for a measured 3D graybox. Convert the exact floor boundaries to enclosing walls; don't leave void gaps as fall hazards. Use the existing map/spawn conventions and preserve tested 1v1 models.
3. Inspect doorway widths, body clearance, spawn facing, camera clipping, corners, jump height and unintended perches with the actual movement controller.
4. Compare both teams' time to first contested cover, early sightlines and flanks. Asymmetric shapes are proposals, not an excuse to give one team a fast angle.
5. Test with four/six/eight clients for the intended mode. Verify friendly-fire rejection, round reset, live-player spectating, elimination ammo awards and match return before decorating.
6. Only then add the distinct theme. Keep Crosscut basic and studded. Do not publish.

No construction or team-mode code is part of this revision.
