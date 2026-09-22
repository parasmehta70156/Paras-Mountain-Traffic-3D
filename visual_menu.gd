extends Node

var overlay: CanvasLayer
var root: Control
var game

func _ready():
    await get_tree().process_frame
    game = get_parent()
    _build_visual_menu()

func _build_visual_menu():
    overlay = CanvasLayer.new()
    overlay.layer = 50
    add_child(overlay)

    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(root)

    var bg := TextureRect.new()
    bg.texture = load("res://art/menu_reference.svg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    _hotspot(Vector2(25,325), Vector2(300,75), func():
        overlay.visible = false
        game._start_game()
    )
    _hotspot(Vector2(25,385), Vector2(300,75), func(): game._cycle_vehicle())
    _hotspot(Vector2(25,440), Vector2(300,75), func():
        game.night = not game.night
        game._set_lighting()
    )
    _hotspot(Vector2(1030,90), Vector2(145,160), func(): game.select_vehicle(0))
    _hotspot(Vector2(1190,90), Vector2(145,160), func(): game.select_vehicle(1))
    _hotspot(Vector2(1350,90), Vector2(140,160), func(): game.select_vehicle(2))

func _hotspot(pos: Vector2, size: Vector2, callback: Callable):
    var b := Button.new()
    b.position = pos
    b.size = size
    b.flat = true
    b.modulate = Color(1,1,1,0)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    root.add_child(b)
