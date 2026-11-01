# MTD — Merge Tower Defense

A 2D tower defense game with auto-merge mechanics.
A prototype built in **Godot 4**.



## Screen Settings (already configured)

| Setting              | Value          |
|-----------------------|-------------------|
| Viewport              | 1125 × 2436        |
| Stretch Mode          | canvas_items      |
| Stretch Aspect        | expand            |
| Orientation           | Portrait          |
| Renderer              | Mobile            |

## Project structure

```
MTD/
├── project.godot
├── src/
│   ├── scenes/
│   │   └── main.tscn
│   └── scripts/
│       └── main.gd
├── assets/
│   ├── data/
│   │   └── unit_stats.gd   # units' stats ( .tres later)
│   ├── sprites/
│   │   ├── background/     # bg_field.png
│   │   ├── wall/           # wall.png (tower at the bottom)
│   │   ├── enemies/        # goblin.png
│   │   ├── units/
│   │   │   ├── archer/
│   │   │   ├── mage/
│   │   │   └── cannon/
│   │   ├── projectiles/
│   │   └── effects/
│   ├── ui/
│   │   ├── buttons/
│   │   ├── icons/
│   │   └── panels/
│   ├── fonts/
│   └── audio/
└── autoload/
```

## Placeholders (replace later)

| File | Purpose |
|------|------------|
| `assets/sprites/background/bg_field.png` | Back |
| `assets/sprites/wall/wall.png` | (tower at the bottom) |
| `assets/sprites/enemies/goblin.png` | Goblin |
| `assets/sprites/units/*/..._1.png` | level_1 units|

## Текущий статус

- [x] Basic project.godot + resolution
- [x] Main scene framework (HUD + buttons)
- [x] Asset structure + placeholders (bg, wall, goblin)
- [x] Scenes and scripts moved to `src/`
- [ ] Energy system / button progress bars
- [ ] Unit spawning + dynamic positioning
- [ ] Auto-merge ×3
- [ ] Enemies + spawners
- [ ] Waves + perks

## GDD

See Google Doc (GDD Lite v3).
