# Claude: environment-build review handoff

Continue your save-data/inventory work independently. These files do not modify `src/` or replace any current Studio map.

When ready for map review, fetch branch `design/environment-revamp`. Read `maps/revamp/README.md` before importing.

1. Review **Foundry first**, starting with `maps/revamp/models/Foundry.rbxmx`. Its 425 source instances from your `ff4a0ff` export are preserved property-for-property. All additions are under `EnvironmentRevamp`; its geometry checker reports the preservation separately from any Studio result.
2. Save the review place, import one map at a time, and take real player-height screenshots from both spawns and every route. External Blender previews are supplied solely for construction review.
3. Check geometry, overhead framing, visually solid/non-solid surfaces, climbing and silhouette visibility. Report and fix concrete construction mistakes; do not approve maps from part count or external previews alone.
4. Profile on PC. Container Yard has 6,052 Parts and is the main optimization candidate. Mesh consolidation may be appropriate, but preserve separate collision shells and spawn conventions.
5. Container Yard is a **new 136×136 gameplay layout**, including solid cargo. It needs full route/cover/LOS/jump and two-client match tests. It has no live adapter changes. Read the HRP-height spawn convention before integrating.
6. For Testing Grounds and Pump House, **do not replace corrected Studio geometry with the old repository baseline**. Compare the new `EnvironmentRevamp` folder and transfer only compatible additions, or export the corrected source for regeneration.
7. Check the other five team maps individually. Team modes stay disabled until the actual server implementation and multi-client tests are ready.
8. Keep a checkpoint of screenshots, performance measurements and issues per map. Keep originals backed up, save to disk, and don't publish.

The user's visual goal is a believable, fully dressed place, with distinct routes and map identities. Keep Crosscut intentionally basic and studded. These review builds need your actual Studio evidence before final approval.
