# Two-client Studio playtest of PR #2 — 2026-11-01 (Claude)

Tested the build Codex installed in Studio (it matched `codex/studio-test-armory` @ b3dd33d, apart from trailing newlines). No duplicate imports: there was one copy each of the scripts, remotes and ArmoryTools. **Not published, not merged.**

Backups made before testing / fixing:
- `ServerStorage.Backups.BeforeClaudePlaytest_2026_11_01`: all services, Data, Shared and StarterPlayerScripts.
- `ServerStorage.Backups.BeforeArmoryScaleFix_2026_11_01`: the unscaled `ArmoryTools` and the previous ViewmodelController.

Setup: Studio *Server & Clients* with 2 clients (Player1 / Player2) on map TestingGrounds, plus a solo Play run to recheck the fix. Network simulation was changed only during the latency test and restored afterwards (see below).

## Results

### Combat, two clients: PASS

Full best-of-five, played with the new weapons. Player2 used the Western Revolver and Butterfly Knife; Player1 the defaults (Service 1911 and Basic Knife). Final score 2-3, Red wins.

| Round | What happened | Result |
| --- | --- | --- |
| 1 | Player2 fires the revolver with a **real mouse click** (normal input and prediction path) | eliminated Player1, bullet restored; 0-1 |
| 2 | Player2 deliberately misses over Player1's head | ammo 1 → 0, automatic switch to the knife |
| 2 | Player2 swings the Butterfly Knife with real clicks | first swing missed (still turning); then front hit for 50, then front elimination; ammo 0 → 1; 0-2 |
| 3 | Player1 fires the 1911 | eliminated Player2, bullet restored; 1-2 |
| 4 | Player1 knifes Player2 from behind with the Basic Knife | front hit for 50 (the victim's turn hadn't replicated yet), then **backstab** elimination; ammo stayed at 1 (maximum); 2-2 |
| 5 | Player2 fires the revolver with a real click **under 200 ms simulated lag** | eliminated Player1; 2-3 |

After the match: Result showed Defeat for Player1 and Victory for Player2, and both returned to the lobby with the match attributes cleared and no Tools. Armory selections were kept for the session. The server log shows no runtime errors on either client.

### Each player sees and hears the other's attacks: PASS (one note)

Every Sound, flash, casing, tracer and impact created on each client was logged.

| Situation | Shooter / attacker | Other client |
| --- | --- | --- |
| Revolver shot, real click | exactly 1 shot sound, 1 muzzle flash, 1 casing, 1 tracer (tracer about 50 ms later) | live observer: 1 tracer, 1 flash, 1 casing, 1 shot sound (3D, at the shooter) |
| 1911 shot | 1 of each | 1 of each, including the victim |
| Knife swing ×3 | 1 swing sound per swing | 1 swing sound per swing, at the attacker |

No duplicates anywhere: predicted and confirmed presentation never doubled up.

**Note (seen once, not reproduced):** in round 1, the player killed by the revolver heard the shot but got no tracer or flash. In round 3, the 1911 victim did get them. Retest this once the weapons are final.

### Simulated latency: PASS

`settings().Network.IncomingReplicationLag` was 0 on both clients before the test. It was set to 0.2 s on both clients for round 5, then set back to 0 and checked afterwards.

| Measurement | Result |
| --- | --- |
| DevArmory RemoteFunction round trip, no lag | 32-48 ms |
| Same round trip, 200 ms lag | 216-235 ms |
| Real click under lag: predicted shot sound, muzzle flash, casing | same frame as the click |
| Real click under lag: server-confirmed tracer | +250 ms |
| Duplicates under lag | none (one of each effect) |
| Elimination under lag | applied normally |

### Frame times while actively rendering: MEASURED

RenderStepped sampling worked in an active Studio test client. Three Studio processes were running on the same PC, and Studio caps at 60 fps.

| Scenario | Frames | Average | Median | p95 | p99 | Max |
| --- | --- | --- | --- | --- | --- | --- |
| Practice, holding the 68-part revolver viewmodel, idle | 482 in 8 s | 16.66 ms (60 fps) | 16.69 ms | 18.09 ms | 19.02 ms | 19.82 ms |
| Sprinting and sliding | 334 | | 16.61 ms | 18.35 ms | | 19.24 ms |
| Scripted run | 201 | | 16.73 ms | 17.97 ms | | 23.23 ms |

No hitches above 24 ms were seen. This is Studio's client on this PC, not a phone or low-end device.

### First-person feel

- **Sprint:** with real Shift+W, state Sprint, WalkSpeed 16 → 24, and the field of view eases 70° → 74° and back to 70° on release.
  - Scripted `Humanoid:Move` can't test this, because the ControlModule resets MoveDirection every frame.
