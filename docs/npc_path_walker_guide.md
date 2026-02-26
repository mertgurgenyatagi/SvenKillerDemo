# NPC Path Walker — Implementation Guide

This guide covers the full pattern for adding a pedestrian NPC that follows a smooth path
defined by marker nodes in a scene. The proof-of-concept was `NPCTexterWalker` (texter
walker on the sidewalk in `street_prototype.tscn`).

---

## Overview

The system has three parts:

1. **Marker nodes** — `Node3D` children placed in the scene editor that define the path.
2. **NPC script** — builds a `Curve3D` at runtime from those markers, spawns the character
   model, plays a looping walk animation, and moves the NPC along the curve with ping-pong
   at each end.
3. **NPC node** — a bare `Node3D` in the scene with the script attached.

---

## Step 1 — Place Marker Nodes

Under the scene root, create a hierarchy:

```
SceneRoot
└── WalkPaths
    └── PathSomeNPC        ← Node3D, name matches the script's get_node call
        ├── WP0            ← Node3D (or CSGSphere3D for visibility)
        ├── WP1
        ├── WP2
        └── ...            ← at least 2, order defines curve direction
```

The markers are sampled in child order, so place them sequentially along the desired path.
`CSGSphere3D` nodes work well in the editor (visible, no physics cost when disabled).

---

## Step 2 — Prepare the FBX Asset

Use a **single combined FBX** that contains the skeleton, mesh, and walk animation together.
Export from Mixamo with the **"In Place"** option checked — but note that Godot may still
import residual XZ root motion (see Step 4).

Place the file under `assets/npc_assets/` (or any consistent path).

**Godot import settings for the FBX:**
- `animation/import = true`
- Leave everything else at defaults.

---

## Step 3 — Create the NPC Script

Copy `scripts/npc/npc_texter_walker.gd` and rename it for the new NPC.
Change the two constants at the top:

```gdscript
const _CHAR_SCENE: PackedScene = preload("res://assets/npc_assets/YOUR_NPC.fbx")
```

Change the path in `_build_curve()` to match the new marker root:

```gdscript
var marker_root: Node3D = scene_root.get_node_or_null(
        "WalkPaths/PathSomeNPC") as Node3D
```

Tune the exports in the Inspector:

| Export | Default | Notes |
|--------|---------|-------|
| `walk_speed` | `1.0` | metres/second; 1.0–1.4 for pedestrians |
| `rotation_smooth` | `10.0` | higher = snappier turns |
| `facing_offset_deg` | `180.0` | set to 180 for Mixamo (+Z-forward meshes) |

---

## Step 4 — Root Motion Stripping (Critical)

Even when "In Place" is checked on Mixamo, Godot often imports XZ translation baked into
`TYPE_POSITION_3D` tracks on the root or hips bone. This causes the character to
self-propel and snap back at the end of each loop.

The script handles this automatically in `_strip_root_motion()`:

```gdscript
func _strip_root_motion(anim: Animation) -> void:
    for i in range(anim.get_track_count()):
        if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
            continue
        for k in range(anim.track_get_key_count(i)):
            var pos: Vector3 = anim.track_get_key_value(i, k)
            anim.track_set_key_value(i, k, Vector3(0.0, pos.y, 0.0))
```

Y is preserved so the natural hip-bob of the walk cycle is kept.

---

## Step 5 — Animation Clip Selection

Mixamo FBX files import with a default animation library (`""`) that always contains:
- `"Take 001"` — the bind/rest pose. **Must be skipped.**
- `"RESET"` — another pose track. **Must be skipped.**
- `"mixamo_com"` — the actual motion clip (or whatever name Mixamo assigned).

`_find_walk_anim_name()` skips the known pose clips and prefers any clip whose name
contains `"walk"` (case-insensitive). If no "walk" clip is found it falls back to the
first non-pose clip. For non-walk animations rename the search string accordingly.

Loop mode must be forced at runtime:

```gdscript
anim_res.loop_mode = Animation.LOOP_LINEAR
```

Mixamo imports default to `LOOP_NONE`.

---

## Step 6 — Add the NPC Node to the Scene

Add a plain `Node3D` as a direct child of the scene root. Set its script to the new
`.gd` file. The node needs no children — the character model is instantiated in `_ready()`.

```
SceneRoot
├── WalkPaths/...
└── NPCSomeName    ← Node3D with npc_some_name.gd attached
```

Because `_build_curve()` calls `get_parent()` to reach the scene root, the NPC node
**must be a direct child of the scene root** (not nested inside another node).

---

## Facing Direction

`Basis.looking_at(fwd, Vector3.UP, false)` aligns local **-Z** to the forward direction.
Mixamo characters face local **+Z**, so they will appear to walk backward. Fix by setting
`facing_offset_deg = 180.0` in the Inspector (this is the default in the script).

If a different character faces -Z (standard Godot convention), set `facing_offset_deg = 0`.

---

## Multiple NPCs of the Same Type

To have several instances of the same NPC type walking different paths:

1. Duplicate the path markers under a new name (e.g., `PathTexterWalkerB`).
2. Create a second NPC node with the same script.
3. Override `_build_curve()` to look up the new path, or add a `@export var path_name: String`
   so it can be set per-instance from the Inspector.

---

## Key Files

| File | Purpose |
|------|---------|
| `scripts/npc/npc_texter_walker.gd` | Reference implementation (texter walker) |
| `assets/npc_assets/npc_walker_texter.fbx` | Reference FBX (mesh + skeleton + animation) |
| `scenes/street_prototype.tscn` | Contains `WalkPaths/PathTexterWalker` marker set |
