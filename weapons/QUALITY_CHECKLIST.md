# Weapon quality and integration review — ten existing prototypes

Purpose: improve existing weapons before expanding the roster. This is a concrete review standard, not evidence that the prototypes already meet it. Use the actual Studio assets if they are better than a generated prototype. Preserve the originals and review in a separate place first.

## Review order

1. Service 1911 (baseline for pistol feel/material quality).
2. Karambit (baseline for knife reach/hand contact).
3. Python-style revolver (moving cylinder and first rare finish).
4. Heavy Eagle / Old West revolver.
5. Machete / Bowie / literal butter knife / butterfly.
6. Repeater stays a preview-only art option until its role outside the pistol-only specification is approved.

Don't fit skins/animations to a production model that will immediately be replaced. Inspect each and record Keep / Refine / Replace, specific issues and next action.

## Shared acceptance standard

### Silhouette and construction

- Consistent scale relative to the real hands and the baseline view offset. No long weapon clipping through the camera or filling too much of the screen.
- Single coherent barrel, intact trigger guard, aligned sights, physically connected visible parts and deliberate seams. No overlapping plates to hide broken geometry.
- Knife blades have a continuous profile and clear edge/spine, not disconnected blocks. No random teeth or ornaments absent from the approved direction.
- Moving assemblies have meaningful separate parts/joints: no duplicate anchors, loose pieces, incompatible joint writers or animated whole-body recoil moving server hit origins.
- Native-part prototypes need an honest final-mesh decision. Do not label blocky parts as photorealistic because a concept image is detailed.

### Materials

- Separate grip, frame/barrel/slide or cylinder, and sight material groups where needed. A combined original mesh may need re-export/UV work before grip-only recoloring.
- Metal has controlled reflectance; grips read differently; sights remain matte/readable. No excessive gloss, emissive glow, visual noise or default rainbow rarity finishes.
- Wear belongs to plausible high-contact edges. No random dirt scatter or thick geometry used as engraving.
- Validate actual Roblox material/shadow appearance at eye height, not only a concept image or plotting preview.
- Asset provenance/ownership/permissions are documented. No copied product photo, random Toolbox dependency or invented asset ID.

### Hands and animation

- Fit the real arm rig: continuous grip, fingers around appropriate contact points, no floating weapon, broken wrists or finger clipping.
- Equip, idle, fire/slash, replenishment presentation, sprint, slide, inspect, unequip and interrupted return each tested. Existing movement controller owns real movement.
- Attack/equip can interrupt inspection; death/reset/spectating/swap clears all transient poses and props. No accumulated drift over repeated actions.
- Mechanical part action suits the weapon. Do not reuse a pistol slide on a revolver or swing the Old West cylinder out like the Python.
- First-person and world presentations are consistent. Don't publish a first-person-only animation as a complete replicated implementation.
- Replenishment/inspect never awards ammo. Presentation duration must not quietly add a gameplay lockout or affect server attack timing.

### Balance and readability

- Every pistol cosmetic uses the same approved server damage, one-bullet capacity, range, rate limit and hit validation. Knife variants share the approved range, front/back damage and cooldown.
- No different hitbox, muzzle-origin advantage, reach, zoom, aim obstruction, particle concealment or useful audio difference from rarity.
- Long visible barrels/blades don't shoot/hit past walls or suggest extra effective reach. Adjust the presentation, not the damage query, if misleading.
- Compare the same viewpoint/FOV and an opponent view across variants on bright/dark maps. Preserve target and sight readability.

### Runtime and reliability

- No extra collisions, touches or ray-query shields from local decorations; no duplicate Tool or per-frame instance allocation.
- One active viewmodel/animation owner, cleanup on camera/character replacement, no orphan props or growing event connections.
- Use current server-accepted attack cues; respect countdown/combat/round-end/practice policy and rollback visual prediction if used.
- Desktop is the primary current test target. Shared input actions should accommodate controller/touch later; untested devices stay marked unrun.

## Model-specific review targets

| Prototype | Main risk to inspect |
| --- | --- |
| Service 1911 | Grip separation, slide/frame alignment, magazine/cartridge path and hand contact |
| Karambit | Hook silhouette, ring grip, controlled flourish without detached fingers |
| Python Magnum | Crane pivot, cylinder/frame clearance, one-cartridge path, hammer, long-barrel framing |
| Machete | Visual contact versus shared knife range; no roof/camera obstruction from long blade |
| Butter knife | Literal rounded utensil silhouette; same melee rules despite comic appearance |
| Repeater | Lever/breech clearance, stock/camera clipping, unapproved rifle gameplay scope |
| Old West revolver | Fixed-cylinder/loading gate behavior, grip fit and distinct reload presentation |
| Heavy Eagle | Fixed front upper versus moving rear slide; no oversized camera obstruction |
| Butterfly | Parallel pivot positions, blade/handle clearance and hand-coordinated flips |
| Bowie | Edge/spine alignment, guard/hand clearance, saw detail readability without gameplay reach change |

## Minimal evidence before integration

Capture neutral side/three-quarter screenshots, a player-eye screenshot and short motion recordings. Repeat/interrupt each action, reset while a mechanism is open, replace camera, and test both local/world presentation. After integration run two-client combat/round/practice/spectating regressions. Studio-only render and mechanical failures must be fixed before declaring polish complete.

Use the attached STATUS table. **NOT REVIEWED** means no evidence yet; it is not a pass.
