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
├── src/
│   ├── scenes/
│   │   └── main.tscn
│   └── scripts/
│       └── main.gd
├── data/
│   └── unit_stats.gd
├── assets/
│   ├── sprites/
│   │   ├── background/     # bg_field.png
│   │   ├── wall/           # wall.png (стена внизу)
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

## Текущие плейсхолдеры (замени своими)

| Файл | Назначение |
|------|------------|
| `assets/sprites/background/bg_field.png` | Фон поля |
| `assets/sprites/wall/wall.png` | Стена (башня) внизу |
| `assets/sprites/enemies/goblin.png` | Гоблин |
| `assets/sprites/units/*/..._1.png` | Юниты 1 уровня (на будущее) |

## Текущий статус

- [x] Базовый project.godot + разрешение
- [x] Каркас main-сцены (HUD + кнопки)
- [x] Структура ассетов + плейсхолдеры (bg, wall, goblin)
- [x] Сцены и скрипты перенесены в `src/`
- [ ] Система энергии / прогресс-баров кнопок
- [ ] Спавн юнитов + динамическое позиционирование
- [ ] Авто-мерж ×3
- [ ] Враги + спавнеры
- [ ] Волны + перки

## GDD

См. Google Doc (GDD Lite v3).
