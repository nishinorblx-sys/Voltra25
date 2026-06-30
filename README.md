# VTR 25 — Roblox UI Design System

A Rojo-ready, code-native football esports interface for **VTR 25 (Voltra)**.

## Run

1. Run `aftman install` (the project pins Rojo in `aftman.toml`), or install Rojo manually.
2. Open a blank Roblox place in Studio.
3. From this folder, run `rojo serve`.
4. Connect with the Rojo Studio plugin and press Play.

The interface is generated entirely from Luau, so no uploaded image assets are required.

## Architecture

- `src/shared` maps to `ReplicatedStorage/VTR/Shared` and contains the central
  theme, data configuration, and shared types.
- `src/client/Components` contains reusable buttons, panels, progress bars,
  stat cards, currency UI, and sidebar items.
- `src/client/Controllers` owns the persistent app shell, navigation, page
  transitions, responsive scaling, and controller focus.
- `src/client/Pages` contains the eight data-driven page modules.
- `src/client/Services` contains domain-specific, cached remote clients and
  notification subscriptions.
- `src/client/App.client.lua` is intentionally tiny and only starts the app.
- `src/server/Services` owns profile, currency, season, ranked, objective,
  fixture, and notification data. No client remote can mutate authoritative values.
- `src/server/MockProfileStore.lua` is an in-memory adapter with the same load,
  get, save, and release boundary expected from a future persistent adapter.
- `src/server/Bootstrap.server.lua` starts services and provides a safe fallback
  lobby for testing in an empty place.

Edit the tokens in `Theme.lua` to reskin the whole product.

The fallback lobby is only created when the place has no `SpawnLocation`, so it
will stay out of the way when the UI is integrated into a real stadium or menu map.

## Gameplay prototype

`GameplayConfig.AutoStartTestMatch` is currently `false`, so VTR 25 starts in
the complete frontend hub framework. Set it to `true` only when intentionally
testing the dormant gameplay prototype.

- WASD: move
- Shift: sprint
- Left mouse: charge and shoot
- Right mouse: pass
- E: tackle
- Space: skill touch

The server owns possession, ball physics, stamina limits, goals, and scores. The
client only predicts the dribble visual and submits validated action intent.
