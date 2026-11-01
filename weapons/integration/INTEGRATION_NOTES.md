# Studio test armory integration — 2026-11-01

The ten native-part prototypes from `Smerfoe/Roblox-Game-One-In-The-Chamber/weapons/models` are downloaded beside this document and staged in `ServerStorage.WeaponExpansionStaging`. The production 1911/karambit templates remain intact. Eight additional Tool templates live in `ReplicatedStorage.Assets.ArmoryTools`.

In Studio Play, use **TEST ARMORY** at the lower left of the lobby. Each session starts with 125,000 test coins, the free Service 1911 and Basic Knife (ButterKnife prototype). Buy/select a gun or unbox/select a blade, then enter practice or start a new round to use it. Choices apply at the next loadout. The current gameplay Tool names remain Service1911/Karambit, while ArmoryId identifies the chosen appearance. This preserves existing server validation and one-bullet rules, including automatic knife switching after a miss.

Gun prices: Western Revolver 2,500; Heavy Eagle 7,000; Python Magnum 10,000; Frontier Repeater 100,000. The test crate costs 10, with Karambit, Butterfly Knife, Machete and Trail Bowie each at 25%. Duplicate drops refund all 10. No additional sword asset exists in the reviewed repository. The literal ButterKnife is the free basic knife; the ButterflyKnife is a separate crate item.

## Code

- ArmoryCatalog: actual rig IDs, slots and draft prices.
- DevArmoryService: server-authoritative Studio-only balances, ownership, equip selection and random crate roll. Bounded response cache plus request high-water mark prevent repeat charging; request cooldown and lobby-only mutations are enforced.
- DevArmoryController: test shop, equip controls, crate contents and odds. Session reset behavior is shown in the UI.
- LoadoutService: Studio-only server-selected templates; skin handling and original combat Tool names remain.
- ViewmodelController: builds from the equipped server Tool, evaluates its joint graph using rig animation curves, and keeps the avatar's hands following the animated Body presentation.
- ArmoryAnimator: reviewed repository WeaponAnimator plus a pure Sample API used by the main FPS renderer. Separate revolver/lever/butterfly tracks play on accepted attack cues and F inspection. No cosmetic reload grants ammo.
- import_models.py: allowlisted XML conversion to bounded instance creation scripts. No model scripts execute during import.

Backups: `ServerStorage.Backups.BeforeDevArmory_2026_11_01` contains original LoadoutService and ViewmodelController. Earlier backups preserve the original grip/pose modules and weapon templates. The current implementation leaves the existing DataService and schema untouched.

## Executed validation

- Imported all ten rigs. Eight additional Tools created; current mesh 1911/karambit retained.
- Purchase: Western Revolver deducted exactly 2,500. Replaying its request ID deducted nothing further. Unowned Python equip was refused. NaN request ID was rejected.
- Crate: all four blades obtained; each first acquisition cost 10. Repeated duplicate drops refunded exactly 10. Balances remained consistent.
- Each of Western Revolver, Heavy Eagle, Python and Repeater selected, entered practice, created a first-person model and generated a server-confirmed tracer and shot sound. Miss consumed its one bullet. No new runtime errors.
- Basic Knife, current Karambit, Butterfly, Machete and Bowie each selected/equipped, created a viewmodel and emitted server-accepted swing sound.
- Western Tool inspection found zero anchored or colliding parts and the player remained alive.
- Test GUI exists and its lobby button is visible. Automated mouse-click capture stalled, so panel interaction/layout still needs a manual UI review.

## Remaining work and limits

This is a **Studio development pass**, not a finished live economy. Test balances/ownership reset when Play stops, never touch saved profiles, and are disabled in live servers. Live coin earning rate, durable purchase migration, currency/ownership recovery, and production shop integration remain future work. Do not describe this as persistent purchases.

True two-client match testing has not run: the connected Studio tool provides one-client Play controls, without a multi-client launch API. Observer animations/sounds for the newly added joints and all round transitions need that test. The current world-effects controller still only animates the original pistol joints; new first-person rigs use their own tracks, but remote players do not yet see the new lever/cylinder articulation. Physics and gameplay still use the original server rules.

These assets are native-part prototypes, not final realistic meshes. Broad avatar fitting, near-plane clipping, material quality, listening/mix review, all inspection poses and UI layout require visual review. Arms reuse the player's hand meshes; articulated fingers are not authored. Studio was returned to Edit mode. Nothing was published or merged into main.
