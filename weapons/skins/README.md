# Eclipse — selected Python finish, material study v1

The user selected black-and-gold **Eclipse** as the first rare Python finish. `PythonEclipse_MaterialStudy.rbxmx` is a real importable Roblox model, but only a native-part color/material proof, NOT the ornate finished skin shown in the concept art.

It keeps all 73 baseline Parts, positions, dimensions, joints, collisions and visibility flags. No new geometry is added. Blackened metal and dark grips are contrasted with small gold medallion/crane details and muted cylinder accents. Sight geometry and the original dark sight color are preserved; in-engine readability still needs checking. There is no engraving texture, mesh UV work, particle effect, sound or gameplay change.

## Inspect separately in Studio

1. Preserve the working assets. Import this file into a separate review place for static color inspection under neutral and in-game lighting.
2. Compare with `models/PythonMagnum_Prototype.rbxmx` at the SAME view/FOV. Don't leave overlapping copies at the origin.
3. For procedural preview, store this model under a separate copy of `WeaponPreviewPack` in a review place and explicitly select its model with animator kind `Revolver`. Keep the existing pack and source templates recoverable; don't insert a second preview client into the game.
4. Verify the existing Reload/Inspect still works with the original motors and that color contrast does not hide the sights. No hand/UV/production polish is claimed.
5. This model is NOT an ownership grant, enabled catalog skin or final material asset. Use the production brief and skin-integration plan before adding it to the actual inventory.

Reproduce: `python3 weapons/tools/build_eclipse_study.py`.

External validation: baseline/study part/joint/weld count, transforms, sizes, collision/visibility and reference relationships are identical. No embedded scripts. Roblox engine import, actual material/reflectance appearance, hands, animation rendering and gameplay remain untested here.
