# VTR 25 — Roblox UI Design System

A Rojo-ready, code-native football esports interface for **VTR 25 (Voltra)**.

## Run

1. Run `aftman install` (the project pins Rojo in `aftman.toml`), or install Rojo manually.
2. Open a blank Roblox place in Studio.
3. From this folder, run `rojo serve`.
4. Connect with the Rojo Studio plugin and press Play.

The interface is generated entirely from Luau, so no uploaded image assets are required.

## Structure

- `src/shared/Theme.lua` — colors, typography, spacing, motion, and responsive breakpoints.
- `src/client/Components.lua` — reusable UI primitives and premium sports components.
- `src/client/App.client.lua` — responsive shell, navigation, screen composition, and animation.

Edit the tokens in `Theme.lua` to reskin the whole product.
