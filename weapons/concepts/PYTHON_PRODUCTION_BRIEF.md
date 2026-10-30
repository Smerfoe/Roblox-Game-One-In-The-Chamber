# Python rare finishes — production preparation

This document prepares the four liked designs for a real asset workflow. It is NOT a finished texture set, UV map, material pack or implemented skin. The user selected **Eclipse — black and gold** for the first detailed production pass. Opal Vein, Crimson Regent and Aurora Titanium remain later candidates.

Source visual: [PythonRareFinishes.png](PythonRareFinishes.png). Equip/ownership plan: [SKIN_INTEGRATION.md](SKIN_INTEGRATION.md). Standard: [../QUALITY_CHECKLIST.md](../QUALITY_CHECKLIST.md).

## Shared model contract

First choose/refine the actual production Python base. It must have independently addressable frame/barrel, cylinder/crane, hammer, grip and sight surfaces, and usable UVs if texture maps are needed. The native-part prototype supports color/material tests, but it cannot carry detailed continuous engraving merely by pasting this art board onto it.

All skins reuse the SAME production geometry, dimensions, joint hierarchy, pivot positions, muzzle/sight alignment and animation curves. No new protruding geometry, charms or oversized trim. Keep grip texturing/materials separate, since changing the frame must not accidentally recolor the whole grip. No manufacturer/photo art copied as an engraving texture.

Sights and sight channel remain matte neutral dark steel in ALL finishes. Engraving stays off sight faces and does not add bright edges through the aim path. No emissive maps, particles, animated material cycling, transparent components or special idle/fire sounds.

## Material studies

These are suggested art colors, not authoritative game stat/currency/catalog data. Test in real Roblox lighting; flat hex colors do not by themselves create metal, pearl or iridescence.

| Finish | Main surface | Grip | Accent | Readability constraint |
| --- | --- | --- | --- | --- |
| Eclipse | Polished blackened steel, base #23272B | Low-sheen black #181C20 | Fine antique gold #B99A52 | Gold stays thin and away from sights; black body must retain form in shadows |
| Opal Vein | Satin pearl-silver #D6DAD8 | Warm ivory #D8D1BD | Sparse mineral blue #6C919B | Highlights must not wash out sights or create a glowing white weapon |
| Crimson Regent | Burgundy satin #65343E | Dark walnut #432D28 | Restrained brass #B09356 | Warm colored panels stay secondary to the silhouette; no red team marker confusion |
| Aurora Titanium | Dark titanium #485462 with controlled blue/teal/violet variation | Matte charcoal #20262A | Muted teal #508A94 and violet #766386 | Static material impression, no shifting animation/bloom or rainbow glare |

### Eclipse — selected first finish

- Barrel side flats: one fine bordered gold line following existing surfaces; leave the crown/front-sight region plain dark metal.
- Frame side: one original geometric engraving composition with substantial quiet black space. Do not copy the concept's tiny arbitrary marks literally.
- Cylinder: sparse matching linework in flat texture/normal detail, not raised ornamental pieces. Keep the chamber openings visually clear.
- Grip: black low-sheen surface and one small flush gold medallion; no bonus geometry.
- Hammer, controls and cylinder crane: restrained gunmetal so the mechanism remains readable during reload.
- First approval should compare plain baseline vs this finish at IDENTICAL camera/FOV and lighting, including the aim view. No need to create the full crate system to review it.

### Opal Vein

Use shallow mineral-blue detail primarily on the grip; keep pearl color play subtle on barrel/cylinder. Avoid candy-white plastic and large marble cracks that distract from the form. If the supported material workflow cannot reproduce the desired effect, present a static satin alternative for approval rather than promising an unsupported shader.

### Crimson Regent

Burgundy only on existing upper/frame material surfaces with fine restrained gold borders. Dark walnut grip. Leave mechanical contact areas steel. It should read as a finished manufactured object, not a gold outline around every part.

### Aurora Titanium

Use controlled broad blue/teal/violet bands within existing metal surfaces, keeping one dark neutral value family. No time-driven animation. A static texture approximation is acceptable only after in-engine review; Roblox's material pipeline must be validated before describing it as physically iridescent.

## Smallest useful production sequence

1. Export/inspect the actual production mesh, UVs, material IDs and moving parts. Do not texture the wrong base and refit everything afterward.
2. Start with the selected Eclipse finish; review the actual production base/UVs before final texture work.
3. Prepare original base-color/material maps on that base and compare against baseline. Start with moderate texture resolution; choose final resolution from on-screen detail/platform budget, not rarity alone.
4. Import through the owner's approved asset workflow, verify experience permissions, inspect real Roblox rendering and provide side/three-quarter/first-person screenshots.
5. Add a DISABLED catalog descriptor until the approved assets load. Use existing immutable IDs and server-owned ownership/equip validation; no invented texture IDs or false Owned cards.
6. Use a dev-only test grant in a separate review environment to exercise preview/equip/respawn/rejoin. Keep production ownership untouched.
7. Only after approval and passing tests consider adding more finishes. Crate implementation is a separate stage.

## Acceptance evidence

- Same geometry/joints/scale/pivots as baseline, verified by data comparison, not just visual similarity.
- Sights, crosshair neighborhood and opponent recognition checked on bright concrete, dark interiors and warm/cool lighting.
- No material change mutates damage, range, rate limits, reach, ammo, rewards or animation timing.
- First-person, world-model and Inventory preview use the same accepted skin ID/materials. Invalid or inaccessible assets fall back safely.
- Reload/inspect/sprint/slide continuity remains correct; no flashing highlights or decals stretching when cylinder/crane moves.
- Record texture resolution, material/mesh count, asset ownership and practical render budget. Test lower graphics settings before release.

The proposed **0.1%** crate chance remains a future rarity idea only. No paid crate, random award, probability, inventory grant or monetization code is delivered here. No final skin material/texture or Studio test is claimed by this preparation document.

## Native-part material study delivered

`../skins/PythonEclipse_MaterialStudy.rbxmx` is an importable color/material study on the existing Python prototype. Its 73 Parts, joint transforms, sizes, collision and visibility flags match the baseline. Dark metal, dark grip, muted flute accents and small gold medallion/crane details establish the color balance. It has NO fine engraving, production texture, unlock, inventory grant or new gameplay logic. It is not automatically included in the ten-weapon preview pack. Follow `../skins/README.md` for isolated inspection.
