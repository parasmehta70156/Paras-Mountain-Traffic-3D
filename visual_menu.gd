extends Node

var overlay: CanvasLayer
var bg: TextureRect

func _ready():
    await get_tree().process_frame
    var game = get_parent()
    var old_menu = game.get("menu")
    if old_menu != null:
        old_menu.visible = false
    _build_visual_menu(game)

func _build_visual_menu(game):
    overlay = CanvasLayer.new()
    overlay.layer = 50
    add_child(overlay)

    var root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(root)

    bg = TextureRect.new()
    bg.texture = load("res://art/menu_reference.svg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    _hotspot(root, Vector2(25,325), Vector2(300,75), func(): game._start_game())
    _hotspot(root, Vector2(25,385), Vector2(300,75), func(): game._cycle_vehicle())
    _hotspot(root, Vector2(25,440), Vector2(300,75), func(): game.night = not game.night; game._set_lighting())
    _hotspot(root, Vector2(1030,90), Vector2(145,160), func(): game.selected_vehicle = -1; game._cycle_vehicle())
    _hotspot(root, Vector2(1190,90), Vector2(145,160), func(): game.selected_vehicle = 0; game._cycle_vehicle())
    _hotspot(root, Vector2(1350,90), Vector2(140,160), func(): game.selected_vehicle = 1; game._cycle_vehicle())

func _hotspot(parent: Control, pos: Vector2, size: Vector2, callback: Callable):
    var b = Button.new()
    b.position = pos
    b.size = size
    b.flat = true
    b.modulate = Color(1,1,1,0)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    parent.add_child(b)
