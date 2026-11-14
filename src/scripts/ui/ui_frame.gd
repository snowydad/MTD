extends CanvasLayer

## Общий каркас: золото + Назад.

signal back_pressed

@onready var gold_label: Label = $Root/TopBar/GoldLabel
@onready var btn_back: Button = $Root/TopBar/BtnBack


func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(func(): back_pressed.emit())
	_refresh_gold()
	if ProgressData:
		ProgressData.gold_changed.connect(_on_gold)


func _on_gold(v: int) -> void:
	if gold_label:
		gold_label.text = str(v)


func _refresh_gold() -> void:
	if gold_label and ProgressData:
		gold_label.text = str(ProgressData.gold)


func set_back_visible(v: bool) -> void:
	if btn_back:
		btn_back.visible = v
