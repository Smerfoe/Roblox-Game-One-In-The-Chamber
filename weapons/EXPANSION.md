# Python-style revolver, machete and butter knife

This document describes the first expansion. The current pack now has ten models; see `WESTERN_AND_KNIVES.md` for the next five.

## Delivered prototypes

- `models/PythonMagnum_Prototype.rbxmx`: 73 native parts. Long fixed barrel, vented rib, wood grip, independent cylinder/crane, hammer and single-cartridge prop.
- `models/Machete_Prototype.rbxmx`: 27 parts/wedges. Broad continuous tapered blade and three-rivet handle.
- `models/ButterKnife_Prototype.rbxmx`: 23 parts/wedges. Rounded table-knife blade and stainless handle. This is a literal butter knife, NOT a butterfly/balisong.
- `NewWeaponGeometryPreview.png`: actual exported geometry, plotted outside Roblox.
- `concepts/PythonRareFinishes.png`: four visual-only rare finish proposals; see accompanying finish document.

The first expansion added these three to the original 1911 and karambit; the full pack now also includes the five listed in `WESTERN_AND_KNIVES.md`. Reimport the updated `WeaponPreviewPack.rbxmx` and `WeaponPreviewClient.rbxmx` into a separate review place, removing only a previous preview pack/script of the same name in that review place. Do not duplicate packs and do not delete production weapons. Follow `README.md` for locations. Q cycles all ten. Left click fires/slashes cosmetically, F inspects, R presents a cosmetic reload on 1911 or revolver only; hold Shift/C for weapon sprint/slide poses; P stops. There are still no arms or fingers in this standalone pack.

## Revolver animation

Presentation kinds: `Revolver`, `Machete`, `ButterKnife` (original `Pistol`/`Knife` kinds still work).

Revolver has equip (0.55s), fire/recoil (0.28s), controlled one-cartridge reload (2.0s) and inspection (2.85s). Reload sequence:

1. Present the weapon and swing cylinder/crane out on its own Motor6D.
2. Show ONE cartridge prop, move it to a selected chamber position, and hide it as it enters.
3. Close the cylinder/crane into the frame under controlled motion.
4. Brief hammer presentation and settle to ready.

A revolver has no pistol slide; do not reuse the 1911 slide track or move the fixed barrel. Chamber discs are shallow visual recess markers on a solid native-part cylinder, not actual boolean-cut holes. No six-round ammo state, speedloader, bullet grant or combat logic is included. There is no explicit spent-case ejection animation in this pass.

The inspection presents both sides with a controlled wrist-style flourish while the cylinder remains closed. The weapon is not tossed. Without the actual hand rig, all of this remains weapon-only procedural motion rather than a finished hand-coordinated reload/inspect.

## Knives

Machete: equip 0.50s, attack 0.50s, inspect 2.50s. Inspection shows the blade faces with a measured turn; no karambit-style finger spin.

Butter knife: equip 0.35s, attack 0.42s, inspect 2.10s. Smaller presentation turn shows the intentionally ordinary polished utensil.

Both attack poses peak at approximately 0.15s to support the existing server's melee hit delay, but no server timing changes are made or authorized by these cosmetic durations. Both use only the Presentation joint. Longer visual blade does not grant extra reach, damage or hitbox area. When integrated, use the SAME existing 6-stud server range, 50 front/100 backstab damage and 0.6s cooldown as all knives. Test long-blade visual reach against that range; adjust local scale/poses if visual contact is misleading rather than expanding the hitbox.

## Production integration constraints

- These are noncolliding client presentation rigs, NOT damage Tools. Use the current loadout and server weapons architecture.
- The revolver must remain one-bullet and one-hit just like the current pistol. No greater range, accuracy, fire-rate or hitbox advantage; no random spread.
- NEVER grant ammo because R was pressed, a cylinder closed, an inspect ended or an animation marker fired. Replenishment must remain a confirmed server elimination award. Decide whether to show the full reload after a grant without adding an unapproved combat delay.
- The preview's visible barrel position must not become a user-controlled server shot origin. Existing hit validation remains authoritative.
- New sounds, arms, third-person world animations, final meshes/materials and inventory/loadout integration are not included. Don't claim they exist from this package.
- Split the actual production model into appropriate parts/material groups before mapping these tracks. Keep the tested originals as fallback. Export the real viewmodel and review hand positions before replacing meshes.
- All new finishes are cosmetic concept art only; rarity/economy/crate behavior is out of scope.

## Verification completed here

All ten loose rigs pass finite positive dimensions, orthonormal rotation matrices, connected acyclic single-parent assembly graph, single anchor, unique joint references, no embedded scripts, expected named motors and deterministic generation. Both updated Luau scripts compile with official Luau 0.699. State tests now exercise revolver reload prop windows/inspection/fire and both knife variants, alongside original cancellation/cleanup tests. Bundled sources match reviewed source files.

## Still required in Studio

Engine XML import, real wedge/metal appearance, cylinder clearance/open-close direction, cartridge alignment at the selected chamber, muzzle/sight alignment, first-person framing at different FOVs, hand fitting, viewmodel cleanup, sound and multiplayer balance. Test interruption/restart while cylinder open and ensure no orphan cartridge remains; inspect must never open the cylinder or grant ammo. Run prior game regressions only AFTER an explicitly reviewed integration. Do not publish.
