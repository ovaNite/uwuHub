# NovaX Games script repository

Put each Roblox experience into its own folder under `novax/scripts/`.

```
novax/scripts/
  index.json                # fallback manifest
  tsb/
    game.json                # title, place IDs, universe ID, script filename
    loader.lua               # per-experience entry point
    combos.lua               # optional editable combo definitions
    m1_engine.lua            # continuous M1 input + Info.BaseM1 monitor
  your-next-game/
    game.json
    loader.lua
```

**Discovery:** The Games workspace reads GitHub's public `contents/novax/scripts` API and loads each folder's `game.json`. Use **REFRESH**, or leave Games open for automatic polling. New folders with valid metadata appear automatically. `index.json` is a fallback when GitHub API calls are rate limited or blocked; update it if you need the fallback to list new folders too.

**Thumbnails:** A card automatically uses the Roblox GameIcon thumbnail from `universeId`. For custom Roblox-uploaded images you may set `"thumbnail": "rbxassetid://123456"`. GitHub-hosted PNG links are not supported as Roblox ImageLabel image assets.

**Entry point contract:** `loader.lua` may be a normal Luau script or may return `function(context) ... return { Stop = function(self) ... end } end`. `context.IsRunning()` becomes false when the user requests stop. Scripts run *inside* the existing executor's `loadstring` environment, not a separate secure Lua virtual machine. The UI does not auto-run newly found scripts.

**Important:** Upload scripts only from sources you trust. Code executed by `loadstring` gets the executor's privileges. Stop works fully only when the loader implements the `Stop()` contract and cooperatively ends its asynchronous tasks. Do not store secrets, passwords, GitHub tokens or private user data in publicly readable scripts.

**TSB:** The loader offers a manual Combo Studio, saved per-character recordings and a continuous M1 input controller (start/stop and rate controls). It scans `ReplicatedStorage.Info.BaseM1` to recognize the M1 animation group and step currently playing. These IDs specify animations, **not** hit distance, server damage, or combo limits. Repeated clicks do **not** remove the game's server-side 4-hit reset and do **not** grant unlimited attack range. Character-specific auto-combo timelines still require actual tested move data.
