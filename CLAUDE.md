# Sven Killer Demo — Project Context & Development Guide

## Project Overview

**Sven Killer Demo** is a 10-15 minute narrative-driven walking simulator in **Godot 4.6**.

**Premise:** Sven, a man in his late 20s/early 30s, wakes in his Swedish townhouse, receives a mysterious voicemail from his mother, explores his house, walks through rain-soaked streets, and arrives at a bus station. Narrative punctuated by black-screen prompts inspired by Gaspar Noé's "I Stand Alone."

**Artistic Influences:** God of War 2018 (over-the-shoulder camera), Gaspar Noé (VHS effects, immersion-breaking prompts), minimalist interactive fiction.

**Target Platforms:** Windows (primary), Mac/Linux (secondary). Fixed 1920×1080, 60 FPS target.

**Engine & Tools:**
- Godot 4.6 (Forward Plus renderer)
- GDScript 4.x (type-safe, with type hints)
- AI integration: removed
- Git with feature branching (`main-menu-tweaks` → `development`)

---

## Current Development Stage

**Phase 1 (Foundation & Polish)** — Main menu system complete, core infrastructure solid. Splash screen, transitions, menu UI, asset library all imported and configured.

**Active Focus:** Menu typography polish, shader integration, audio mixing setup.

**Next Phase Priority:** Player controller, house interior scene, interactable system (doors, switches, seats).

---

## Game Design Architecture

### Level Flow (Complete)

1. **Opening (Non-Playable):** Black screen → voiceover (Sven in custody, future) → VHS videos → mission text → fade to gameplay
2. **House Interior (Upper Floor):** Sven wakes on bed. E to stand. Light switches, wardrobe, bathroom. ~15s exploration.
3. **House Interior (Ground Floor):** Descent to dark ground floor (streetlight through blinds). Light switches, wall phone (voicemail), newspaper, couch. Exit via front door.
4. **House Exit Cutscene:** Door open, step outside, lock clicks. Door now inaccessible.
5. **Street Walk (5-7 min):** 72m walk to bus station. Rain, pedestrians (5-7 visible), cars every 6-7s. Death mechanic: traffic = black screen + respawn. **First Noé prompt** interrupts gameplay.
6. **Bus Station:** Girl awaits (dialogue/interaction TBD).
7. **Second Half + Ending:** Content TBD. Second Noé prompt somewhere. Cutscene/dialogue. Credits or menu return.

### Gameplay Mechanics

- **Movement:** WASD walk only (1.2 m/s fixed). No sprint, jump, or crouch.
- **Camera:** Over-the-shoulder, God of War style. Offset: +0.20m X, +0.12m Y, -0.65m Z from neck. FOV ~70°. Inertia for cinematic feel.
- **Interaction:** E key raycast for objects/NPCs. Distances TBD.
- **Death:** Step into traffic on street → black screen → respawn on pavement.

### Narrative Style

- **Language:** Swedish primary, English subtitles. Voiceover (future) + ambient dialogue (street pedestrians).
- **Subtitles:** 7 languages supported (Swedish, English, Spanish, Chinese, French, German, Turkish). Data-driven system (timestamps + text).
- **Noé Prompts:** 2 instances of black screen (3-5s) with Swedish text + metallic sound. Deliberate immersion break.
- **Audio-First:** Voiceover, ambient SFX, footsteps (surface-based), music. Sound design paramount.

---

## Code Conventions & Patterns

### Naming Standards

**GDScript Files:** `snake_case` (e.g., `game_manager.gd`)
**Classes:** `PascalCase` (e.g., `GameManager`, `PlayerController`)
**Constants:** `CONSTANT_CASE`
**Signals:** `descriptive_past_tense` (e.g., `scene_changed`, `transition_finished`)
**Scenes:** `snake_case` (e.g., `main.tscn`, `house_interior.tscn`)

**Asset Organization:**
- `assets/audio/` → `music/`, `sfx/`, `voiceover/`
- `assets/audio/sfx/` → `ambient/`, `footsteps/`, `interactions/`, `vehicles/`
- `assets/models/` → `characters/`, `environments/`, `props/`
- `assets/animations/sven/` (40+ FBX files, Mixamo-rigged)
- `assets/textures/` → `environment/`, `polyhaven/`, `ui/`
- `assets/shaders/` (custom GLSL: title gradient, text distress, etc.)

### Code Style

- **Type Hints:** Always use (GDScript 4.x). `var speed: float = 1.2`
- **Onready Pattern:** `@onready var label: Label = $Path/To/Node`
- **Async/Await:** Heavy use for sequencing (tweens, timers, state transitions).
- **Signals:** Prefer signals over callbacks for decoupled communication.
- **Singletons:** GameManager autoload for global state. Add others sparingly.
- **Error Handling:** Null checks before use. Early returns.
- **Comments:** Explain *why*, not *what*. Code should be self-documenting.

### Established Patterns

**Scene Manager with Fade Transitions:**
```gdscript
GameManager.change_scene("res://scenes/house_interior.tscn", 0.5)
# Fades out, changes scene, fades in over 0.5s total
```

