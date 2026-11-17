# roblox_modPack v7 — geometric reflection prototype

This release adds **real scene ray queries** to the existing v6 local weather/material system. It does **not** add native GPU RTX, path tracing, actual per-pixel SSR, or access to Roblox's renderer internals.

## New v7 loadstring (Real Executor only)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v7/start.lua"))()
```

The loader fetches the v6 base and v7 ray reflection module from **fixed Git commits**. All old v6 effects remain available.

## What the reflection module computes

For each sample in the lower viewport:
1. The actual Roblox camera creates a viewing ray via `ViewportPointToRay`.
2. `Workspace:Raycast` finds the first visible floor/roof hit.
3. The reflected direction is calculated by the mirror law `R = D - 2(D·N)N`, with a tiny optional microfacet roughness offset.
4. A second `Workspace:Raycast` finds an object that would appear in that reflection.
5. The object's actual Roblox part color (or Terrain material color) is projected as a **thin, transparent, local colored ground sample** at that first hit.
6. Ray budgets and sample pools limit overhead. Unresolved rays do not produce fake color.

This gives **scene-dependent, camera-dependent raycast reflections**. The projection is a deliberately low-resolution approximation: it cannot sample the renderer's final pixels, texture maps, shadows, objects behind non-queryable geometry, skybox imagery, or accurate light transport. It may look speckled and will not resemble high-resolution RTX in most games. The module can also be invisible if reflection rays hit nothing.

## Controls and performance

- **F11** — raycast reflections ON/OFF.
- **F12** — quality ECO / BALANCED / DETAIL.
- **F7** — existing weather (choose RAIN to see wet-floor reflections).
- **F10** — existing v6 menu.
- **F8** — existing master effects ON/OFF.

Quality levels use 10×5, 16×8, or 22×10 ground samples, with at most 7, 12, or 19 sample updates per rendered frame respectively. Each sample needs up to two raycasts. The 90 Hz **weather physics** target remains separate; reflection sample updates run as a bounded per-frame budget and are **not** guaranteed to refresh at 90 Hz.

## Debug

After starting, a v7 status line appears in the client log. In an executor that exposes `getgenv`, live stats can be read using:

```lua
local rm = getgenv().roblox_modPack_v7
print(rm and rm.Stats.ReflectionRaysPerSec, rm and rm.Stats.ReflectionHitsPerSec)
```

If there are zero successful second-ray hits, no reflected scene colors can be drawn. Try RAIN mode while looking toward a wet floor with nearby tall colorful objects or walls.

## Limitations

Everything is client-side and visually approximate; it never modifies server physics, damage, aiming or other players. It doesn't bypass anticheat or install native GPU shaders. Material changes from v6 can be overwritten by the experience's own scripts. The v7 Lua files have been checked on GitHub for presence and pinned loading, **not run inside Roblox/Real Executor**, so runtime compatibility and FPS are not guaranteed.
