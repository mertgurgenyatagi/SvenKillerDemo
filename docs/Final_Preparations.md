# Sven Killer Demo — Final Preparations
**Date:** 2026-02-03  
**Status:** Pre-Development Checklist

---

## 1. ASSET VERIFICATION

### 1.1 Character Models
| Asset | Location | Status | Action Needed |
|-------|----------|--------|---------------|
| sven.fbx | `assets/models/characters/sven/` | ⬜ Verify | Check rig, test import |
| girl_bus_station.fbx | `assets/models/characters/girl_bus_station/` | ⬜ Verify | Check rig |
| pedestrian_male_01-04.fbx | `assets/models/characters/pedestrians/` | ⬜ Verify | Check rig compatibility |
| pedestrian_female_01-03.fbx | `assets/models/characters/pedestrians/` | ⬜ Verify | Check rig compatibility |

### 1.2 Environment Models
| Asset | Location | Status |
|-------|----------|--------|
| sven_home.glb | `assets/models/environments/house/` | ✅ Exported |
| street_scene.glb | `assets/models/environments/city/` | ✅ Exported |

### 1.3 Vehicle Models
| Asset | Location | Status |
|-------|----------|--------|
| car_sedan_01/ | `assets/models/vehicles/cars/` | ⬜ Verify FBX/OBJ inside |
| car_sedan_02/ | `assets/models/vehicles/cars/` | ⬜ Verify |
| car_suv_01/ | `assets/models/vehicles/cars/` | ⬜ Verify |
| car_compact_01/ | `assets/models/vehicles/cars/` | ⬜ Verify |

### 1.4 Street Props
| Asset | Location | Status |
|-------|----------|--------|
| bench/ | `assets/models/props/street/` | ⬜ Verify |
| streetlight/ | `assets/models/props/street/` | ⬜ Verify |
| trash_can/ | `assets/models/props/street/` | ⬜ Verify |
| fire_hydrant/ | `assets/models/props/street/` | ⬜ Verify |
| mailbox/ | `assets/models/props/street/` | ⬜ Verify |
| newspaper_stand/ | `assets/models/props/street/` | ⬜ Verify |

### 1.5 Audio Assets
| Category | Count | Location | Status |
|----------|-------|----------|--------|
| Footsteps | 20 | `assets/audio/sfx/footsteps/` | ✅ Complete |
| Interactions | 11 | `assets/audio/sfx/interactions/` | ✅ Complete |
| Ambient | 3 | `assets/audio/sfx/ambient/` | ✅ Complete |
| Vehicles | 4 | `assets/audio/sfx/vehicles/` | ✅ Complete |
| Voiceover | 1 | `assets/audio/voiceover/` | ✅ Complete |

### 1.6 Animations (Sven)
| Animation | File | Status |
|-----------|------|--------|
| Idle Stand | sven_idle_stand.fbx | ⬜ Verify |
| Walk | sven_walk.fbx | ⬜ Verify |
| Run | sven_run.fbx | ⬜ Verify |
| Sit Idle | sven_idle_sit.fbx | ⬜ Verify |
| Stand from Sit | sven_stand_from_sit.fbx | ⬜ Verify |
| Sit Down | sven_sit_down.fbx | ⬜ Verify |
| Ascend Stairs | sven_ascend_stairs.fbx | ⬜ Verify |
| Descend Stairs | sven_descend_stairs.fbx | ⬜ Verify |
| Light Switch | sven_light_switch.fbx | ⬜ Verify |
| Open Door (In) | sven_open_door_in.fbx | ⬜ Verify |
| Open Door (Out) | sven_open_door_out.fbx | ⬜ Verify |
| Look Down | sven_look_down.fbx | ⬜ Verify |
| Strafe Left/Right | sven_strafe_*.fbx | ⬜ Verify |
| Turn Left/Right | sven_turn_*.fbx | ⬜ Verify |

### 1.7 Fonts
| Font | File | Purpose |
|------|------|---------|
| Inter | inter.ttf | Primary UI |
| Courier Prime | courier_prime.ttf | Noé-style screen text |

### 1.8 Video
| Asset | Location | Status |
|-------|----------|--------|
| tv_static.webm | `assets/video/vhs/` | ✅ Present |

---

## 2. GODOT PROJECT VERIFICATION

### 2.1 Project Settings
- [ ] Verify `project.godot` loads without errors
- [ ] Confirm renderer: Forward+
- [ ] Confirm resolution: 1920×1080
- [ ] Verify input mappings (WASD, E, Escape)
- [ ] Confirm physics layers are defined

### 2.2 Autoload Scripts
| Script | Path | Status |
|--------|------|--------|
| GameManager | `scripts/autoload/game_manager.gd` | ⬜ Test load |
| AudioManager | `scripts/autoload/audio_manager.gd` | ⬜ Test load |
| InputManager | `scripts/autoload/input_manager.gd` | ⬜ Test load |

