# MTD — Merge Tower Defense

2D Tower Defense с механикой авто-слияния юнитов.  
Прототип на **Godot 4**.

## Быстрый старт

1. Склонируй репозиторий
2. Открой папку в Godot 4.3+ (или 4.2+)
3. Нажми F5 / Play

## Настройки экрана (уже прописаны)

| Параметр              | Значение          |
|-----------------------|-------------------|
| Viewport              | 720 × 1280        |
| Stretch Mode          | canvas_items      |
| Stretch Aspect        | expand            |
| Orientation           | Portrait          |
| Renderer              | Mobile            |

## Структура проекта

```
MTD/
├── project.godot
├── scenes/
│   └── main.tscn          # Главная сцена
├── scripts/
│   └── main.gd
├── data/                  # UnitStats, WaveConfigs (data-driven)
├── assets/
│   ├── sprites/
│   ├── ui/
│   ├── fonts/
│   └── audio/
└── autoload/              # GameManager, EventBus и т.д.
```

## Текущий статус

- [x] Базовый project.godot + разрешение
- [x] Каркас main-сцены (HUD + кнопки)
- [ ] Система энергии / прогресс-баров кнопок
- [ ] Спавн юнитов + динамическое позиционирование
- [ ] Авто-мерж ×3
- [ ] Враги + спавнеры
- [ ] Волны + перки

## GDD

См. Google Doc (GDD Lite v3).