**Autoload Signals:**
```gdscript
GameManager.transition_started.connect(_on_transition_started)
GameManager.transition_finished.connect(_on_transition_finished)
```

**Preload Assets at Top:**
```gdscript
var sven_model: PackedScene = preload("res://scenes/player/sven.tscn")
var footstep_grass: AudioStream = preload("res://assets/audio/sfx/footsteps/grass_01.ogg")
```

**Runtime Asset Loading (for frequently-changed assets):**
```gdscript
var audio: AudioStream = load("res://assets/audio/music/sven_killer.ogg")
```

---

## Architecture & Systems to Implement

### Player Controller (High Priority)
- CharacterBody3D with WASD movement (1.2 m/s)
- AnimationTree for Sven animations (idle, walk, strafe, turn, sit, stand, stair variants)
- Camera system: over-the-shoulder positioning, collision avoidance
- Footstep sound triggers (surface detection via physics layers)
- Input handling (move_forward, move_backward, move_left, move_right, interact, pause)

**Expected Structure:**
```
scenes/player/
├── player.tscn       (root CharacterBody3D with Sven model)
├── player.gd         (movement, animation tree, camera logic)
├── camera_controller.gd (camera positioning, collision)
```

### Interactable System
- Base `Interactable` class (raycast detectable, prompt display)
- Subclasses: Door, LightSwitch, Seat, NPC, PhysicsObject
- E key triggers interaction with closest interactable
- Raycast range ~2m, on physics layer 4 (Interactables)

**Physics Layers (Established):**
- Layer 1: World (environment collision)
- Layer 2: Player (player body)
- Layer 3: NPCs (pedestrians, girl)
- Layer 4: Interactables (doors, switches, seats)
- Layer 5: Triggers (progress zones, surface detection)

### Surface Zone System
- Trigger zones on physics layer 5, each labeled with surface type: `grass`, `wood`, `tile`, `concrete`, `carpet`, `stairs`
- When player enters/exits, signal to player controller
- Player controller selects footstep audio based on current surface + walking state

### Light Switch Interactable
- Component on light switch objects (3D models in house)
- E to toggle light on/off (parent light node visibility or intensity)
- Play `door_open.ogg` style SFX on toggle (TBD which SFX)
- No animation required initially (can add toggle animation later)

### Door Interactable
- Entry doors: E to open, load new scene (with fade transition via GameManager)
- Exit doors: E to open, trigger cutscene (door opens, Sven steps through, closes, locks)
- Play door open/close SFX
- Can lock doors (prevent re-entry, e.g., front door after exiting house)

### Seat Interactable
- Couch, dining chairs: E to sit, trigger sit animation (`sven_sit_down.fbx`)
- Display prompt: "E to sit" (distance-based, fade out beyond 2m)
- Sitting state: no movement, E to stand (`sven_stand_from_sit.fbx`)
- Inventory of 20+ animations already prepared; use them liberally

### NPC Controller
- Base for pedestrians + girl at bus station
- Simple idle/walk behavior (not complex AI initially)
- Pedestrian spawner: spawn at edges of map, walk across, despawn off-screen
- Girl: static pose at bus station, trigger dialogue on approach (TBD implementation)

### Progress Trigger System
- Invisible zones on physics layer 5 (Triggers)
- Trigger actions: play VHS video, play voicemail, spawn cars, spawn pedestrians, etc.
- Example: entering house ground floor → play ambient audio, turn on streetlight
- Example: reaching white dot on street → load bus station scene

### Voicemail System
- Wall phone interactable: E to pick up
- Play mother's voicemail (30s audio stream)
- Subtitle system displays synchronized Swedish text (+ other language options)
- Play phone SFX (pickup, dial tone, hangup)

### Subtitle System (Data-Driven)
- CSV/JSON with: `time_start, time_end, text_swedish, text_english, text_spanish, text_chinese, text_french, text_german, text_turkish`
- Dialogue Label displays current subtitle based on player selection
- Voicemail, Noé prompts, NPC dialogue all use same system
- Accessible in pause menu or settings (language selection)

---

## Asset Paths & Key Files

### Models & Animations
- **Sven Character:** `assets/models/characters/sven/` (main model + 5 texture variants)
- **Sven Animations:** `assets/animations/sven/` (40+ FBX files: walk, sit, stairs, turn, strafe, etc.)
- **House:** `assets/models/environments/sven_home.glb` (2-floor interior, 29 architecture + 14 furniture pieces)
- **Street:** `assets/models/environments/street_scene.glb` (Urban Sprawl 2 city, 167×151m, bus shelter, girl placeholder)
- **Props:** `assets/models/props/street/` (bench, streetlight, trash_can, fire_hydrant, mailbox, newspaper_stand)

