# Player-data and inventory review

Reviewed Claude's `3df8955` checkpoint. Fixes are isolated on `review/player-data-inventory`; they do not include the map-revamp branch, new weapons, new catalog entries, purchases, or schema/store-name changes. Nothing was installed in Studio or published.

## Fixed findings

### P1: old same-server acquisitions could overwrite/release newer ones

`ProfileStore.Load` used one server GUID as the lock for every load. A second load in the same server therefore succeeded while an old handle still existed. A late cleanup/save from that old handle could write its older snapshot and clear the newer handle's lock. Ordinary completed leave/rejoin works; the risk is overlapping/delayed loads, failed releases, or stale same-server handles.

Fix: append a monotonic per-load sequence to the server GUID and store that exact acquisition token on the profile. Retries of one load reuse its token; another load gets a different token. Save/release checks the profile token, not just the server GUID. Rejoining the same server now waits for a still-active acquisition to release or expire rather than silently sharing it. Regression tests reproduce the old overwrite/release behavior and pass after the fix.

### P1: existing records with missing payloads could be replaced by defaults

An existing envelope without `Data` was treated like a new key, even if it retained save/lock metadata. Malformed version and lock fields could also be normalized or bypassed rather than refused. This is a damaged-record path, not evidence that current users lost data.

Fix: only a nil key means a new player. Require a table payload on existing records, finite positive integer versions (or the documented missing-version legacy shape), valid save counters and well-formed lock fields. Refuse invalid records as `Corrupt`, without writing. Existing repair behavior for supported payload fields remains unchanged.

### P2: a departed player could finish waiting and acquire a new profile

A load waiting for a prior leave-save did not check whether its player had left before creating its state. Removal during that wait could happen before a state existed, so the removal handler had nothing to clean up. The later load could remain active and get autosaved for a disconnected player.

Fix: check `player.Parent == Players` while waiting, before starting a load, and when it completes. Late load cleanup only releases its own acquisition. Mark unloading states closing so new mutations stop; overlapping shutdown/unload waits for the existing release.

### P2: dead/inactive match participants could change skins

`InMatch` intentionally means alive/armed, not membership in the match. During death, results and between rounds it can be false while `MatchId` remains present. The lobby-only equip gate checked armed state, allowing that match participant to equip.

Fix: also require no `MatchId`. Unavailable/closing profiles are rejected through `DataService.IsReady`.

### P2: malformed equip requests bypassed the cooldown and rejection replies were unbounded

Malformed weapon/skin arguments did not consume the equip cooldown. Every rate-limited request also generated a reply. This allowed needless validation/reply work even though ownership checks still prevented unauthorized equips.

Fix: malformed requests consume the same processing budget. Rate-limit rejection replies as well; extreme bursts may be dropped silently. A normal individual rejected request still gets its reason. No grant remote was added.

## Validation performed here

- **16/16 DataTests pass** using the official Luau CLI, actual Schema/ProfileStore/MemoryStore modules and a no-op `task.wait` adapter. Original non-race data scenarios remain covered.
- Deterministic coroutine harness runs the actual DataService and InventoryService with mocked Roblox services. It checks owned/unowned/wrong-weapon/practice/inactive-match equips; bounded replies for 1,000 malformed requests; leave while waiting for a prior release; leave during a held load response; mutation refusal while closing; rejoining with the saved selection; shutdown overlapping a leave-save.
- Regression checks run against original `3df8955` modules fail as expected for old acquisition reuse/cleanup, corrupt envelopes, closing mutations, and inactive-match equipping. Baseline failure switches are supplied for reproduction.
- All **43 Luau files** (42 under `src/` plus the service harness) compile with the official Luau compiler.
- Read-only review of the live `ViewmodelController`: firing/slash/draw poses are time-based, `hide()` clears animation/model state, and switching weapons rebuilds that state. Production inspect/reload/sprint/slide animation flows are not implemented in that controller; the separate weapon preview pack is not evidence of live integration. No visual animation pass was performed here.

Commands (pass a Luau executable path if it is installed elsewhere):

```bash
python tools/tests/run_data_review.py /tmp/oitc-luau/luau
python tools/tests/run_service_review.py /tmp/oitc-luau/luau
```

Expected-failure regression reproduction (these commands intentionally exit nonzero):

```bash
python tools/tests/run_data_review.py --baseline
python tools/tests/run_service_review.py --baseline=DataService
python tools/tests/run_service_review.py --baseline=InventoryService
```

The runners bundle the real modules without translating Luau into Python. Their engine, scheduler, datastore, clocks, remotes and material values are **test mocks**. They do not prove Roblox DataStore delivery, replication, UI visuals, real networking or Studio lifecycle behavior.

## Claude's Studio checklist

1. Fetch `review/player-data-inventory` and review this diff against `3df8955`. Back up the four changed Lua modules before installing: ProfileStore, DataTests, DataService, InventoryService. Restart the Studio test server after updating; don't hot-patch an active profile owner.
2. Run `DataTests.Run()` in Studio. Expect 16 passing tests. Record actual results separately from CLI results.
3. Repeat normal grant/equip/save/leave/rejoin using the isolated Studio store. In memory mode, inspect the exact lock token via Peek; the real adapter does not expose Peek. `Test.SessionId()` now returns only its server prefix. Before claiming real persistence, confirm StoreKind is `DataStore` and its name is `OITC_PlayerData_STUDIO_v1`. Do not change production keys or enable live grants.
4. Delay an old load/save response, disconnect, then rejoin on the same server. Check the old response cannot clear the new lock or roll back the new snapshot. Check a player who leaves while waiting never ends up Ready or holding the lock. Release failure can still require lock expiry; that existing limitation remains.
5. Test shutdown with saves pending. Confirm final allowed changes are retained, new changes are refused once closing starts, and locks release when writes succeed.
6. Use two clients with different owned skins. Test lobby equip, practice refusal, alive-match refusal and **dead/between-round/result-phase refusal**. Verify server Tool, local viewmodel and opponent-visible colors after each next-round loadout; confirm ammo and damage remain unchanged.
7. Test a short burst of malformed/spammed equips. Replies should stay bounded; ordinary UI operation and one-shot error feedback should still work after cooldown.
8. Finish the existing Inventory click-through/screenshots and real-DataStore tests when isolated Studio API access is available. Mocks do not close those pending items.
9. Visually check fire → switch, slash → switch, death mid-animation, practice exit and round respawn. Future inspect/reload integrations need their own interruption tests; don't mark them complete from this code review.
10. Update `docs/CHECKPOINT.md` with the imported commit, actual Studio results, unresolved issues and screenshots. Keep the game unpublished.
