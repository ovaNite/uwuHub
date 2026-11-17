# roblox_modPack v6 / realistic client graphics

## Important
Version 6 has its **own new loadstring path**, `/v6/start.lua`. It does not use the old `/v5/load.lua` entrypoint.

### Improvements
- The **old Realism v4 overlay is suppressed** inside the v6 core; the start script stops previous v4/v5/v6 sessions and removes stale ModPack-only GUIs.
- 90-Hz fixed-step physics core for local weather; weather intensity controlled by the new v6 UI.
- Rain hits drive rounded temporary puddle lenses while floor materials gain modest local shine and environmental specular light. This isn't SSR, ray tracing, or actual reflections of the surrounding geometry.
- Static neutral-colored walls can receive an underlying concrete material finish without replacing original developer-supplied decals or textures. Existing baked grey grids and custom MeshPart maps can remain visibly unchanged: new texture images need authorized asset IDs and material access.
- First-person weapon models: where named parts are accessible, certain barrels, sights and optics get reversible subtle metal/glass material properties; existing PBR SurfaceAppearance is preserved.
- New smaller, movable, dark UI for weather intensity, local material and optic settings, measured physics rate and counts of altered parts.
- Continues v5.3 modules for local body rain, snow deposition, rain sounds, weather, optics, camera lens and style profiles, using an immutable Git SHA.

### Run
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ovaNite/uwuHub/main/roblox_modPack/v6/start.lua"))()
```
Requires an executor supporting `game:HttpGet` and `loadstring`.

### Controls
F10 toggle v6 panel, F7 weather, F8 enable/disable, F9 core intensity cycle, F6 diagnostics. A clean Roblox client restart may be necessary if a previously injected script cannot be stopped.

### Safety and limitations
Everything is visual and **client-side only**. No changes to hitboxes, actual firing, damage, aim, replicated physics or other players. Material changes may be rejected or overwritten by game scripts. Rainwater, snow, camera wetness and gloss remain approximations within the Roblox renderer, not new GPU shaders. Some custom weapon meshes and textured walls cannot be retextured using arbitrary Luau.
When the loader runs, a pinned source code revision is downloaded, checked for expected source length and executed. Do not treat published Luau as unbreakable encryption.
The files and module references are checked statically, but they have **not** been tested live in Real Executor. Use the live console if a module reports a permissions error.
