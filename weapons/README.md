# Service 1911 and Karambit — animated prototype pack

This is a standalone first-person weapon presentation pack for Studio review. It contains REAL editable Roblox models and executable procedural Luau animations, not only concept pictures. It does not modify the existing Studio weapons or game services.

## What is built

- **Service1911_Prototype:** 74 native parts/wedges, separate wood grips, slide, hammer, magazine and one cartridge prop; rounded trigger guard, grip screws, slide serrations, sight details and muzzle inset.
- **Karambit_Prototype:** 59 native parts/wedges, continuous hooked blade profile and open finger ring, separate grip scales and pins.
- **WeaponAnimator:** client-side procedural equip, firing/recoil/slide/hammer, single-cartridge magazine reload presentation, pistol inspection, knife equip/slash/inspection flourish, and idle/sprint/slide poses. No animation asset IDs or upload permissions are required for this procedural preview.
- **WeaponPreviewPack.rbxmx:** importable Folder containing both rigs and the animation ModuleScript.
- **WeaponPreviewClient.rbxmx:** importable Studio-only LocalScript for testing.
- **GeometryPreview.png:** a plotted view of the ACTUAL exported geometry, not concept art or a Roblox engine screenshot.

These are native-part prototypes, not photorealistic final meshes or production animation. The user-approved finish concept images have more surface detail. The knife's silhouette is continuous but faceted; a later artist-authored mesh/material pass will improve appearance. No custom textures, hand/finger animations, arm rigs, sound effects, multiplayer world animation, or Colt Python revolver are included in this pack. The current Studio weapon/viewmodel code was not available in GitHub, so these cannot claim drop-in compatibility with that implementation.

## Quick preview in a SEPARATE Studio Baseplate

1. Pull this folder from GitHub. Save a backup and open a separate Baseplate; do not install the preview into the working game.
2. Import `WeaponPreviewPack.rbxmx` using Insert from File or drag into Studio, then MOVE the resulting **WeaponPreviewPack** Folder into **ReplicatedStorage** before pressing Play. This folder includes the ModuleScript and the two models. Keep the name unchanged.
3. Import `WeaponPreviewClient.rbxmx`, then MOVE the resulting **WeaponPreviewClient** LocalScript into **StarterPlayer > StarterPlayerScripts**. Do not leave a LocalScript in Workspace and expect it to run.
4. Press Play (client Play, not server-only Run). It temporarily locks first-person and clones only the selected prototype under CurrentCamera. It does not delete any existing viewmodel. Use the separate Baseplate to avoid duplicate weapons or input conflicts.
5. Controls: left click = fire/slash animation; F = inspect; R = cosmetic pistol reload; Q = switch prototype; hold Left Shift = sprint pose; hold C = slide pose; P = stop preview and restore the previous camera mode. Shift/C only preview weapon poses; they do not implement locomotion or change character speed.
6. Reset the character during testing and verify cleanup/recreation. Stop Play to restore edit state.

The expected hierarchy is:

```text
ReplicatedStorage
└── WeaponPreviewPack
    ├── Service1911_Prototype
    ├── Karambit_Prototype
    └── WeaponAnimator (ModuleScript)
StarterPlayer
└── StarterPlayerScripts
    └── WeaponPreviewClient (LocalScript)
```

Do not import both this complete pack and the loose models/module into the same Folder: duplicated names would make asset lookup ambiguous. Loose files under `models/` and `animations/` are for review/custom integration.

## Animation durations and behavior

| Presentation | Seconds | Notes |
| --- | ---: | --- |
| Pistol equip | 0.48 | Settles from lowered pose |
| Pistol fire | 0.24 | Slide/hammer and small recoil; does not fire a ray |
| Pistol one-round reload | 1.55 | Magazine lowers, one prop cartridge inserts, magazine returns, slide racks |
| Pistol inspect | 2.65 | Two side presentations and controlled return |
| Knife equip | 0.42 | Controlled draw |
| Knife slash | 0.46 | Strongest extension at 0.15; presentation only |
| Knife inspect | 2.35 | Blade presentation and controlled rotating flourish |

Inspection can be interrupted by action or locomotion changes. Tracks always target their authored rest pose; frame interpolation handles blend-out without multiplying accumulated offsets. No AnimationTrack publishes or network state changes occur. The knife visual timing must remain subordinate to the existing server's 0.15-second hit delay and 0.6-second attack cooldown. Do not replace combat timing with the table above.

The R key exists ONLY in this visual sandbox. It never changes ammo. In the live game there must be no unlimited manual reload after a miss. Decide when to present the reload after an existing SERVER-GRANTED replenishment; if a full reload would alter responsiveness, use a shorter replenishment presentation or inspect-only version instead. Do not add a 1.55-second gameplay delay without approval. World combat and ammo remain owned by the existing server.

