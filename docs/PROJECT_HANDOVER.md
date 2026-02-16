# Sven Killer Demo — Complete Project Handover Document

**Date:** February 7, 2026
**Repository:** https://github.com/mertgurgenyatagi/SvenKillerDemo
**Current Branch:** massive-cleanup
**Engine:** Godot 4.6 (Forward Plus renderer)
**Primary Language:** GDScript 4.x (strict typing)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Development History](#development-history)
3. [Current Project State](#current-project-state)
4. [Technical Architecture](#technical-architecture)
5. [Asset Inventory](#asset-inventory)
6. [Git Workflow](#git-workflow)
7. [Key Design Decisions](#key-design-decisions)
8. [Pending Work & Next Steps](#pending-work--next-steps)
9. [Critical Context Notes](#critical-context-notes)

---

## Project Overview

### Original Vision (Pre-Pivot)

**Sven Killer Demo** was originally conceived as a 10-15 minute narrative-driven walking simulator built in Godot 4.6. The game followed Sven, a man in his late 20s/early 30s, who wakes in his Swedish townhouse, receives a mysterious voicemail from his mother, explores his house, walks through rain-soaked streets, and arrives at a bus station.

**Artistic Influences:**
- God of War 2018 (over-the-shoulder camera)
- Gaspar Noé's "I Stand Alone" (VHS effects, immersion-breaking prompts)
- Minimalist interactive fiction

**Narrative Style:**
- Swedish primary language, English subtitles
- 7 language subtitle support (Swedish, English, Spanish, Chinese, French, German, Turkish)
- Voiceover-driven storytelling
- Black-screen Noé prompts (2 instances with metallic sound)
- Audio-first design philosophy

**Planned Level Flow:**
1. Opening (Non-Playable): Black screen → custody voiceover → VHS videos → mission text → fade to gameplay
2. House Interior (Upper Floor): Wake on bed, explore, light switches, wardrobe, bathroom
3. House Interior (Ground Floor): Descent, streetlight ambiance, voicemail from mother, newspaper, couch
4. House Exit Cutscene: Door locks behind player
5. Street Walk (5-7 min): 72m walk to bus station, rain, pedestrians, cars, death mechanic (traffic = respawn)
6. Bus Station: Girl awaits (dialogue TBD)
7. Second Half + Ending: Content TBD

**Gameplay Mechanics (Original Plan):**
- WASD walk only (1.2 m/s fixed, no sprint/jump/crouch)
- Over-the-shoulder camera (God of War style, +0.20m X, +0.12m Y, -0.65m Z from neck, FOV ~70°)
- E key interaction raycast (doors, switches, seats, NPCs)
- Death mechanic: Step into traffic → black screen → respawn on pavement
- Surface-based footstep audio (5 surface types: concrete, carpet, tile, wood, stairs)

### Current Vision (Post-Pivot)

**CRITICAL: The God of War camera/gameplay plan has been COMPLETELY ABANDONED.**

The project is now pivoting toward a different movement system based on reverse-engineering analysis found in `docs/final_animation_guideline.txt`. This new direction uses a **turn-then-walk** locomotion model (like Rockstar games) instead of strafing/over-the-shoulder mechanics.

**New Movement Philosophy:**
- Character always faces movement direction
- S key = turn 180° then walk forward (not backpedal)
- A/D keys = turn 90° then walk forward (not strafe)
- W+A/D = 45° arc turn while walking
- Acceleration-based physics (0.4-0.6s ramp to 1.5 m/s)
- Camera pivot at ~1.6m (neck height), FOV 45-55° vertical
- Rotational damping: 0.1-0.2s lag for weighty feel

**Animation System (New):**
- Root motion-driven or hybrid physics
- Turn-in-place loops
- Pose-matched transitions
- No strafe animations
- No backward walking animation

**Sitting and door interactions:** Status unclear post-pivot (were in original plan, may still be needed).

---

## Development History

### Phase 0: Project Initialization (Pre-Jan 2026)

**Commit:** `68c9e89` — "Sync all local changes: main menu, assets, and structure updates"

- Initialized Godot 4.6 project
- Imported asset library (models, animations, audio, fonts, shaders)
- Set up basic folder structure
- Created initial documentation (`CLAUDE.md`, screenplay, production plan, questionnaires)

**Key Assets Imported:**
- 40+ Mixamo FBX animations for Sven (walk, sit, strafe, stairs, turn, idle)
- Sven character model + 5 texture variants
- House interior model (`sven_home.glb`, 2-floor, 29 architecture + 14 furniture pieces)
- Street scene model (`street_scene.glb`, Urban Sprawl 2 city, 167×151m)
- Footstep audio (5 surfaces × 4 variants each)
- Interaction SFX (door, light switch, phone, newspaper)
- UI fonts (Fjalla One, Playfair Display, Inter, Courier Prime, Roboto Condensed)
- VHS/dreamscape shaders
- Music (`sven_killer.ogg`)

### Phase 1: Main Menu System (Jan-Feb 2026)

**Branch:** `main-menu-tweaks` → `main-menu-finalization`
**Commits:**
- `c949d44` — "Main menu stylization enhancements"
- `855234d` — "Add General settings tab with Language option"

**Implemented:**
- Splash screen with Gurgen Studios branding (`gurgenstudios.png`)
- Main menu with cinematic atmosphere:
  - Background video player (`main_menu.ogv`) with dreamscape shader overlay
  - Procedural dust particles (50 particles, slow drift)
  - Fjalla One title font (160pt, near-white with shadow)
  - Roboto Condensed buttons (34pt, hover effects with dark gray panels)
  - Menu SFX (hover, click)
  - Ambient audio loop (`ambient_main_menu.ogg`)
  - Music delayed fade-in (`sven_killer.ogg`, 10s fade)
- Settings menu overlay:
  - Audio tab (Master, Music, SFX sliders)
  - General tab (Language selection: Swedish, English, Spanish, Chinese, French, German, Turkish)
  - Settings persistence via `SettingsManager` autoload
- Scene transition system via `GameManager` autoload:
  - Fade-out → scene change → fade-in
  - Black overlay prevents white flash
  - TransitionLayer at z-index 100

**Audio Bus Setup:**
- Master → Music
- Master → SFX
- All audio routed through `SettingsManager` bus creation

**Files Created:**
- `scenes/main.tscn`, `scenes/main.gd`
- `scenes/ui/main_menu.tscn`, `scenes/ui/main_menu.gd`
- `scenes/ui/settings_menu.tscn`, `scenes/ui/settings_menu.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/autoload/settings_manager.gd`
- `assets/shaders/video_dreamscape.gdshader`

### Phase 2: Opening Sequence (Feb 2026)

**Branch:** `pre-gameplay-sequence` → `development`
**Commit:** `5209404` — "Complete opening voiceover sequence implementation"

**Implemented:**
- Opening voiceover sequence (`opening_sequence.tscn`):
  - Black screen with white text prompts
  - Timed subtitle display (Swedish with multi-language support)
  - Background video with B&W sepia shader (`video_bw_sepia.gdshader`)
  - Voiceover audio (`vo_opening_custody.ogg`)
  - Gaspar Noé prompt with metallic SFX (`noe_prompt_sfx.ogg`)
  - Sequence timing: 0.5s fade in → 3s hold → 1.0s fade out → video appears → voiceover plays → Noé prompt → transition to gameplay (placeholder)
- Subtitle system:
  - CSV-based subtitle data (time_start, time_end, text per language)
  - Dynamic language selection from `SettingsManager`
  - Courier Prime font for subtitle display

**Files Created:**
- `scenes/gameplay/opening_sequence.tscn`, `scenes/gameplay/opening_sequence.gd`
- `assets/shaders/video_bw_sepia.gdshader`


### Phase 3: Player Controller & Sitting Mechanic (Feb 2026)

**Branch:** `configuring-core-gameplay`
**Commit:** `a3288c2` — "Implement sitting mechanic with state machine and interactable system"

**Context:** Debug scene created to prototype player movement, animations, camera, and interactions. This work was done BEFORE the God of War plan was abandoned and represents the old over-the-shoulder strafing approach.

**Implemented:**
- Debug test scene (`scenes/debug/debug_scene.tscn`):
  - 20×20m platform
  - Simple chair (seat, backrest, 4 legs, brown wood material)
  - Player spawn at (0, 0, 5.726)
  - Directional light with shadows
  - Procedural sky
- Player controller (`scenes/debug/sven.gd`, CharacterBody3D):
  - Movement: WASD, 1.55 m/s speed, accel 2.4, decel 4.5
  - Camera: SpringArm3D system, shoulder offset +0.49m X, inertia 12.0, pitch clamp -15° to 60°
  - Camera decoupled from body rotation (CamOrigin handles yaw, Visuals rotate independently)
  - Idle breathing sway (0.0003 amount, 0.8 Hz)
  - Animation system:
    - Runtime FBX loading via `_load_anim(fbx_path, anim_name, loop, strip_root_motion)`
    - Auto-detection of bone prefix (mixamorig7_ → mixamorig_)
    - Preference for "mixamo_com" animation over "Take 001" (T-pose)
    - Root motion stripping (Hips position track removal)
    - Loaded animations: idle, walk, walk_backward, strafe_left, strafe_right, sit_down, idle_sit, stand_from_sit
    - Cross-fade blending (0.3s)
  - Direction-aware animation:
    - Forward (W) → walk
    - Backward (S) → walk_backward
    - Lateral (A/D alone) → strafe_left/strafe_right
    - Diagonal (W+A/D) → walk (not strafe)
  - Model rotation:
    - Forward: faces movement direction (atan2)
    - Backward/Strafe: faces camera forward
  - Footstep audio:
    - AudioStreamPlayer3D, pitch randomization 0.9-1.1
    - Step interval 582ms
    - Per-surface first-step offset (concrete: 270ms)
    - Single sound: `footstep_concrete_03.ogg`
  - Interaction system:
    - PlayerState enum: IDLE, WALKING, SITTING_DOWN, SEATED, STANDING_UP
    - RayCast3D aimed at camera pitch+yaw, 2m range, collision_mask layer 4 (Interactables)
    - E key triggers `_handle_interact()`
    - Sitting logic:
      - Raycast detects "sittable" group objects
      - Finds SeatPosition Marker3D child
      - Snaps player to seat global_position
      - Rotates model to face chair's -Z forward direction
      - Plays sit_down animation (one-shot, no root strip, no loop)
      - Transitions to idle_sit on animation_finished
      - E while seated plays stand_from_sit, nudges player forward 0.5m
    - Movement/animation/footsteps guarded by `can_move` (only IDLE/WALKING states)

**Animation Loading Fixes:**
- Fixed T-pose bug (prefer "mixamo_com" over "Take 001")
- Fixed bone name mismatches (auto-detect prefix)
- Fixed variable name collision (`offset` → `step_offset`)

**Assets Used:**
- FBX animations: `sven_idle_stand.fbx`, `sven_walk.fbx`, `sven_walk_backward.fbx`, `sven_strafe_left.fbx`, `sven_strafe_right.fbx`, `sven_sit_down.fbx`, `sven_idle_sit.fbx`, `sven_stand_from_sit.fbx`
- Deleted old strafe animations: `sven_strafe_walk_left.fbx`, `sven_strafe_walk_right.fbx`

**Physics Layers Defined:**
- Layer 1: World (environment collision)
- Layer 2: Player (player body)
- Layer 3: NPCs (pedestrians, girl)
- Layer 4: Interactables (doors, switches, seats)
- Layer 5: Triggers (progress zones, surface detection)

**Input Actions:**
- `move_forward`, `move_back`, `move_left`, `move_right`: WASD
- `interact`: E key
- `pause`: ESC

**Known Issues at End of Phase 3:**
- Sven model has 180° Y rotation in mesh (handled via negated atan2)
- GDScript strict typing requires `lerpf`/`clampf` instead of `lerp`/`clamp`
- Em-dash characters (—) in comments cause parse errors

**Files Created:**
- `scenes/debug/debug_scene.tscn`
- `scenes/debug/sven.gd`

### Phase 4: Massive Cleanup (Feb 7, 2026)

**Branch:** `massive-cleanup`
**Commit:** `72c1072` — "Massive cleanup: remove all unused assets and debug scenes"

**Rationale:** User requested drastic cleanup to remove all files not directly used by the main scene (`scenes/main.tscn`) and its dependencies. This was done to streamline the repository before a major pivot.

**Deleted (484 files, ~629 MB):**
- `scenes/debug/` (entire debug scene and player controller)
- `assets/animations/sven/` (all 20+ animation FBX files)
- `assets/models/` (character models, house, street, props)
- `assets/audio/sfx/footsteps/` (20 footstep audio files)
- `assets/audio/sfx/ambient/house_interior.ogg`, `assets/audio/sfx/ambient/street_morning.ogg`
- `assets/audio/vehicles/` (car sound effects)
- `assets/textures/` (environment textures, polyhaven library, UI extras)
- `.claude/plans/` (planning documents)
 - `static/`, `debug_screenshots/` (temp folders)
- Root-level temp files (installers, test FBX, test screenshots)

**Kept (26 essential files):**
- Core scenes: `main.tscn`, `main_menu.tscn`, `settings_menu.tscn`, `opening_sequence.tscn`
- Scripts: `main.gd`, `main_menu.gd`, `settings_menu.gd`, `opening_sequence.gd`
- Autoloads: `game_manager.gd`, `settings_manager.gd`
- Fonts: `fjalla_one.ttf`, `roboto_condensed.ttf`, `roboto_condensed_medium.ttf`, `roboto_condensed_semibold.ttf` (also kept unused: `courier_prime.ttf`, `inter.ttf`, `playfair_display.ttf`)
- Audio: `sven_killer.ogg` (music), `ambient_main_menu.ogg`, `menu_hover.ogg`, `menu_click.ogg`, `noe_prompt_sfx.ogg`, `vo_opening_custody.ogg`
- Video: `main_menu.ogv`, `voiceover_video.ogv`
- Shaders: `video_dreamscape.gdshader`, `video_bw_sepia.gdshader` (also kept unused: `button_shimmer.gdshader`, `ornate_frame.gdshader`, `text_distress.gdshader`, `title_breathing.gdshader`, `title_distortion.gdshader`)
- Branding: `gurgenstudios.png`
- Documentation: `docs/` (all files kept)
- Project files: `project.godot`, `.gitignore`, etc.
-- Godot addons: (none kept)

**Current Repository State:**
- Lean, production-ready asset structure
- All gameplay mechanics (debug scene, animations, models) removed
- Main menu experience fully functional
- Opening sequence functional
- Ready for complete redesign/pivot

---

## Current Project State

### What Works

✅ **Splash Screen**
- Gurgen Studios logo fade-in/fade-out (2s in, 2.5s hold, 1.5s out)
- Smooth transition to main menu (2.5s fade)

✅ **Main Menu**
- Background video with dreamscape shader overlay
- Dust particle effects (50 particles, 12s lifetime)
- Title: "SVEN KILLER" (Fjalla One, 160pt)
- Buttons: "New Game", "Settings" (Roboto Condensed, 34pt)
- Hover effects (dark gray panel, 0.45 alpha)
- Click/hover SFX
- Ambient audio loop (fade-in over 1.5s)
- Music delayed start (10s fade-in)
- Click "New Game" → 0.85s wait → audio/video stop → black screen → 0.45s wait → load opening_sequence.tscn

✅ **Settings Menu**
- Audio tab: Master, Music, SFX sliders (0-100%)
- General tab: Language dropdown (7 languages)
- Settings persistence via ConfigFile
- ESC to close overlay

✅ **Opening Sequence**
- Black screen text prompts (Swedish + multi-language)
- B&W sepia video with voiceover
- Gaspar Noé prompt (3s black screen, metallic SFX)
- Subtitle system (time-synced, language-aware)
- Auto-advance to next scene (placeholder)

✅ **Autoload Singletons**
- `GameManager`: Scene management, fade transitions, current_scene tracking
- `SettingsManager`: Audio bus setup, config persistence, language selection

✅ **Debug Scene & Player Prototype**
- `scenes/debug/debug_movement_and_camera.tscn` — Debug testbed added after this handover: contains a player instance and simple geometry; movement and camera were finalized here (prototype of the turn-and-walk locomotion and spring-arm camera with damping).

### What Doesn't Work

❌ **Gameplay**
- No player controller (deleted in cleanup)
- No animations (deleted in cleanup)
- No character model (deleted in cleanup)
- No house/street scenes (deleted in cleanup)
- Opening sequence has placeholder transition to gameplay (scene doesn't exist)

❌ **Audio**
- No footstep system
- No interaction SFX (door, light switch, phone, etc.) — assets exist but not used

❌ **Interaction System**
- No doors, light switches, seats, NPCs
- No raycast interaction
- No E key handling

### Current File Tree (Simplified)

```
SvenKillerDemo/
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   │   └── sven_killer.ogg
│   │   ├── sfx/
│   │   │   ├── ambient/
│   │   │   │   └── ambient_main_menu.ogg
│   │   │   └── interactions/
│   │   │       ├── menu_hover.ogg
│   │   │       ├── menu_click.ogg
│   │   │       └── noe_prompt_sfx.ogg
│   │   └── voiceover/
│   │       └── vo_opening_custody.ogg
│   ├── fonts/
│   │   ├── fjalla_one.ttf
│   │   ├── roboto_condensed.ttf
│   │   ├── roboto_condensed_medium.ttf
│   │   ├── roboto_condensed_semibold.ttf
│   │   ├── courier_prime.ttf
│   │   ├── inter.ttf
│   │   └── playfair_display.ttf
│   ├── shaders/
│   │   ├── video_dreamscape.gdshader
│   │   ├── video_bw_sepia.gdshader
│   │   ├── button_shimmer.gdshader
│   │   ├── ornate_frame.gdshader
│   │   ├── text_distress.gdshader
│   │   ├── title_breathing.gdshader
│   │   └── title_distortion.gdshader
│   ├── ui/
│   │   └── branding/
│   │       └── gurgenstudios.png
│   └── video/
│       ├── menu/
│       │   └── main_menu.ogv
│       └── voiceover/
│           └── voiceover_video.ogv
├── docs/
│   ├── CLAUDE.md
│   ├── final_animation_guideline.txt
│   ├── planning/
│   ├── questionnaires/
│   ├── sven_killer_details.txt
│   └── sven_killer_screenplay.txt
├── scenes/
│   ├── gameplay/
│   │   ├── opening_sequence.tscn
│   │   └── opening_sequence.gd
│   ├── ui/
│   │   ├── main_menu.tscn
│   │   ├── main_menu.gd
│   │   ├── settings_menu.tscn
│   │   └── settings_menu.gd
│   ├── debug/
│   │   └── debug_movement_and_camera.tscn
│   ├── main.tscn
│   └── main.gd
├── scripts/
│   └── autoload/
│       ├── game_manager.gd
│       └── settings_manager.gd
└── project.godot
```

---

## Technical Architecture

### Engine & Tools

- **Godot 4.6** (Forward Plus renderer)
- **GDScript 4.x** (type-safe, warnings as errors)
- **Target Platforms:** Windows (primary), Mac/Linux (secondary)
- **Resolution:** Fixed 1920×1080
- **Target FPS:** 60

### Code Style & Conventions

**Naming:**
- Files: `snake_case` (e.g., `game_manager.gd`)
- Classes: `PascalCase` (e.g., `GameManager`)
- Constants: `CONSTANT_CASE`
- Signals: `descriptive_past_tense` (e.g., `scene_changed`, `transition_finished`)
- Scenes: `snake_case` (e.g., `main.tscn`, `opening_sequence.tscn`)

**Type Hints:**
- Always use: `var speed: float = 1.2`
- Use `lerpf()`, `clampf()` for floats (not `lerp()`, `clamp()`)

**Onready Pattern:**
```gdscript
@onready var label: Label = $Path/To/Node
```

**Async/Await:**
- Heavy use for sequencing (tweens, timers, state transitions)

**Signals:**
- Prefer signals over callbacks for decoupled communication

**Error Handling:**
- Null checks before use
- Early returns

**Comments:**
- Explain *why*, not *what*
- Code should be self-documenting

### Established Patterns

**Scene Management:**
```gdscript
GameManager.change_scene("res://scenes/house_interior.tscn", 0.5)
# Fades out, changes scene, fades in over 0.5s total
```

**Autoload Signals:**
```gdscript
GameManager.transition_started.connect(_on_transition_started)
GameManager.transition_finished.connect(_on_transition_finished)
```

**Preload vs Load:**
```gdscript
# Preload at top of file for frequently-used assets
var sven_model: PackedScene = preload("res://scenes/player/sven.tscn")

# Load at runtime for infrequently-changed assets
var audio: AudioStream = load("res://assets/audio/music/sven_killer.ogg")
```

### Audio Architecture

**Bus Structure:**
```
Master
├── Music
└── SFX
```

**Setup:**
- `SettingsManager._ready()` creates buses if they don't exist
- All audio nodes assign `bus` property
- Volume controlled via `AudioServer.set_bus_volume_db()`

**Persistence:**
- Settings saved to `user://settings.cfg`
- Loaded on `SettingsManager._ready()`

### Scene Transition System

**GameManager Responsibilities:**
- Track `current_scene` reference
- Provide `change_scene(path, duration)` method
- Emit `transition_started`, `transition_finished` signals
- Handle fade-out → load → add to tree → fade-in

**TransitionLayer (Main.tscn):**
- CanvasLayer at z-index 100
- ColorRect "Fade" at anchors_preset 15 (full screen)
- Animated via Tween (color.a property)

---

## Asset Inventory

### Fonts (7 files)

| Font | Purpose | Used In |
|------|---------|---------|
| `fjalla_one.ttf` | Titles | Main menu title |
| `roboto_condensed.ttf` | Body text | (Unused) |
| `roboto_condensed_medium.ttf` | Menu buttons | Main menu buttons |
| `roboto_condensed_semibold.ttf` | Settings headers | Settings menu |
| `courier_prime.ttf` | Monospace | Opening sequence subtitles |
| `inter.ttf` | Body text | (Unused) |
| `playfair_display.ttf` | Elegant headings | (Unused) |

### Audio (6 files)

| File | Type | Purpose |
|------|------|---------|
| `sven_killer.ogg` | Music | Main menu background |
| `ambient_main_menu.ogg` | Ambient | Main menu background |
| `menu_hover.ogg` | SFX | Button hover |
| `menu_click.ogg` | SFX | Button click |
| `noe_prompt_sfx.ogg` | SFX | Gaspar Noé prompt metallic sound |
| `vo_opening_custody.ogg` | Voiceover | Opening sequence narration |

### Video (2 files)

| File | Purpose |
|------|---------|
| `main_menu.ogv` | Main menu background loop |
| `voiceover_video.ogv` | Opening sequence B&W video |

### Shaders (7 files)

| File | Purpose | Used In |
|------|---------|---------|
| `video_dreamscape.gdshader` | Video overlay effect | Main menu |
| `video_bw_sepia.gdshader` | B&W sepia effect | Opening sequence |
| `button_shimmer.gdshader` | Button hover effect | (Unused) |
| `ornate_frame.gdshader` | Decorative frame | (Unused) |
| `text_distress.gdshader` | Grunge text effect | (Unused) |
| `title_breathing.gdshader` | Animated title | (Unused) |
| `title_distortion.gdshader` | VHS distortion | (Unused) |

### UI Assets (1 file)

| File | Purpose |
|------|---------|
| `gurgenstudios.png` | Splash screen studio logo |

---

## Git Workflow

### Branch Structure

- `development` — Main integration branch
- `massive-cleanup` — Current working branch (post-cleanup)
- `configuring-core-gameplay` — Player controller (merged to dev, now obsolete)
- `main-menu-finalization` — Main menu (merged to dev)
- `main-menu-tweaks` — Menu polish (merged to dev)
- `pre-gameplay-sequence` — Opening sequence (merged to dev)
- `project_initialization` — Initial commit

### Commit Message Format

```
Brief summary line (imperative mood, <70 chars)

- Bullet point details
- Multiple lines allowed
- Explain what and why, not how

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```

### Workflow

1. Create feature branch from `development`
2. Commit frequently with descriptive messages
3. Push to origin
4. Merge to `development` when feature-complete
5. Push `development` to origin

**Never force-push to `main` or `development`.**

---

## Key Design Decisions

### 1. God of War Camera Abandoned

**Original Plan:** Over-the-shoulder camera with strafing, backward walking, and manual rotation control.

**New Plan (Post-Pivot):** Turn-then-walk locomotion model based on `docs/final_animation_guideline.txt`. Character always faces movement direction. S/A/D keys trigger turns, then walk forward. No strafe or backpedal animations.

**Implications:**
- All work in `scenes/debug/sven.gd` is now obsolete
- Animation requirements drastically simplified
- Camera system needs redesign (pivot at neck, 45-55° FOV, rotational damping)
- Physics needs acceleration/deceleration curves (0.4-0.6s ramp)

### 2. Massive Asset Cleanup Rationale

User requested deletion of all unused assets to streamline before major pivot. 484 files deleted, reducing repo to only main menu + opening sequence functionality. This was intentional and necessary for the redesign.

### 3. Swedish-First Language

All in-game text and voiceover in Swedish. English and 5 other languages supported via subtitles only. This is non-negotiable per design vision.

### 4. Gaspar Noé Prompt System

Black-screen interruptions with Swedish text + metallic sound. Deliberately immersion-breaking. Occurs twice in game. Opening sequence has first instance implemented.

### 5. Audio-First Design

Sound design paramount. Every interaction should have SFX. Voiceover drives narrative. Ambient audio creates atmosphere. Music is sparse and delayed (10s fade-in on main menu).

### 6. No Complex UI

Minimalist UI. Only prompts, interaction cues, subtitles visible. Menus fade in/out. No HUD clutter.

### 7. Fixed 1920×1080 Resolution

Not responsive. Designed for 16:9 aspect ratio only. Simplifies UI layout and cinematic framing.

---

## Pending Work & Next Steps

### Immediate Priorities (Post-Handover)

1. **Clarify Animation Requirements**
   - User is purchasing "MoCap Mobility Starter" pack ($3.99, 35 animations)
   - Pack includes: idle, walk, jog, crouch, jump, turns, transitions, aim offsets
   - Pack MISSING: sit down, sitting, stand up, door interactions
   - Decision needed: Are sitting/door interactions still required post-pivot?

2. **Rebuild Player Controller**
   - Implement turn-then-walk system per `final_animation_guideline.txt`
   - Acceleration-based movement (0.4-0.6s ramp to 1.5 m/s)
   - Deceleration with foot-planting (0.3-0.5s)
   - Camera pivot at 1.6m, FOV 45-55° vertical, rotational damping 0.1-0.2s
   - Input logic:
     - W from idle → walk_start transition → walk loop
     - S from idle → turn 180° (~0.8s) → walk forward
     - A/D from idle → turn 90° → walk forward
     - W+A/D → 45° arc turn while walking
     - Release → walk_stop transition with foot plant

3. **Import and Configure Animations**
   - Purchase and import MoCap Mobility Starter pack
   - Retarget to Godot humanoid skeleton
   - Set up AnimationTree or state machine
   - Configure root motion (if using)
   - Test transitions for smoothness

4. **Create Test Scene**
   - Simple environment for testing locomotion
   - No need for elaborate level geometry yet
   - Focus on movement feel and camera behavior

5. **Define Sitting/Door Mechanics**
   - If still needed, source animations separately
   - Design interaction prompts and raycast system
   - Decide on physics layers for interactables

### Medium-Term Work (Post-Movement)

1. **House Interior Scene**
   - Need to re-acquire or rebuild sven_home.glb (deleted in cleanup)
   - Set up lighting, spawn points, surface zones
   - Implement light switches (if still relevant)
   - Implement doors (if still relevant)
   - Implement sitting on couch/chairs (if still relevant)

2. **Voicemail System**
   - Wall phone interaction
   - Play mother's voicemail (30s audio, needs recording)
   - Subtitle display

3. **Street Walk Scene**
   - Need to re-acquire street_scene.glb (deleted in cleanup)
   - Pedestrian spawner (5-7 visible)
   - Car spawner (every 6-7s)
   - Death mechanic (traffic collision → respawn)
   - Rain effects
   - Surface-based footstep audio

4. **Bus Station Scene**
   - Girl character (needs model)
   - Dialogue/interaction system (TBD)

5. **Second Half Content**
   - Undefined. Not yet designed.

### Long-Term Considerations

- Performance optimization (target 60 FPS)
- Platform builds (Windows export, Mac/Linux secondary)
- Localization testing (7 languages)
- Audio mixing and mastering
- Final narrative polish

---

## Critical Context Notes

### For the Next LLM

1. **The God of War plan is DEAD.** Do not reference over-the-shoulder strafing mechanics, the old player controller in `scenes/debug/sven.gd`, or any deleted animations. The new system is turn-then-walk per `docs/final_animation_guideline.txt`.

2. **All gameplay assets were intentionally deleted.** This was not an accident. The user wanted a clean slate for the pivot. Do not suggest restoring deleted files from git history.

3. **The main menu and opening sequence are production-ready.** Do not refactor these unless explicitly requested. They work and match the artistic vision.

4. **Sitting and door interactions are in limbo.** The user has not confirmed whether these are still needed post-pivot. Ask before implementing.

5. **The MoCap Mobility Starter pack does not include sitting or door animations.** If these are needed, they must be sourced separately.

6. **Swedish is non-negotiable.** All in-game text and voiceover MUST be Swedish first. Subtitles handle other languages.

7. **The project is in active redesign.** The user is making drastic changes. Be prepared for additional pivots, asset purges, or direction shifts.

8. **GDScript strict typing is enforced.** Always use type hints. Use `lerpf`/`clampf` for floats. Avoid em-dash characters in comments.

9. **The user values conciseness.** Avoid verbose explanations. Be direct and actionable.

10. **Git hygiene matters.** Always commit with descriptive messages and Co-Authored-By tags. Never force-push to main/development.

### User's Development Style

- **Decisive:** Makes big changes quickly (e.g., deleting 484 files without hesitation)
- **Iterative:** Tests frequently, tweaks values in-editor (e.g., footstep offset changed from 290ms to 270ms)
- **Detail-Oriented:** Cares about animation timing, audio sync, font sizes, shadow offsets
- **Pragmatic:** Willing to abandon complex plans (God of War camera) for simpler alternatives
- **Research-Driven:** Analyzes other games' systems (reverse-engineering doc), purchases asset packs

### Known Gotchas

- Sven model has 180° Y rotation baked into mesh (handle with negated atan2 or rotation offset)
- Mixamo FBX files can have "Take 001" (T-pose) and "mixamo_com" (actual animation) — always prefer "mixamo_com"
- Mixamo bone prefixes vary (mixamorig_ vs mixamorig7_) — auto-detect via Hips bone search
- Root motion must be stripped for in-place animations (remove Hips position track)
- GDScript `lerp()`/`clamp()` return Variant, causing type errors — use `lerpf()`/`clampf()`
- Em-dash characters (—) break GDScript parser — use regular dash or avoid

### Files to Reference

- **`CLAUDE.md`** — Original project vision (now outdated, God of War plan abandoned)
- **`final_animation_guideline.txt`** — NEW movement system specification (turn-then-walk)
- **`sven_killer_screenplay.txt`** — Narrative details, dialogue, opening sequence script
- **`docs/planning/PRODUCTION_PLAN.txt`** — 480-line implementation roadmap (may be outdated)
- **`project.godot`** — Input mappings, physics layer names, autoload registrations

---

## End of Handover Document

**This document represents the complete state of the Sven Killer Demo project as of February 7, 2026.** The project is at a critical pivot point, transitioning from a complex God of War-style controller to a simpler turn-then-walk system. The main menu and opening sequence are production-ready, but all gameplay mechanics have been removed and must be rebuilt from scratch.

**Good luck, next LLM. The user is decisive and iterative. Stay concise, stay flexible, and always ask before assuming requirements.**
