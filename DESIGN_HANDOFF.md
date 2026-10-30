# Profile and weapon-polish handoff

This is a design/documentation delivery, separate from Claude's shared-queue implementation. No `src/` script, match rule, working model, animation script, queue or save system is changed.

## For Claude after the Stage 3 checkpoint

1. Read `ui/PROFILE_HANDOFF.md` and use `ui/concepts/PlayerProfile.png` as the latest expanded profile reference. This replaces achievement/Revives-style stats and the earlier tabbed proposal. Show current selected pistol, knife and their skins; other items stay in Inventory.
2. Reuse the existing UI/menu owner and approved server-data layer. No live-looking fake statistics, balances or ownership. This package does not implement a profile GUI or statistics backend.
3. Read `weapons/QUALITY_CHECKLIST.md`, compare the ten prototypes with actual current Studio assets, and record specific evidence in `weapons/QUALITY_STATUS.md`. Do not start replacing all weapons because the files exist.
4. Read `weapons/concepts/PYTHON_PRODUCTION_BRIEF.md`. The user selected Eclipse (black and gold) first. Inspect its native-part material study via `weapons/skins/README.md`, then use the actual production mesh/UV workflow for final engraving. Existing concept art is not a ready UV texture.
5. Preserve tested systems/backups and report Studio screenshots, pass/fail/unrun checks and next task. Don't merge this design branch or publish automatically; review it through the existing Git workflow.

Current target: PC first, controller/mobile adaptability by design, dedicated physical console/mobile tests later. Do not falsely mark an untested platform supported. Do not interrupt the queue task to build all of this concurrently.

No Studio implementation, weapon visual polish, final Python texture or multiplayer validation is claimed by this handoff. Those need the actual running project and production assets.
