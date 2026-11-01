# Permanent armory candidate

Built separately while Claude tests Studio. **Not installed, not published, and not connected to live player data.** This is a tested persistence/domain layer plus an integration adapter, not a completed production shop deployment.

## What it adds

- Schema version 2 with permanent coins, weapon ownership, selected firearm/knife, replay receipts and trusted credit cursors.
- Atomic full-profile saves: the coin deduction, ownership, equip selection and transaction receipt share one existing profile record/session lock.
- Server-owned prices and crate RNG; the remote request contains only a sequence, action and item/crate ID.
- Durable request replay detection across rejoins. A bounded 32-receipt cache retains results; a permanent high-water sequence prevents old evicted requests from executing again.
- Pending-save recovery. An ambiguous save acknowledgement does not expose provisional rewards or permit more spending. Retry saves the same snapshot and crate roll.
- Failed loads, corrupt balances and newer schemas fail closed. Existing skins, skin equipment, progression and unrelated valid fields are preserved.
- One owner adapter for legacy skin writes, armory transactions and autosaves. It must replace direct mutations of that profile; running it alongside an independent writer is unsupported.

New accounts receive zero coins, Service1911 and BasicKnife. Migrated version-1 accounts also retain their existing default Karambit access. The Studio session's 125,000 test coins are never imported. Existing unrecognized currency fields are preserved in place but are not converted into spendable coins without an audited migration rule.

Draft firearm prices: Western Revolver 2,500; Heavy Eagle 7,000; Python 10,000; Repeater 100,000. The development blade crate costs 10 with four equal 25% buckets; duplicate drops have zero net cost. **The crate remains Studio-only.** No paid-crate purchase, Robux receipt flow, monetization, live crate enablement or automatic coin earning is implemented. Earning rates still need a design decision.

## Files

- `Schema.luau`: versioned migration and corruption checks.
- `Catalog.luau`: draft prices, valid items, crate contents and credit sources.
- `Transactions.luau`: pure purchases, equip, rolls, receipts and server-only credits.
- `Coordinator.luau`: serial durable saves and pending/replay recovery over an existing locked ProfileStore profile.
- `OwnerAdapter.luau`: candidate seam for the existing DataService's ownership/publishing loop.
- `RequestRouter.luau`: validated, rate-limited transport adapter. No credit/grant remote exists.
- `studio/PersistentArmoryCandidate.rbxmx`: six inert ModuleScripts for review. No Script/LocalScript automatically runs; importing it alone does not integrate persistence.
- `INTEGRATION.md`: concrete integration plan and client protocol.
- `tests/run.luau`: domain, failure, session-lock and adapter checks.
- `tests/generated/`: frozen copies of the existing save modules, with import paths adapted for the CLI, plus candidate schema. The MemoryStore scheduler call becomes an injected test hook. No business logic is translated into another language.

## Validation performed

Executed with the official pinned Luau 0.745 Windows CLI. The download helper verifies the release digest when present and records source/digest locally. Executables are excluded from GitHub and the handoff ZIP.

**45 distinct checks passed:** 13 existing persistence/session-lock cases plus 32 new cases. The printed armory count is 33 because its first wrapper runs the 13 existing cases. The randomized case executes 250 transactions and replays each request, checking currency conservation, ownership monotonicity, receipt consistency and no extra save/RNG calls on replay.

Covered migration, unchanged input records, corrupt and newer records, purchases, insufficient funds, replay after rejoin, sequence conflicts, evicted receipts, unowned equip, all crate buckets, duplicates, fake client prices/context, disabled live crates, failed saves, acknowledgement lost after commit, crash recovery, stale locks, overlapping requests, yielding/throwing callbacks, legacy skin preservation, trusted credit replay/overflow, router behavior and adapter notifications. All six source modules also passed Luau compilation.

The failures are simulated with the existing MemoryStore/ProfileStore logic and an injectable scheduler. Actual Roblox DataStore throttling, network behavior, budget/load, live session transitions and UI integration are not verified by these offline tests. They need a separate staging integration. Nothing about these tests establishes smooth gameplay.

## Run locally on Windows

From this folder, with Python and network access for the first tool download:

```powershell
python tools/get_luau.py
& tools/luau-0.745/luau.exe tests/run.luau
python tools/build_studio_modules.py
```

`tools/prepare_tests.py` refreshes the frozen existing-module copies only when the original workspace's `ServerScriptService/Data` files are available. The committed fixture copies allow tests to run from the repository without that workspace. `tests/generated/sources.json` records the original file hashes.

See `TEST_RESULTS.txt` for the executed output. Existing Studio/server scripts were read only; all writes stayed inside this candidate artifact directory.
