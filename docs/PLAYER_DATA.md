# Player data and inventory (stage: 2026-10-30)

Server-owned player data (owned skins, equipped skins, room for progression) plus the Inventory screen for equipping skins. **Not published. No crates, purchases or currency.** Skins are cosmetic only.

## Pieces

| Where | What |
|---|---|
| `ServerScriptService.Data.DataConfig` | Store names, lock and retry timings, developer ids. |
| `ServerScriptService.Data.Schema` | Versioned data shape (v1), migrations, repair of wrong-typed fields. |
| `ServerScriptService.Data.ProfileStore` | Load/save of one record per player with a session lock. All reads and writes go through `UpdateAsync`. |
| `ServerScriptService.Data.MemoryStore` | In-memory stand-in for a DataStore, with simulated failures. Used by the tests, and in Studio when API access is off. |
| `ServerScriptService.Data.DataTests` | 16 automated checks of the above. Run with `print(require(game.ServerScriptService.Data.DataTests).Run())`. |
| `Services.DataService` | Runs ProfileStore for every player: load on join, save after changes, autosave, save and release on leave or shutdown. Sets the `DataStatus` attribute. |
| `Services.InventoryService` | Equip requests (`Remotes.Inventory`), server validation, per-player `Skin_<weapon>` attributes, and each owner's private inventory snapshot. |
| `Services.LoadoutService` (changed) | Gives each weapon in the player's equipped skin and tags the Tool with `SkinId`. |
| `Shared.Config.SkinCatalog` | The single catalog of weapons and skins. Ids are permanent; it holds appearance data only. |
| `Shared.SkinAppearance` | The only code that applies a skin. It changes Color and Material only, and is used by the server, the viewmodel and the previews. |
| `Controllers.InventoryController` | The Inventory screen. |
| `Controllers.ViewmodelController` (changed) | First-person weapon uses the Tool's `SkinId`. |
| `Controllers.LobbyHudController` (changed) | The INVENTORY tile now opens the screen, and the Profile "Equipped" rows show the real equipped skins. |

Backup taken before this stage: `ServerStorage.Backups.PrePlayerData_2026-10-30` (all services, Init, Shared, and StarterPlayerScripts; scripts disabled).

## Saved data (schema v1)

```text
key "u_<UserId>" -> {
  Data = {
    SchemaVersion = 1,
    Inventory   = { Skins = { [skinId] = true } },   -- owned; default skins are implied
    Equipped    = { [weaponId] = skinId },           -- no entry = default
    Progression = {},                                -- reserved
  },
  Lock = { Session = <server GUID + per-load sequence>, Time = os.time() } | nil,
  SavedAt, SaveCount,
}
```

The record also sets the player's UserId on the key, so Roblox data-deletion requests can find it.

## Store separation

- **Live servers** use the DataStore `OITC_PlayerData_v1`.
- **Studio** uses `OITC_PlayerData_STUDIO_v1`, so tests never touch live data.
- If Studio can't reach DataStores (right now "Enable Studio Access to API Services" is **off** for this game), Studio uses an in-memory store and prints a warning. That data is lost when the test stops.

## Safety rules

1. **Session lock.** Loading takes the lock in the same `UpdateAsync` that reads the data.
   - If another live server holds the lock, this server retries 6 times, 5 s apart.
   - After that it gives up (`Locked`) and writes nothing.
   - A lock older than 300 s counts as abandoned (for example a crashed server) and may be taken over.
2. **Saves only while holding the lock.** Each save checks inside `UpdateAsync` that this server still owns the lock.
   - If another server took over, the save is cancelled (`LostLock`) and this server stops saving that player (`SessionLost`).
3. **Failed loads never overwrite.** On `Failed`, `Locked`, `Incompatible` or `Corrupt`:
   - The player keeps playing with default skins, and equipping is refused with a clear message.
   - Nothing is saved for that player this session, including when they leave.
4. **Retries with backoff.**
   - Loads: 5 attempts. Saves: 4 attempts. Waits double each time (1, 2, 4, 8 s, at most 10 s).
   - A failed save keeps the data in memory for the next attempt.
5. **Versioned schema.**
   - Older versions are migrated step by step.
   - Data written by a newer version is refused and left untouched (`Incompatible`).
   - A record that isn't a table is left untouched (`Corrupt`).
   - Unknown skin ids are kept, so a retired skin can return.
6. **When saves happen:**
   - 5 s after a change (quick changes are batched into one write);
   - every 60 s (this also refreshes the lock);
   - on leave (save, then release the lock);
   - at shutdown (`BindToClose`, all players in parallel, up to 25 s).
7. **Clients never write data.** The only client message is an equip request containing ids.

## Developer test grants

`DataService.DevGrantSkin(player, skinId)` and `DevRevokeSkin` are server-only functions; no remote reaches them.

- In Studio they always work, because Studio uses its own store.
- In live servers they are off. They would need `DataConfig.AllowLiveDevGrants = true` and a UserId listed in `DeveloperUserIds` (currently the game creator).
- Studio-only test hook: `ServerStorage.DataTestHook` (a BindableFunction, created only in Studio). Test scripts can't reach the running DataService through `require`, so they use this hook to grant, rejoin, inject failures and inspect the store.

## Equip rules (InventoryService)

The client sends `("Equip", requestId, weaponId, skinId)`. The server accepts only when all of these hold:

