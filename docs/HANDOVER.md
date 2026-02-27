# Sven Killer Demo — Project Handover
**Date:** Feb 27, 2026
**Branch:** `finalizing-street`
**Base branch:** `development`

---

## What's Been Built

### Scenes Complete (or Near-Complete)

| Scene | File | Status |
|-------|------|--------|
| Splash screen | `scenes/ui/splash_screen.tscn` | Complete |
| Main menu | `scenes/ui/main_menu.tscn` | Complete |
| Settings menu | `scenes/ui/settings_menu.tscn` | Complete |
| Opening sequence | `scenes/gameplay/opening_sequence.tscn` | Complete |
| House interior | `scenes/sven_house.tscn` | Complete (preloads during opening video) |
| Street | `scenes/street_prototype.tscn` | Complete |

### Systems Implemented

**Audio System (`scripts/autoload/audio_manager.gd`)**
- Pooled 2D and 3D audio players (8 each)
- Central config via `resources/audio_config.tres`
- Dynamic `NoePrompt` bus created at runtime with AudioEffectReverb
- `stop_all()` for instant cut on hard scene transitions

**Street Scene (`scripts/street/street_manager.gd`)**
- Mission statement: fades in 1s after scene load ("Go left to the bus station. Don't keep her waiting.")
- Death boundary: `z=24–127`, `x=-2.35–17.79` — instant black, audio mute, 1.6s blackout, respawn to start
- Second Noé prompt triggers at `z=60` — controls frozen, audio continues, duration 2.75s
- Rain system: GPU particles + ambient audio (`scripts/effects/rain_system.gd`)
- NPC walkers, groups, standing NPCs (`scripts/npc/`)
- Car spawner with passing audio (`scripts/audio/car_passing_audio.gd`)
- Motion blur via CanvasLayer shader (`scripts/effects/motion_blur.gd`, layer 127)

**Opening Sequence (`scenes/gameplay/opening_sequence.gd`)**
- B&W sepia video at 1.5× scale rendered through SubViewport at 12.5fps (10fps perceived)
- Synchronized subtitles
- House scene (`sven_house.tscn`) instantiated and preloaded during video playback
- Noé-style prompt ("VI KOMMER ATT TRÄFFAS VID BUSSTATIONEN") with reverb SFX
- Transitions directly into house scene without fade

**Subtitle System**
- Slot arbitration via `GameManager.claim_subtitle_bottom()` / `release_subtitle_bottom()`
- Used by: phone voicemail, newspaper clipping, opening sequence, street Noé prompt
- All subtitle CanvasLayers at layer **128** (above motion blur at 127)
- TransitionLayer at **200** (covers everything during scene changes)

**Interactables (house scene)**
- Door (`scripts/interactable/door_interactable.gd`)
- Light switch (`scripts/interactable/light_switch_interactable.gd`)
- Phone / voicemail (`scripts/interactable/phone_interactable.gd`)
- Newspaper clipping (`scripts/interactable/newspaper_clipping.gd`)

---

## Current Audio Levels

All values as of Feb 27, 2026. Two sources of truth: `audio_config.tres` (default) and hardcoded overrides in call sites.

| Sound | Where controlled | Current dB |
|-------|-----------------|------------|
| MENU_HOVER | `audio_config.tres` | 18.0 |
| MENU_CLICK | `main_menu.gd` + `settings_menu.gd` (hardcoded override) | -13.5 |
| AMBIENT_MAIN_MENU | `audio_config.tres` | 27.0 |
| MUSIC_MAIN | `audio_config.tres` | -7.0 |
| NOE_PROMPT | `opening_sequence.gd` × 2, `street_manager.gd` (hardcoded target) | 1.5 |
| HOUSE_HUM | `audio_config.tres` | -4.0 |
| AMB_RAIN | `audio_config.tres` | -10.0 |
| FOOTSTEP_WOOD 1–7 | `audio_config.tres` | -17.0 |
| PHONE_BUTTON_PRESS | `audio_config.tres` | 21.0 |
| VOICEMAIL | `audio_config.tres` | -4.0 |
| LIGHTSWITCH | `audio_config.tres` | 18.0 |
| Opening voiceover video | `opening_sequence.gd` (`video_player.volume_db`) | -3.5 |

**NoePrompt bus reverb:** room_size=0.3, damping=0.8, spread=0.5, wet=0.12, dry=1.0

---

## CanvasLayer Order (Critical — Do Not Break)

| Layer | What |
|-------|------|
| 0–126 | Game world, UI elements |
| 127 | Motion blur (CanvasLayer in `motion_blur.gd`) |
| 128 | All subtitle labels, mission statements |
| 190 | Street death/Noé overlay (`street_manager.gd`) |
| 200 | Scene transition fade (`main.gd` → TransitionLayer) |

Subtitles **must** be above 127 or they get blurred. TransitionLayer **must** be above 128 or subtitles show through on scene change.

---

## Key Architectural Decisions

- **Hard cut to street:** `GameManager.hard_cut_to_scene()` — stops all pooled audio, mutes Master bus, frees old scene, waits for preload window (min 20s from player gaining control), then reveals new scene.
- **Preloading:** House scene is instantiated during the opening video and parented under `GameManager` until reparented into `Main/CurrentScene` at video end.
- **Subtitle slot:** `GameManager._subtitle_bottom_owner` — only one system can show subtitles at the bottom at once. Others are pushed to top.
- **NoePrompt bus:** Created dynamically in `AudioManager._ready()`. If a "NoePrompt" bus already exists in the project layout, the dynamic creation is skipped.

---

## What's Left / Not Started

- **Bus station scene** — not created
- **Second half of game** — content TBD
- **Concrete/pavement footsteps** — only wood footsteps exist; street uses same sounds
- **Sven animations** — AnimationTree not wired up; player movement exists but uses no animation blending
- **NPC dialogue on street** — ambient audio exists, actual dialogue/subtitles not implemented
- **Credits / end screen** — not created
- **Mac/Linux testing** — untested

---

## Branch State

```
finalizing-street (current)
    └── development
            └── main
```

Recent commits (all on `finalizing-street`):
- Rain system, motion blur, NPC audio
- Car passing + NPC ambient audio
- NPC walker/group/standing system
- WorldEnvironment conflict fix + physics tuning
- Car spawner node path fix
