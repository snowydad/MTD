extends Control

const META := "res://src/scenes/ui/meta_map.tscn"
const FEEDBACK_URL := "https://example.com/mtd-feedback"

@onready var btn_sfx: Button = $Safe/VBox/BtnSfx
@onready var btn_music: Button = $Safe/VBox/BtnMusic
@onready var btn_lang: Button = $Safe/VBox/BtnLang
@onready var btn_feedback: Button = $Safe/VBox/BtnFeedback
@onready var btn_restore: Button = $Safe/VBox/BtnRestore
@onready var id_label: Label = $Safe/VBox/IdLabel
@onready var frame: CanvasLayer = $UIFrame


func _ready() -> void:
	frame.back_pressed.connect(func(): get_tree().change_scene_to_file(META))
	btn_sfx.pressed.connect(_toggle_sfx)
	btn_music.pressed.connect(_toggle_music)
	btn_lang.pressed.connect(_toggle_lang)
	btn_feedback.pressed.connect(func(): OS.shell_open(FEEDBACK_URL))
	btn_restore.pressed.connect(func(): print("Restore Purchases: stub"))
	_refresh()


func _refresh() -> void:
	btn_sfx.text = "SFX: ON" if ProgressData.sfx_on else "SFX: OFF"
	btn_music.text = "Music: ON" if ProgressData.music_on else "Music: OFF"
	btn_lang.text = "Language: %s" % ProgressData.language.to_upper()
	id_label.text = "ID: %s" % ProgressData.player_id


func _toggle_sfx() -> void:
	ProgressData.sfx_on = not ProgressData.sfx_on
	ProgressData.save()
	_refresh()


func _toggle_music() -> void:
	ProgressData.music_on = not ProgressData.music_on
	ProgressData.save()
	_refresh()


func _toggle_lang() -> void:
	ProgressData.language = "ru" if ProgressData.language == "en" else "en"
	ProgressData.save()
	_refresh()