- **Slide (C):** state Slide, camera offset eases to -1.1 studs, field of view +2°, and both return to normal afterwards.
- **Camera comfort:** the changes are small and eased, with no snapping. Bob and sway are modest.
- **Grips and size: FAILED, then FIXED (see below).**
  - All eight armory prototypes were 1.9-4.4× the size of the production weapons. For example, the Western Revolver is 3.16 studs long against the 1911's 1.30, and the Frontier Repeater 5.71.
  - In first person the revolver covered the centre-right of the screen, the Butterfly blade ran off the top, and the hand was pushed off-screen.
  - Other players saw the same giant Tool (Player1 measured Player2's revolver at 3.16 studs).
  - The weapon also clipped through the camera in the ROUND WON frame.
- **Inspect (F):** the knife inspect plays and the arm follows the blade. The revolver inspect wasn't captured after the fix, because the key press went to an unfocused window. It needs a manual look.

### TEST ARMORY click-through: PASS (UI notes)

Real clicks in the panel:

| Action | Result |
| --- | --- |
| Open the panel | 125,000 test coins; Service 1911 and Basic Knife selected |
| Buy Western Revolver | 125,000 → 122,500 |
| Equip it | SELECTED |
| Crate: Trail Bowie | new, -10 |
| Crate: Karambit | new, -10 |
| Crate: duplicate Trail Bowie | refunded, net 0 |
| Crate: Butterfly Knife | new, -10 |
| Crate: duplicate Karambit | refunded, net 0 |
| Accidental click on Frontier Repeater | 122,470 → 22,470 (exactly 100,000) |
| Equip Butterfly Knife | SELECTED |

- The server snapshot matched the panel: 22,470 coins, the same owned list and selection.
- These were refused, with no coins charged: a replayed request id ("Old request ignored"), a NaN id, an unknown item, buying a crate-only knife, and equipping an unowned Python.
- Entering practice gave the selected Tools with ArmoryId set. They have 0 anchored and 0 colliding parts, and ammo was 1.

UI issues (not fixed; they need a design decision):
1. The armory panel sits over the PLAY GAME button, and the lobby hotbar stays visible. It doesn't use MenuController, so other menus can open on top of it.
2. The Roblox backpack hotbar still says "Service1911" / "Karambit" whatever weapon is chosen, because the Tool names are kept for combat.
3. The revolver's loose `SingleCartridge` part (used by the reload track) is authored about 0.8 studs beside the gun, so it floats visibly next to the hand. This is in the prototype too; scaling kept the same proportions.

## Fix applied (Studio + this branch)

1. **ArmoryTools scaled** with `weapons/integration/scale_armory_tools.luau`, using Model:ScaleTo so joints, Grip and Muzzle stay aligned. Each Tool has attribute `ViewScale`.

   | Weapon | Before (longest side) | After | Factor |
   | --- | --- | --- | --- |
   | Western Revolver | 3.16 | 1.51 | ×0.475 |
   | Heavy Eagle | 2.68 | 1.46 | ×0.542 |
   | Python Magnum | 3.57 | 1.61 | ×0.448 |
   | Frontier Repeater | 5.71 | 2.91 | ×0.508 |
   | Basic Knife | 1.85 | 1.16 | ×0.623 |
   | Butterfly Knife | 2.46 | 1.36 | ×0.550 |
   | Machete | 2.91 | 1.90 | ×0.654 |
   | Trail Bowie | 3.08 | 1.60 | ×0.519 |

   All Motor6Ds stayed connected.
2. **`feel/ViewmodelController.luau`:** ArmoryAnimator joint translations are multiplied by the Tool's `ViewScale`, so slide, cylinder and lever travel keeps the right proportion. Studio's copy is 16,668 bytes, identical to this branch.
3. **Rechecked in solo Play:** the revolver in practice is 1.51 studs on the server Tool too, so other players now see the right size. The viewmodel looks proportionate in the hand, next to the arms.
   - **Not yet rechecked after the fix:** the other six weapons in first person, the inspect and fire animations on scaled rigs, and a second two-client match.

## Still untested / limits

- **Real devices:** touch and gamepad, small screens, and low-end hardware.
- **Network:** packet loss and jitter (only a constant 200 ms incoming lag was simulated).
- **Weapon animations after the scale fix:** the Heavy Eagle, Python, Repeater, Machete, Trail Bowie and Basic Knife haven't been viewed in first person; the inspect and fire animations haven't been viewed on scaled rigs; and the revolver's lever and cylinder articulation is still not shown to other players (a known limit).
- **Economy:** session-only by design. Coins and ownership reset when Play stops and never touch saved profiles.

Screenshots (`playtest_screenshots/`): `before_revolver_oversized.jpg`, `before_butterfly_oversized.jpg`, `after_revolver_scaled.jpg`, `test_armory_panel.jpg`.
