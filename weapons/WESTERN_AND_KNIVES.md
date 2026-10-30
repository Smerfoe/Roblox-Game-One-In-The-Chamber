# Repeater, Old West revolver, heavy pistol, butterfly and Bowie prototypes

This batch contains original editable native-part approximations inspired by the user's reference screenshots. It does NOT download or reuse the pictured Sketchfab/commercial models, trademarks, logos or imagery as production assets. These are not finished high-detail meshes or drop-in gameplay Tools.

## New models and presentation kinds

| Model | Parts | Animator kind | Art direction |
| --- | ---: | --- | --- |
| FrontierRepeater_Prototype | 64 | Repeater | Dark iron, wood fore-end and continuous stock profile, articulated lever and breech |
| OldWestRevolver_Prototype | 68 | OldWest | Brass frame/barrel, ivory-tone grip, fixed-cylinder layout and separate loading gate |
| HeavyEagle_Prototype | 81 | HeavyPistol | Broad silver upper, dark grip/frame, fixed front shroud and moving rear slide |
| ButterflyKnife_Prototype | 33 | Butterfly | Steel blade, dark twin handles with blue insets, independent parallel handle pivots |
| TrailBowie_Prototype | 77 | Bowie | Dark broad blade, bright edge strip and spine teeth, guard and cylindrical ribbed grip |

All visible parts are noncolliding/CanQuery=false; these are client presentation models. The actual damage system must not raycast/hit-test these decorative shapes. The butterfly knife is separate from ButterKnife_Prototype, which remains a literal table knife.

## Preview

Read `README.md` for exact Studio hierarchy/import steps. The regenerated `WeaponPreviewPack.rbxmx` now includes TEN models and the updated WeaponAnimator module. The updated `WeaponPreviewClient.rbxmx` cycles all ten with Q, preserving the earlier five. Use a SEPARATE review Baseplate, and remove only an older duplicate sandbox pack/script there before importing. Leave the working game's production models/controllers alone.

Left click: firearm recoil or knife attack presentation. R: one-cartridge reload presentation on firearm types only. F: inspection. Hold Shift/C: sprint/slide WEAPON POSES, not actual locomotion. P: stop and restore previous camera mode. There are no gameplay damage, bullets, rewards or network requests in this sandbox. Hand/arm rigs and audio are not included.

`WesternAndBladesGeometryPreview.png` plots the actual export, not the final in-engine appearance. Wedge edges are deliberately drawn in that preview so geometry can be inspected; surface weathering and smooth production mesh polish are not present.

## Animation behavior

- **Repeater:** equip 0.65s, fire/recoil plus lever/breech presentation 0.65s, one-cartridge reload 2.05s, inspect 2.80s. The lever and breech have separate joints. The fire animation does not create a shot or enforce a fire rate.
- **Old West:** equip 0.55s, fire 0.28s, loading-gate one-cartridge reload 1.95s, inspect 2.85s. The cylinder stays fixed during this presentation; it does NOT swing out like the Python. A separate cylinder joint exists as an integration pivot, not an instruction to use the Python reload on this model.
- **Heavy pistol:** original pistol equip/reload/inspect timings, distinct 0.28s fire recoil/rear-slide motion. The front barrel shroud/sight remain fixed. Uses its own preview offset. This is a presentation approximation, not a mechanical simulation of the reference firearm.
- **Butterfly:** closed-handle start to open equip 0.60s; 0.46s attack; 2.60s inspect with independent handle folds. A hand-coordinated flip is NOT complete until fitted to the real hand rig. Check handle/blade clearance and direction in Studio before treating these curves as final. The prototype has no working latch release/finger animation.
- **Bowie:** measured machete-family equip 0.50s, slash 0.50s and face-inspection 2.50s; own model/offset. Same peak visual slash extension near the existing 0.15s melee hit delay. No finger-spin on a fixed blade.

Reload tracks show one cartridge prop only during their defined window; cancel/cleanup hides it. Frame boundaries and state transitions are tested under mocks, not the Roblox renderer. All actions target original joint rest poses.

## Preserve the original game rules

The repeater is a new RIFLE-shaped option, outside the original pistol-only match specification. Keep it preview-only until the user approves its role. Do not quietly add rifle range, zoom, damage, fire-rate, extra ammo or new matchmaking rules. If approved as an appearance-only alternative, route it through exactly the existing one-bullet server pistol behavior and validate camera/sightline equivalence.

New pistol presentations must not grant ammo or adjust the server's accepted attack timings. R in the sandbox is cosmetic; production players cannot reload for free after a miss. Keep server-granted elimination replenishment as the only match ammo award unless a new rule is explicitly approved. Decide presentation duration separately from gameplay responsiveness.

Every knife must use the same existing 6-stud server range, 50 front / 100 backstab damage and 0.6s cooldown. Longer blade appearance must not extend melee detection. If visible contact disagrees with the shared hit range, adjust scale/poses, not the hitbox. No new purchased/cosmetic advantage.

Do not use viewmodel muzzle movement as the server shot origin or allow a long barrel to shoot through a wall from outside the character. Existing server ray validation remains authoritative. New animated joints are client presentation only, never a source of player damage or rewards.

## Tests and limitations

Completed here:

- All ten rigs: valid finite positive dimensions/orthonormal part rotations; unique references and named joints; one anchor; acyclic, connected, exactly-one-parent assembly graph; correct initial joint rest positions; no scripts in loose model files; deterministic rebuild.
- Updated WeaponAnimator/Preview client compile with official Luau 0.699.
- Executed animation state tests for all new kinds: allowed actions, required joint contracts, strictly increasing keyframe times, rest endpoints/durations, reload prop visibility/cancellation, inspect interrupted by sprint, repeated action lifecycle and cleanup. Lightweight mocks do NOT validate actual CFrame rotation interpolation, Motor6D engine behavior or visual appearance.
- Import pack source is verified against the reviewed Luau source and includes ten unique model names.

Still required in Studio: engine import, visual scale/materials, view offsets/FOV/near-plane clipping, lever/cylinder/gate/handle clearances, cartridge entry alignment, hand fitting, sound, world-model variants, inventory integration and two-client combat regressions after reviewed integration. Models are native-part prototypes; final realism requires an approved production mesh/material pass. Do not publish.
