# NovaX v1.0 | Klaus (Dev) · Nexus (Bug Fixer)

NovaX is a modular continuation of the **complete uploaded 7,466-line NovaPremiumUI + main template**. It preserves the original feature core, does not replace it with a small mockup, and adds safer two-mode Silent Aim and a separate performance-aware weather system.

## NEW Loader for Real Executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/novax/v1/start.lua"))()
```

You need an executor that supports `game:HttpGet`, `loadstring`, and ideally `getgenv`. GitHub modules load from an **immutable revision** embedded in the start file. The public `main` URL is only the entrypoint.

## Modules

| Module | Responsibility |
| --- | --- |
| `start.lua` | Stops prior instance, cleans old ModPack UI, loads fixed modules and reports errors |
| `ui/NovaPremiumUI.lua` | Preserved full premium GUI library, restyled charcoal/slate |
| `core/legacy.lua` | Original AimLock, AutoAim, RageBot, Trigger, ESP, movement, config, spoofing, utilities + revised two-mode Silent Aim |
| `modules/weather.lua` | v9 snow/rain + camera wetness + material optics, 90Hz fixed-step weather, adaptive FPS throttle |
| `modules/gui_extensions.lua` | Adds Weather and Compatibility tabs to the **same** NovaPremiumUI window |
| `modules/capabilities.lua` | Reports engine/executor API availability without executing privileged test calls |
| `verify.lua` | Optional compile-only test for all five modules |
| `AUDIT.md` | Detailed functionality, capability and limitation audit |

## Silent Aim modes

- **Snap:** during manual mouse shooting, locally aims the visible camera at the nearest valid opponent inside the configured screen FOV. It does not force arbitrary `FireServer` calls.
- **Hook (Internal):** experimental client `Workspace:Raycast` hook, active only for a short period around a manual shot, with caller and camera-origin checks. It is loaded only if `hookmetamethod`, `newcclosure`, `getnamecallmethod`, and `checkcaller` exist. **No guarantee in other games.** Weapon systems that use other remote/server logic will not be intercepted.

Existing AimLock, AutoAim and RageBot remain separate and exclusive as in the supplied template. No hidden protection bypass or server-side bullet steering is claimed.

## Weather

The Weather tab starts **OFF** by default so the game doesn't suffer from a full-strength weather load on launch. Features:
- Rain and snow 1–100% independently.
- Snow crystals, native distant particles, wind drag, ray-swept collision checks, limited 3D snow grains, slow melting.
- Rain impact spray/mist, local audio, camera lens wetness and optional storm.
- Adaptive snow quality ECO / BALANCED / ULTRA to reduce visual load if measured FPS falls below thresholds.
- Target **90Hz fixed weather simulation updates**, with catch-up limits; not a guaranteed frame rate, not server Terrain deformation, and not RTX.

The old round-snow and round-water surface modules are not loaded together with the v9 weather bridge. The full old ModPack GUI is not loaded either.

## Controls

- **K** — toggle the original premium NovaX GUI.
- **Combat → Silent Aim → Mode** — Snap / Hook (Internal).
- **Weather** — choose weather and intensity, quality, visuals and sounds.
- **Compatibility** — see executable API availability and runtime weather counters.
- Some original hotkeys are editable in the original settings.

## Compilation smoke test (without starting features)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/novax/v1/verify.lua"))()
```

This reports per-module Luau compilation, but **does not test runtime behavior** or game-server hit registration. Real Executor test results and errors are still needed for a reliable gameplay verdict.

See [AUDIT.md](AUDIT.md) for confirmed code presence vs functionality not yet demonstrated. Some original template state switches (notably `NoSpread`, `HitboxExpander`, and `Wallbang`) should **not** be treated as confirmed working features.

Restart Roblox between major older ModPack/NovaX versions if duplicate executor hooks cannot be cleanly removed.