### 2.3 Script Compilation
- [ ] `player_controller.gd` — No errors
- [ ] `interactable.gd` — No errors
- [ ] `door_interactable.gd` — No errors
- [ ] `light_switch_interactable.gd` — No errors
- [ ] `seat_interactable.gd` — No errors
- [ ] `surface_zone.gd` — No errors
- [ ] `progress_trigger.gd` — No errors
- [ ] `npc_pedestrian.gd` — No errors
- [ ] `car_spawner.gd` — No errors
- [ ] `interaction_prompt.gd` — No errors
- [ ] `screen_text.gd` — No errors

### 2.4 Resources
| Resource | Path | Status |
|----------|------|--------|
| Default Environment | `resources/environments/default_environment.tres` | ⬜ Verify |
| House Environment | `resources/environments/house_interior_environment.tres` | ⬜ Verify |
| Street Environment | `resources/environments/street_environment.tres` | ⬜ Verify |
| Audio Bus Layout | `default_bus_layout.tres` | ⬜ Verify buses exist |

---

## 3. IMPORT SETTINGS TO CONFIGURE

### 3.1 FBX Character Import Settings
When importing `sven.fbx` and other characters:
```
Root Type: Node3D (not AnimationPlayer)
Root Name: <model_name>
Skeleton:
  - Bone Rename: Keep original (Mixamo naming)
Animation:
  - Import: Separate file OR embedded based on structure
  - Loop Mode: Set per animation
  - Trim: Remove T-pose frames if present
Meshes:
  - Compress: Yes
  - Generate Lightmap UVs: No (we use realtime)
```

### 3.2 FBX Animation Import Settings
For standalone animation files (Mixamo):
```
Root Type: Node3D
Import as: Animation Library
Animation:
  - FPS: 30 (matches our export)
  - Loop Mode: 
    - Walk/Idle: Loop
    - Transitions: No Loop
  - Trim start/end if needed
```

### 3.3 GLB Environment Import Settings
For `sven_home.glb` and `street_scene.glb`:
```
Root Type: Node3D
Meshes:
  - Generate Lightmap UVs: Consider for baked lighting
  - Collision: Generate (for StaticBody3D auto-creation)
Materials:
  - Import: Embedded
```

### 3.4 Audio Import Settings
For all `.ogg` files:
```
Loop: 
  - Ambient files: Enable
  - SFX: Disable
Force Mono: Yes for positional SFX, No for ambient/music
```

---

## 4. SCENE HIERARCHY PLAN

### 4.1 Main Scene (`main.tscn`)
```
Main (Node)
├── CurrentLevel (Node3D)          ← Level scenes instantiated here
├── UI (CanvasLayer)
│   └── InteractionPrompt (Control)
│       └── PromptLabel (Label)
└── ScreenText (CanvasLayer)       ← Noé-style black screen text
    ├── Background (ColorRect)
    └── TextLabel (Label)
```

### 4.2 Player Scene (`player.tscn`) — TO CREATE
```
Player (CharacterBody3D)           ← player_controller.gd
├── CollisionShape3D (Capsule)
├── MeshInstance3D                 ← Sven model (or separate scene)
├── CameraPivot (Node3D)
│   ├── Camera3D
│   └── InteractionRay (RayCast3D)
├── AnimationTree
└── AudioStreamPlayer3D            ← Footstep sounds (positional)
```

### 4.3 House Level Scene (`house_level.tscn`) — TO CREATE
```
HouseLevel (Node3D)
├── WorldEnvironment              ← house_interior_environment.tres
├── DirectionalLight3D            ← Or imported lights
├── sven_home (imported GLB)
│   └── (auto-generated collision)
├── Interactables (Node3D)
│   ├── Bed (SeatInteractable)
│   ├── Couch (SeatInteractable)
│   ├── BedroomDoor (DoorInteractable)
│   ├── BathroomDoor (DoorInteractable)
│   ├── FrontDoor (DoorInteractable)
│   ├── BedroomLight (LightSwitchInteractable)
│   └── TV (Interactable) — custom
├── SurfaceZones (Node3D)
│   ├── WoodFloorZone (Area3D)
│   ├── CarpetZone (Area3D)
│   ├── TileZone (Area3D)
│   └── StairsZone (Area3D)
├── ProgressTriggers (Node3D)
│   ├── LeftBedroomTrigger
│   └── LeftHouseTrigger
├── SpawnPoints (Node3D)
│   ├── BedSpawn (Marker3D)
│   └── FrontDoorSpawn (Marker3D)
└── AmbientAudio (AudioStreamPlayer)
```