- the request is well formed and at least 0.25 s after the previous one;
- the player's data is `Ready`;
- the weapon is known;
- the skin is known and enabled;
- the skin is made for that weapon;
- the player owns it (default skins are free);
- the player is in the lobby (not in a match or practice).

The reply is `("EquipResult", requestId, ok, reason)`; the screen ignores replies to older requests. Equipped choices are saved and used from the player's next loadout (match round or practice entry).

## Skins

The current finishes are plain colour and material proofs on the existing weapon models. Final textured finishes are a later art task.

| Weapon | Skins |
|---|---|
| Service 1911 | Factory (default), Slate, Desert, Crimson |
| Karambit | Factory (default), Forest, Ember, Ivory |

A skin can never change damage, ammo, range, cooldowns, hitboxes, size or muzzle position: `SkinAppearance` only writes `Color` and `Material`. The Tool, its scripts and the combat code are unchanged.

## Inventory screen

Choose a weapon, then a skin: only skins you own are shown, plus the default. Selecting a skin shows a turning preview with a "Previewing - not equipped" label. Pressing **EQUIP** shows "Equipping..." until the server replies, then "Equipped" or the server's reason. Selecting a skin never equips it by itself.

The screen also shows:
- "Loading your inventory..." while data loads;
- a clear "couldn't be loaded" message if the load failed (equipping is then disabled);
- a note that equipped skins are used from the next match or practice visit.

Controller B closes the screen, like the other menus.

## Test results

### Automated (`DataTests`, MemoryStore with a fake clock): 16/16 pass in the Luau CLI review harness; Studio rerun pending

- A new player gets the defaults and takes the lock.
- A save persists the data and refreshes the lock.
- Leave releases the lock; a rejoin on another server gets the saved data.
- Competing session:
  - a second server waits, then gives up with nothing written;
  - if the first server releases while the second is waiting, the second picks the data up.
- A stale lock (crashed server) is taken over, and the old server's later save is refused (`LostLock`) without overwriting.
- Failed load (store down): nothing is written, existing data is intact, and the data loads once the store recovers.
- Transient errors: the load succeeds after retries with the expected backoff (1 + 2 s).
- A save failure keeps the profile active and the old record intact; a later save succeeds.
- Newer-schema data and unreadable records are refused and left untouched.
- Schema repair keeps valid entries and drops wrong types.
- A second load on the same server waits for the existing acquisition; it cannot reuse that handle's lock.
- A late save/release from an old same-server acquisition cannot overwrite or release a newer acquisition.
- A load whose commit succeeded but whose response was lost safely retries its own acquisition token.
- Missing data payloads and malformed lock/version/save-count envelopes are refused without writes.

### Previously reported live play tests in Studio (before the review fixes; in-memory store, real DataService and remotes)

| Check | Result |
|---|---|
| Load on join | `Ready`, new profile |
| Dev grants (Slate, Ember) | granted |
| Equip: an unowned skin, a skin for the wrong weapon, an injected asset id, an unknown weapon | all rejected with the right reason |
| Equip owned skins; equip the already-equipped skin | accepted; no change for the second |
| Second request inside the cooldown; malformed request; oversize ids | "Too fast"; ignored; "Invalid request" |
| Saved 5 s after the change | record updated, lock refreshed |
| Competing server load while this server holds the lock | `Locked`, record unchanged |
| Leave, then rejoin | lock released; equipped and owned skins restored |
| Store down during join | `Failed` after about 15 s of retries; grants refused; client equip refused with "Saved data is unavailable"; stored record unchanged; leaving afterwards wrote nothing |
| Two errors, then the store recovers | `Ready` with data intact |
| Stored data marked SchemaVersion 2 | `Incompatible`, record untouched |
| Enter practice after equipping | Tools carry `SkinId` (slate / ember) with the right colours on the server; the client viewmodel shows the same colours; ammo still 1 |
| Equip while in practice | rejected ("Return to the lobby to change skins") |

### Not run yet

- **Real DataStore**: needs "Enable Studio Access to API Services". A real rejoin across separate play sessions is still untested. All data logic was exercised against the in-memory store.
- **Inventory screen visuals:** no screenshots, and the flow wasn't clicked through. Equip was tested through the real remote, but I lost the connection to the Studio computer before UI screenshots.
- **Entering a real match with skins:** a match round uses the same LoadoutService path as practice, which passed, but a 2-client match with skins was not run.
- **Two real servers competing:** simulated with a second session object on the same store (unit and live). Real cross-server behaviour needs published or real-DataStore testing.
- **Platforms:** touch and gamepad on real devices, and small screens.

## Known limitations

- After a load fails (`Failed` / `Locked` / `Incompatible`), the session uses default skins and saves nothing. The player has to rejoin to try again; there is no in-session retry.
- A crashed server's lock blocks that player for up to 5 minutes. They load with defaults and the "couldn't be loaded" message until the lock goes stale and they rejoin.
- Other players see your equipped skin on your Tool; the `Skin_<weapon>` attributes are public. Your owned list is sent only to you.
- The skins are colour proofs, not final art.

## Follow-up code review

See `docs/PLAYER_DATA_REVIEW.md` for the fixes, mock-service regression results and required Studio checklist. Each load now has a unique acquisition token. The GUID returned by `DataService.Test.SessionId()` is only the server prefix; inspect `Peek` for the exact stored lock token. Restart the Studio server after installing the module updates. No production store or schema version changed.
