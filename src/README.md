# Script snapshot

Every script in the Studio place, exported on 2026-10-30. Folders mirror the Roblox hierarchy (`ServerScriptService/Services/MatchService.luau` is `ServerScriptService.Services.MatchService`).

- `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
- Studio is the source of truth. This folder is for review and history. It is not wired to Rojo; `ServerScriptService/Init.server.luau` would need renaming before any Rojo setup, because Rojo treats `init` files specially.

See `docs/HANDOFF.md` for architecture and test results.