## Rig contract

Both rigs have one anchored transparent **Anchor** at the origin and one **Presentation** Motor6D to the body. Every other part is unanchored, massless and noncolliding; CanTouch/CanQuery/shadows are disabled. Each visible part is welded exactly once to its assembly. The 1911 has unique **Slide**, **Hammer**, **Magazine**, and **Cartridge** Motor6Ds. The root points down local -Z.

WeaponAnimator adjusts C0 from captured rest values. It must be the only writer for those joints: don't run an Animator or another C0 procedural controller on them simultaneously. Tune view offset after import and test camera clipping. Destroy the driver before deleting the model, and recreate it on weapon/model replacement. The module does not own player cameras or gameplay state; the sandbox LocalScript owns its temporary first-person camera mode.

## Instructions for Claude

Inspect the models and `GeometryPreview.png` before proposing replacement of existing assets. Test this pack in the separate place first. Preserve the original Service1911, Karambit, viewmodels and controllers in a recoverable backup. Do not overwrite their meshes, animations or names blindly.

Integration must use the existing ViewmodelController, WeaponController, KnifeController and WorldEffectsController responsibilities. This pack is FIRST-PERSON weapon-only presentation. It supplies no arms; visually convincing reload/knife inspection needs the real hand rig, attachment transforms and coordinated hand poses. Export/read those assets before fitting the hands, so grips don't float or clip. A knife pivot flourish without coordinated finger release is a preview motion, not a finished finger-spin animation.

Prefer adapting these motion curves and separate-part rig concepts to a higher-quality existing mesh when available. Existing combined mesh grips cannot be recolored separately until the mesh is split/re-exported or a supported texture workflow is used. Do not hide a working mesh under blocks just to claim it is polished.

Connect presentation to real accepted events/phase eligibility. Visual prediction, if used, must roll back cleanly after server rejection. Do not send new damage/fire/remotes from WeaponAnimator, change hitboxes, move muzzle server ray origins according to inspection poses, or alter server cooldowns/ammo. Interrupt/reset on death, unequip, spectating and lobby return. Hide the dead player's weapon while spectating. Do not install the sandbox inputs in the actual game.

## Required Studio review

- XML import succeeds; correct materials, wedge orientation, part scale and weld offsets.
- No exploding assemblies, physics jitter, detached slide/magazine or cartridge visible at rest.
- Check at several FOVs and first-person offsets: near-plane clipping, muzzle visibility and inspect framing.
- Play every animation repeatedly. Interrupt inspect with attack, reload with swap, sprint/slide with equip, reset during each track, replace CurrentCamera and stop the preview.
- Check one cartridge visible only during the reload window; no stray visible prop remains after cancellation.
- Fit actual hand rig and verify grips, finger contacts, no floating weapon, no wrist clipping or accidental finger-through-trigger spin. Weapon-only preview cannot pass this check by itself.
- Keep existing server attack timings. Two-client gameplay regression after integration: accepted fire, misses, knife/backstab, one ammo award per confirmed elimination, spectating, next round and lobby return.
- No unintended ammo from R/inspect/animation completion; no additional collision or line-of-sight behavior from cosmetics.
- No publishing.

## Checks run here

- Python rig checks: positive finite sizes, unique reference/motor names, one anchor, all visible parts connected by an acyclic single-parent weld/joint graph, correct rest positions, no embedded scripts in loose models, byte-identical rebuilds.
- Official Luau 0.699 compiler: both Luau sources compile. This is a syntax/bytecode check, not full Roblox API type analysis.
- Executed real animation state code under Luau with explicit lightweight engine mocks: action availability, inspection gating and interruption, reload prop window, cancellation, locomotion, repeated actions, knife attack, camera replacement and cleanup pass. Mocks do not establish correct actual rotations, Motor6D evaluation, rendering or Studio behavior.
- Exported geometry preview was inspected; a disconnected-looking segmented blade was replaced with a continuous wedge profile.

Roblox Studio import, animation appearance, hands, sound, multiplayer integration and gameplay tests remain UNRUN here.

Rebuild from repository root:

```sh
python3 weapons/tools/build_weapons.py
python3 weapons/tests/check_rigs.py
python3 weapons/tools/package_preview.py
```

Optional preview: `python3 weapons/tools/render_preview.py` (matplotlib/numpy).
Optional executable state tests: `python3 weapons/tests/run_animation_checks.py /path/to/luau`.
The complete preview pack contains exactly the reviewed ModuleScript and Studio-only LocalScript sources above; no downloaded scripts or assets are embedded.
