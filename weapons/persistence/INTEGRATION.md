# Integration handoff for Claude

Do this after the current gameplay tests, using the latest Studio/DataService code rather than blindly replacing scripts. This candidate has not touched Studio. Keep a backup and use staging player data first.

## Single data owner is mandatory

The installed DataService currently owns the locked ProfileStore profile, queues saves, and updates skins in memory. Do **not** start another DataStore/ProfileStore writer or acquire a second lock for the armory. Do not put currency into a separate key: it would permit partial charge/award commits.

1. Review and integrate the candidate Schema into canonical `ServerScriptService.Data.Schema`. Keep the existing store names and user-key format when actually migrating; changing only the schema version does not require moving player keys. First validate on staging copies. Version-1 readers refuse version-2 records, so coordinate rollout/rollback across versions rather than downgrading the record or overwriting it with defaults.
2. Keep one existing `profiles:Load(...)` per player. Only after it returns `Ok` with an active profile migrated to version 2, construct one `OwnerAdapter` using that same ProfileStore and profile. Do not fabricate an owner for Loading/Failed/Locked/Corrupt/Incompatible profiles.
3. Route **all** writes and saves for that profile through the owner. Replace the old direct `DataService.Update` mutation/save path with `adapter:Update(mutator)`, periodic save with `adapter:Save(false)`, and leave/shutdown release with `adapter:Save(true)`. Disable the old parallel save queue for coordinated profiles. No code may retain and mutate the raw profile.Data or save it independently.
4. Adapt legacy callers to explicit result codes. `Updated` means the mutation is durably acknowledged. `Pending` means saving is uncertain; it must not be displayed as either a completed award or a safely cancelled operation. `Busy` / `Unavailable` do not imply success. During Pending, only confirmed state may be read for UI/loadouts.
5. Use the existing DataService Changed publisher in `OwnerAdapter.Changed`. Reflect owner Status to the player's data-status UI. Schedule `adapter:RetryPending()` with bounded backoff when Pending, and publish the resulting Ready/SessionLost status. Keep old data visible while saving; block purchases/equips until resolved. A pending write is flushed before profile release. If recovery fails on shutdown, do not promise success; the next session reads whichever atomic snapshot actually committed.

## Server wiring example

Use the generated Studio sources (their require paths already target sibling ModuleScripts). Keep them server-side; clients only need a sanitized display catalog/snapshot, not Coordinator or schema internals.

```lua
-- Inside the existing DataService load-success branch. Schematic integration,
-- not a replacement for its latest lifecycle/error/PlayerRemoving handlers.
local rng = Random.new()
state.armoryOwner = OwnerAdapter.new({
    Profile = state.profile,
    ProfileStore = profiles,
    RandomIndex = function(count) return rng:NextInteger(1, count) end,
    Context = function()
        return {
            IsStudio = RunService:IsStudio(),
            InLobby = player:GetAttribute("Location") == "Lobby"
                and player:GetAttribute("MatchId") == nil
                and player:GetAttribute("InMatch") ~= true,
        }
    end,
    Changed = function(status)
        -- Publish through the existing DataService lifecycle safely.
        -- Do not expose the raw profile, pending roll, receipts or credit API.
        player:SetAttribute("DataStatus", status)
        changedEvent:Fire(player)
    end,
})
```

Context, random rolls, credit sources, prices and costs must never come from a client request. Domain callbacks are nonyielding; the coordinator closes a yielding domain/legacy mutation coroutine before it can stage a write. Only the persistence adapter may yield while saving, with all other mutations blocked.

`RequestRouter.new({GetOwner = function(player) return readyState.armoryOwner end, Now = os.clock})` accepts the adapter directly. Return nil for players without an owned active data session. Bind one reviewed RemoteFunction to `router:Handle(player, action, request)`; call `router:Forget(player)` on leave. There is no `Credit`, `Grant`, `SetCoins` or arbitrary mutator action in the router. Consider exception/logging boundaries in the outer service, without converting errors into purchase success.

Use confirmed `adapter:Snapshot().Selected` and the existing validated ArmoryTools mapping on the next loadout. Client attributes are not ownership proof. Validate asset availability before enabling each catalog entry. Keep a safe starter fallback if a tool asset is unavailable. This package does not replace the current world-effects or weapon controllers.

## Client protocol

- `Snapshot` returns Status, Coins, Owned, Selected, NextSequence and optional PendingSequence. No receipts or raw profile are replicated.
- For a player's new explicit action, send `Transact` with `{Sequence = snapshot.NextSequence, Action = "Buy" | "Equip" | "Crate", ItemId = exactCatalogId}`.
- Keep that same envelope when retrying after a timeout/Pending response. Never create a fresh sequence just to retry the same purchase/crate. Show the award/unbox reveal only after a durable `Purchased`/`Unboxed` result.
- A successful response includes the current confirmed Snapshot. Don't immediately issue an unnecessary second snapshot request; the router limits requests to one per second per player.
- On Busy/RateLimited, retry with backoff. On OutOfOrder/SequenceConflict/ExpiredRequest, refresh confirmed inventory and resynchronize. Do not automatically submit another crate as a new action. On SessionLost/Unavailable, disable mutations and use the existing safe data-unavailable flow.
- Duplicate crate rewards use zero net cost: the player already owns that item, so no extra debit/refund pair is necessary. The server saves the receipt so retrying cannot generate another roll.
- The existing DevArmory remote/controller uses a different request format and session balance. Keep it separate, or deliberately rewrite it and remove the old session route. Never credit its 125,000 test balance to the permanent wallet.

## Earnings are deliberately not wired

`adapter:Credit(source, eventNumber, amount)` is for trusted server code only. The source is allowlisted and requires a durable **ordered event number bound to one award**. A retry must reuse the exact event number, not allocate a new number from NextSequence/current balance. Out-of-order credits are refused so callers must reconcile their authoritative award queue. No distributed match-award/outbox implementation is supplied; do not wire match rewards until its durable event identity/order and earning amounts are decided. No live dev-grant remote should be added.

## Staging checklist

Verify the existing skin equip UI against Pending states; migration of real staging copies; failed load; buy then leave/rejoin; stale/competing sessions; repeated UI requests; disconnect immediately after a crate roll; pending retry/shutdown recovery; real DataStore latency/budget; and every selected asset on the next round. Keep the test crate disabled live. Coordinate final UI/round tests with the gameplay owner. Do not publish just by importing the candidate package.
