extends Node

var overlay: CanvasLayer
var root: Control
var game

func _ready():
    await get_tree().process_frame
    game = get_parent()
    _build_safe_menu()

func _build_safe_menu():
    overlay = CanvasLayer.new()
    overlay.layer = 50
    add_child(overlay)

    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(root)

    var bg := ColorRect.new()
    bg.color = Color(0.035, 0.055, 0.075, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    var title := Label.new()
    title.text = "PARAS MOUNTAIN TRAFFIC 3D"
    title.position = Vector2(45, 55)
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(1, 1, 1))
    root.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "DANGEROUS ROADS • REAL TRAFFIC • OFFLINE"
    subtitle.position = Vector2(48, 110)
    subtitle.add_theme_font_size_override("font_size", 20)
    subtitle.add_theme_color_override("font_color", Color(0.45, 0.9, 0.35))
    root.add_child(subtitle)

    _button("PLAY GAME", Vector2(50, 230), Vector2(310, 75), func():
        overlay.visible = false
        game._start_game()
    )
    _button("CHANGE VEHICLE", Vector2(50, 320), Vector2(310, 75), func(): game._cycle_vehicle())
    _button("DAY / NIGHT", Vector2(50, 410), Vector2(310, 75), func():
        game.night = not game.night
        game._set_lighting()
    )

    var info := Label.new()
    info.text = "SUV • FORTUNER • BIKE\n\nSteer: A / D\nBrake: S\nBoost: SPACE"
    info.position = Vector2(520, 245)
    info.add_theme_font_size_override("font_size", 24)
    info.add_theme_color_override("font_color", Color(0.88, 0.9, 0.92))
    root.add_child(info)

func _button(text: String, pos: Vector2, size: Vector2, callback: Callable):
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 24)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    root.add_child(b)
