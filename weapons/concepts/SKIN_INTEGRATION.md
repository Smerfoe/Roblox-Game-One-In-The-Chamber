# Python skins: production and equip integration

The user likes the four rare finish concepts and asked how to make them equippable. This is a concrete implementation plan, not a claim that the current game has finished assets, ownership, persistence or crates.

## 1. Produce the real visual assets

Select/finalize the Python production mesh and split material groups (barrel/frame, cylinder, hammer, grip, sights). The current native-part prototype can preview simple colors, but elaborate engraving/iridescence needs a UV-mapped mesh with original texture maps or a deliberate supported Roblox material workflow. Reuse the SAME geometry, joints, sizes and offsets across skins. Don't create random ornamental geometry to approximate engraving.

Create actual assets for approved finishes, upload through the game owner's supported asset workflow and verify the experience has access. Preserve ownership/provenance; no invented asset IDs. Test SurfaceAppearance/material support in Studio and at actual gameplay lighting/FOV. Image-generation boards are not ready UV textures and must not be pasted onto the weapon as one image.

Keep sights matte and the aiming view unobscured. First test a plain color proof on the prototype without claiming it reproduces the concept. Finish-specific weapon meshes are not needed unless the production asset's material structure forces it; do not duplicate gameplay Tools or scripts per finish.

## 2. One authoritative catalog

Use immutable catalog IDs, for example:

- Weapon: `PythonMagnum`
- Skins: `python.default`, `python.eclipse`, `python.opal_vein`, `python.crimson_regent`, `python.aurora_titanium`

Each skin declares weapon compatibility, display name, preview assets and an approved appearance descriptor. Keep asset IDs/appearance descriptors in developer-owned catalog data, not in client equip messages. Don't mark a skin ready until the required production assets load.

Catalog entries must contain no damage, recoil, reach, spread, cooldown, ammo capacity or movement bonuses. Optional rarity metadata is presentation only and does not itself award a skin.

## 3. Ownership and selected skin

Reuse the game's existing player-data service if it exists. Inspect its schema, persistence and failure handling first. Conceptual stored data (adapt names to the current schema):

```text
ownedSkins: set of catalog skin IDs
selectedSkinByWeapon: { PythonMagnum: python.eclipse }
```

Default skin is always available. No authoritative balance/inventory is stored in a LocalScript. Add a dev-only server grant in a separate review place if testing rare skins; never ship global free-grant or test-mode toggles. If data isn't ready, show loading or unavailable rather than an empty profile that might overwrite existing ownership. Use safe existing update/retry/session policies; don't bolt on a competing datastore.

## 4. Equip request and acknowledgement

UI flow: Inventory > Python > Skins > Owned compatible skins > Preview > Equip Skin.

Reuse existing cosmetic/equipment remotes if present. Client sends only the chosen catalog skin ID plus minimal request correlation, NOT asset IDs, target Instances, prices, arbitrary tables or stat values. Rate-limit and validate on the server:

- profile loaded and request well-formed;
- known, enabled skin with ready assets;
- compatible with Python;
- ownership (default exempt);
- permitted player state and no conflicting loadout transition.

Only after acceptance does the server update selected skin and persist through the existing data layer. A rejected request leaves the previous selection intact. UI shows pending, equipped acknowledgement or clear error; rapid clicks cannot bypass ownership or produce stale response reversal. Persisted selection must be revalidated on join with a default fallback if catalog assets are retired.

Selecting the preview does not equip. Never infer ownership from the card being visible or a client-side equipped badge.

## 5. Consistent application

Use one vetted appearance applicator and catalog ID across these presentations:

- Local first-person Python viewmodel.
- Other players' world weapon model.
- Inventory/Store ViewportFrame preview.

Server owns the selected skin ID. Replicate that safe ID or public equipped metadata; clients may render the catalog appearance for other players, but cannot authoritatively change selection. Do not replicate the entire private owned inventory to everyone.

Apply appearance after cloning the base model and preserve joint/weld structure. Do not recreate Tools, reset ammo or cancel an ongoing attack to recolor. Default behavior: equip changes are accepted in the lobby and applied on the next weapon loadout; disclose this in the UI. If live visual swapping is later desired, review it separately and test state safety.

Handle missing asset permissions/load failures with the default appearance. No character/weapon disappearance on failure. Clear old surface/material overlays when reusing instances so skins cannot stack.

## 6. Gameplay contract

Python remains a one-bullet pistol option with identical authoritative combat behavior to other pistols. All finishes have identical geometry, muzzle origin policy, timings, visibility standards and hitbox behavior. Skin equip/reload/inspect never adds ammo. A long model cannot extend the raycast origin past walls. Keep existing elimination award validation.

The 0.1% figure was a possible rarity target only. First make equip/ownership work using safe test grants. Crates, rewards, currency spending and drop odds are a separate approved task. If implemented later, awards must be server-side and persisted, and any displayed odds must match the real distribution.

## Acceptance checks

- Owned compatible skin equips; unowned/unknown/wrong-weapon skin and injected asset IDs are rejected.
- Selecting a preview does not equip; failed/pending request does not show false ownership/equipped state.
- Equipped skin persists across rejoin when data saving exists and works on the next loadout.
- First-person, world weapon and inventory preview show the SAME approved finish.
- No ammo/attack/stat changes, reset, duplicate Tools, joint breakage or camera disruption.
- Death, next round, spectating, return to lobby and rapid requests remain stable.
- Catalog/loading/permission failure uses a safe default and never overwrites valid saved ownership.
- Compare target readability and aim visibility across all skins in varied map lighting.

This plan has not been integrated with the Studio-only game code. Production textures, profile bindings, equipment remotes, world presentation and multiplayer tests remain to be implemented/verified with the actual project.