### Audio
- **Ambient:** `assets/audio/sfx/ambient/` (house_interior.ogg, street_morning.ogg, main_menu.ogg)
- **Footsteps:** `assets/audio/sfx/footsteps/` (grass, wood, tile, concrete, carpet, stairs—4 variants each)
- **Interactions:** `assets/audio/sfx/interactions/` (door_open, door_close, light_switch, phone_pickup, newspaper_rustle)
- **Vehicles:** `assets/audio/sfx/vehicles/` (car_pass_by_01/02/03, car_idle_distant)
- **Music:** `assets/audio/music/sven_killer.ogg`
- **Voiceover:** `assets/audio/voiceover/` (opening narration, mother's voicemail—to be recorded/placed)

### UI & Shaders
- **Fonts:** Fjalla One (titles), Playfair Display (buttons), Inter (body), Courier Prime (text)
- **Shaders:** `assets/shaders/` (title_gradient, text_distress, ornate_frame)
- **UI Textures:** `assets/textures/ui/` (ornate borders, interaction prompts)

### Documentation (For Reference, Not Implementation)
- **Game Vision:** `docs/sven_killer_details.txt` (artistic direction, engine rationale)
- **Production Plan:** `docs/planning/PRODUCTION_PLAN.txt` (480-line implementation roadmap)
- **Screenplay:** `docs/sven_killer_screenplay.txt` (opening sequence dialogue, narrative details)
- **Asset Checklist:** `docs/planning/Final_Preparations.md` (import settings, phase breakdown)
- **Design Questionnaires:** `docs/questionnaires/` (12 files establishing design decisions)

---

## Workflow Best Practices

### Before Coding
1. **Check the docs first.** `Final_Preparations.md` has import settings and phase breakdown.
2. **Reference the screenplay.** `sven_killer_screenplay.txt` clarifies narrative intent.
3. **Review established patterns.** GameManager, scene transitions, autoload singletons.
4. **Plan the system.** Create a brief outline before writing code.

### During Implementation
1. **Use type hints.** Always. `var player: CharacterBody3D = ...`
2. **Leverage signals.** Prefer `signal_name.connect()` over callback parameters.
3. **Preload persistent assets.** Animation FBX, fonts, key audio. Load others at runtime if infrequent.
4. **Test with full assets.** Load Sven model + animations early; catch import issues.
5. **Use @onready.** All node references should be `@onready var...` at top of script.

### Git Workflow
1. Work on feature branches (`player-controller`, `interactables`, etc.), not directly on `main-menu-tweaks`.
2. Commit frequently with descriptive messages: "Add: player walking movement and animation blending"
3. Merge to `development` branch when feature-complete.
4. Use `main-menu-tweaks` only for menu-specific polish.

### Collaboration with Claude AI
- Use manual or external AI workflows.

---

## Key Reminders

- **No jump, sprint, or crouch.** Movement is walk only (WASD). Fixed 1.2 m/s.
- **Animations are prepared.** 40+ FBX files exist; AnimationTree must blend them seamlessly.
- **Audio is paramount.** Every interaction should have SFX. Footsteps vary by surface.
- **Narrative drives design.** Every scene has emotional/narrative purpose. Polish UI, timing, pacing.
- **Minimize UI clutter.** Only prompts, interaction cues, subtitles visible. Menus fade in/out.
- **Swedish first, English second.** Text/voiceover in Swedish, subtitles in 7 languages.
- **Second half is TBD.** Post-bus-station content not yet defined. Focus on playable opening first.

---

## Quick Reference: File Locations

| What | Where |
|------|-------|
| Main scene + transitions | `scenes/main.tscn` |
| Main menu | `scenes/ui/main_menu.tscn` |
| Game state manager | `scripts/autoload/game_manager.gd` |
| Sven model + textures | `assets/models/characters/sven/` |
| Sven animations | `assets/animations/sven/` |
| House model | `assets/models/environments/sven_home.glb` |
| Street model | `assets/models/environments/street_scene.glb` |
| Footsteps (all surfaces) | `assets/audio/sfx/footsteps/` |
| Interactions SFX | `assets/audio/sfx/interactions/` |
| Game design (screenplay) | `docs/sven_killer_screenplay.txt` |
| Production checklist | `docs/planning/Final_Preparations.md` |
| Godot MCP addon | removed |

---

## Next Steps (In Priority Order)

1. **Implement PlayerController** — CharacterBody3D, WASD movement, AnimationTree, camera
2. **Create House Interior Scene** — Load sven_home.glb, set up lighting, spawn points, surface zones
3. **Build Interactable Base Class** — Raycast detection, E key handling, visual feedback
4. **Add Light Switch Interactable** — Toggle house lights, SFX, hierarchy template for others
5. **Set Up Surface Zone System** — Detect walking surfaces, trigger footstep audio selection
6. **Implement Door Interactable** — Entry doors load scenes; exit door triggers cutscene
7. **Add Seat/Sitting System** — Couch/chairs, sit/stand animations, interaction prompts
8. **Build Street Scene** — Load street_scene.glb, pedestrian spawner, car spawner, death mechanic

*Estimated time: Phases 1-3 can be completed in 1-2 weeks with focused effort.*

---

**Last Updated:** Feb 4, 2026
**Branch:** main-menu-tweaks → development
**Contact AI:** AI integration removed — use external tools or scripts instead
