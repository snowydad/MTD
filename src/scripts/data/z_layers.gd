class_name ZLayers
extends Object

## Единый порядок отрисовки (World / Node2D).
## UI — отдельно через CanvasLayer.layer.

const BG := 0
const DECOR := 10       # стрелы в земле, воронки, FX на поле
const MOBS := 20        # враги (+ y_sort у контейнера)
const PROJECTILE := 25  # стрелы в полёте (над мобами, под стеной)
const WALL := 30
const UNITS := 40       # юниты на стене
const UNIT_JUMP := 45   # юнит в прыжке со спавна

## CanvasLayer.layer для HUD
const UI_LAYER := 10