### 4.4 Street Level Scene (`street_level.tscn`) — TO CREATE
```
StreetLevel (Node3D)
├── WorldEnvironment              ← street_environment.tres
├── DirectionalLight3D            ← Morning sun, low angle
├── street_scene (imported GLB)
├── NPCs (Node3D)
│   ├── GirlAtBusStation
│   └── PedestrianSpawner
├── Vehicles (Node3D)
│   └── CarSpawner
├── SurfaceZones (Node3D)
│   └── ConcreteZone (Area3D)
├── ProgressTriggers (Node3D)
│   └── ReachedBusStationTrigger
├── SpawnPoints (Node3D)
│   ├── StreetStart (Marker3D)
│   └── BusStationEnd (Marker3D)
└── AmbientAudio (AudioStreamPlayer)
```

---

## 5. IMPLEMENTATION ORDER

### Phase 1: Core Systems (Foundation)
1. **Verify all scripts compile** — Run project, check for errors
2. **Set up Audio Bus Layout** — Ensure buses are recognized
3. **Test Autoloads** — Verify GameManager, AudioManager, InputManager load

### Phase 2: Player Character
4. **Import Sven model** — Configure import settings
5. **Create Player scene** — CharacterBody3D + collision + camera
6. **Attach animations** — AnimationTree setup
7. **Test movement** — Walk around empty scene
8. **Test footsteps** — Verify AudioManager plays sounds

### Phase 3: House Level
9. **Import sven_home.glb** — Generate collision
10. **Create HouseLevel scene** — Add environment, lights
11. **Add surface zones** — Wood, carpet, tile, stairs
12. **Add interactables** — Doors, lights, seats
13. **Add spawn points** — Bed, front door
14. **Test house navigation** — Walk through, interact

### Phase 4: Street Level
15. **Import street_scene.glb** — Configure collision
16. **Create StreetLevel scene** — Add environment, fog
17. **Add NPC spawner** — Pedestrians walking
18. **Add car spawner** — Traffic every 6-7 seconds
19. **Add girl at bus station** — Static NPC
20. **Test street navigation** — Walk corridor to bus station

### Phase 5: Game Flow
21. **Opening sequence** — Black screen text + voiceover
22. **Scene transitions** — House → Street
23. **Progress tracking** — GameManager state
24. **Ending trigger** — Reach bus station

### Phase 6: Polish
25. **Post-processing** — Verify environments look correct
26. **Audio mixing** — Balance levels
27. **UI polish** — Interaction prompts, screen text
28. **Playtesting** — Full walkthrough

---

## 6. KNOWN ISSUES / RISKS

| Issue | Risk Level | Mitigation |
|-------|------------|------------|
| Mixamo rig compatibility | Medium | May need retargeting in Godot |
| Animation blending | Medium | AnimationTree setup may need tuning |
| FBX import quirks | Low | Godot 4.6 has improved FBX support |
| Large GLB file size | Low | Already exported, seems fine |
| Surface detection | Low | Using Area3D triggers, reliable |

---

## 7. CLEANUP BEFORE BUILD

- [ ] Delete `ALL ASSETS/` folder (moved to `assets/`)
- [ ] Delete `NEW ASSETS/` folder (moved to `assets/fonts/`)
- [ ] Delete `sound_files_to_be_processed/` folder (if still exists)
- [ ] Verify `.gitignore` excludes large binary files appropriately
- [ ] Remove any test/placeholder files

---

## 8. QUICK REFERENCE

### Input Mappings
| Action | Key | Usage |
|--------|-----|-------|
| move_forward | W | Walk forward |
| move_backward | S | Walk backward |
| move_left | A | Strafe left |
| move_right | D | Strafe right |
| interact | E | Interact with objects |
| pause | Escape | Pause menu |

### Physics Layers
| Layer | Name | Used By |
|-------|------|---------|
| 1 | World | Environment collision |
| 2 | Player | Player CharacterBody3D |
| 3 | NPCs | Pedestrians, Girl |
| 4 | Interactables | Doors, switches, seats |
| 5 | Triggers | Surface zones, progress triggers |

### Audio Buses
| Bus | Purpose | Default dB |
|-----|---------|------------|
| Master | Overall volume | 0 |
| SFX | Sound effects | 0 |
| Ambient | Background loops | -3 |
| Voice | Voiceover | +3 |
| Music | Score (optional) | -6 |

---

## 9. READY TO BUILD?

Before proceeding, confirm:

- [ ] All assets verified and in correct locations
- [ ] Project opens without errors
- [ ] All scripts compile
- [ ] MCP connection working
- [ ] This checklist reviewed

**Once confirmed, we begin with Phase 1: Core Systems.**

---

*Document created: 2026-02-03*  
*Last updated: 2026-02-03*
