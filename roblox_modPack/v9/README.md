# roblox_modPack v9 — Particle / Impact Rebuild

## NEW loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v9/start.lua"))()
```

Version 9 is a **new folder and new entrypoint**, not another update to v8's old URL. Close Roblox or stop prior sessions before trying a new version.

## Rebuilt in v9

**Falling snow:** No old giant white balls. A dedicated local module creates small, six-arm microcrystals from three thin crossing bars for the foreground, plus GPU-native low-opacity sprites for distant wind-driven snow. Native emitters use Roblox built-in particle resources; visual appearance depends on what the client supports.

**Contact-based landing:** The camera samples actual visible surfaces across its view, including rooftops and distant platforms. Foreground flakes integrate wind, air resistance and falling velocity at a **target 90 fixed physics steps/second** and use swept `Workspace:Raycast` checks to determine collisions. Impact positions are not simply spawned as fake decals.

**Powder/snowbanks:** On verified contacts, a short powder burst is emitted. Snow mass is stored in a bounded local cell map. Each cell draws four small, irregularly offset `WedgePart` grains (not circular plates), growing slowly and melting according to its mass, weather and sun. Visuals are client-local approximations, not real Terrain voxels or fluid/thermal engineering. Max 126 snow cells (504 wedge grains). Distant snow impacts are counted.

**Rain:** Replaces ball-shaped splash effects with narrow, short-lived water strands and native soft mist on real rain hit positions. One bounded pool of 96 water splashes is reused. Sound plays locally if Roblox permits the included audio asset; storm sound is optional.

**Wet surfaces:** v9 keeps local material/specular adjustments but removes 3D circular puddle lenses. Actual scene-ray reflections remain a separate experimental option, OFF by default (F11).

**GUI:** Restrained graphite v9 panel for rain/snow percentages, quality (ECO/BALANCED/ULTRA), actual 90 Hz target vs measured rate, accumulated snow, distant hits, rain impacts, materials and optics. F10 opens the menu, F5 changes snow detail, F7 switches weather, F8 master mode, F11 experimental geometric reflections.

## Architecture

- `start.lua` — new revision-pinned v9 loader
- `core.lua` — 90 Hz rain/weather, 0 legacy snow spheres, 0 old debug UI
- `snow.lua` — six-arm near snow, native distant snowfall, wind, swept collisions, powder burst, 3D wedge-grain accumulation
- `rain.lua` — hit-linked water spray and ambient audio
- `surfaces.lua` — local wet floor and concrete material finishing, without round geometric puddles
- `reflect.lua` — optional 2-ray scene reflection samples (not native RTX)
- `ui.lua` — small modern options UI
- pinned legacy modules: weapon finish, first-person arms, camera lens, environmental light, optics and styles; **old v5/v8 snowfall/surface modules are NOT loaded**

## FPS + limitations

All weather is local. The program preallocates a maximum count of nearby particles, splash strands and snow grains, but a high setting still uses GPU/CPU resources. Physics rate 90 Hz is a fixed-step target, not a guarantee of 90 real FPS. The mod cannot force true GPU ray tracing, new textures on every foreign MeshPart, detailed Navier-Stokes fluid simulation, or changes to another experience's server physics.

One important distinction: the native background ParticleEmitter renders aesthetically pleasing flakes but its individual visual particles do not expose collision callbacks. A separate bounded set of tracked six-arm flakes performs real local swept raycasts and drives snow accumulation. This separation is deliberate for speed.

## Diagnostics

Core: F6, Rain/snow: use v9 UI. Optional via executor:
```lua
local rm=getgenv().roblox_modPack_v9
print(rm.Stats.SnowSimulationHz,rm.Stats.SnowImpacts,rm.Stats.SnowFarLandings,rm.Stats.Rain3DImpactHits)
```

The GitHub source, module references and API calls have been inspected. **No live Real Executor run has been performed**, so any Roblox permission or game-specific rendering errors should be collected from the executor console.
