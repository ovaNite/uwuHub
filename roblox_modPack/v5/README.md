# roblox_modPack / Realism v5.3 — First-person wetness hotfix

## Start
Paste in an executor that provides `game:HttpGet` and `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v5/load.lua"))()
```

## What this patch fixes
- **No full-avatar soaking.** `body.lua` now only examines visible arms in first person and the current player's equipped tool / suitable camera-parented first-person viewmodel. It explicitly excludes torso, head, legs, accessories and other players. Rain beads are tiny (.015–.034 studs); snow specks are tiny (.026–.049 studs).
- **Rain on camera.** `lens.lua` provides up to 20 small translucent, rounded, slowly sliding lens droplets. Rain appears only outdoors when local upward raycasts don't detect overhead cover. An exclusion ellipse keeps the central crosshair/optics area clear. This is a subtle GUI optical approximation, not GPU light refraction.
- **No huge white eggs.** The base physics no longer renders duplicate snow/puddle geometry, and the organic `surface.lua` mounds have been reduced to low, narrow, semi-translucent contours. Snow still accumulates and melts as mass increases.
- **Redesigned interface.** `ui.lua` now uses a compact, draggable graphite panel with unobtrusive navigation, subtle hover transitions, adjustable weather intensity and profile styles, local sound, user background via Roblox image asset ID, corner radius, transparency and key remaps. No fake image previews and no overriding game-specific HUD.
- **90Hz fixed physics target**, as in v5.2. Measured rate may be lower under CPU/GPU load; client physics remains separate from server physics.

## Controls
- F10 menu, F7 rain/snow/off, F8 enable/disable, F9 strength, F6 core diagnostic.
- Weather tab: Rain/Snow/Clear/Storm, 1–100% per-weather strength, camera lens toggle.
- Graphics tab: Realism, Anime, Hello Kitty, Star Wars, WW2, Russia, Walter White, Galaxy, CS2, Sophy Rain, Kung Fu Panda, Stalin, Gewitter, Bright. These are local post-processing mood profiles, **not** full renderer/shader replacements or copyrighted visual designs.
- Sound tab: weather sound on/off, rain volume and local Roblox-audio player.
- Interface tab: corner radius, background transparency, image asset ID, editable keybinds.

## Modules
The loader fetches *revision-pinned* `dist/*.lua` files. Readable code is in `core.lua`, `body.lua`, `lens.lua`, `surface.lua`, `weatherfx.lua`, `styles.lua`, `optics.lua`, `worldfx.lua`, and `ui.lua`. Packed files are **reversibly encoded and checked**, not encrypted or secure against reverse engineering.

## Technical notes
- All effects are local and visual only; they cannot modify other players' weather, weapon ballistics, map geometry, or server physics. Game-made custom camera rigs may use different part names; no universal viewmodel detector exists.
- The camera drops do not refract the real 3D render pipeline, and cannot create native GPU shaders.
- Ambient and impact sounds require Roblox-allowed audio IDs and may be blocked by an experience.
- This revision was checked for coherent package contents, checksum integrity and GitHub retrieval; there is no live Real Executor execution test.
