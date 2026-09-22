extends Node3D

# Paras Mountain Traffic 3D
# Offline mobile mountain traffic game. No network/API runtime dependency.

var player: Node3D
var traffic: Array[Node3D] = []
var traffic_lane: Array[int] = []
var rng := RandomNumberGenerator.new()
var speed := 0.0
var target_speed := 0.0
var player_x := 0.0
var distance := 0.0
var score := 0
var started := false
var crashed := false
var state := "menu"
var left_pressed := false
var right_pressed := false
var brake_pressed := false
var boost_pressed := false
var selected_vehicle := 0
var selected_level := 1

var ui: CanvasLayer
var menu_layer: Control
var garage_layer: Control
var levels_layer: Control
var settings_layer: Control
var gameplay_layer: Control
var score_label: Label
var speed_label: Label
var status_label: Label

const LANES := [-3.5, 0.0, 3.5]
const TRAFFIC_COUNT := 10
const FAR_Z := -170.0
const RESET_Z := 28.0
const ROAD_LENGTH := 260.0

func _ready() -> void:
    rng.seed = 87421
    _setup_world()
    _build_environment()
    _build_player()
    _build_traffic()
    _build_ui()
    _show_menu()

func mat(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    return n

func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    n.mesh = mesh
    n.position = pos
    n.rotation = rotation
    n.material_override = material
    parent.add_child(n)
    return n

func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    n.mesh = mesh
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    return n

func _setup_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#164b7a")
    sky_mat.sky_horizon_color = Color("#f5c26b")
    sky_mat.ground_bottom_color = Color("#132b20")
    sky_mat.ground_horizon_color = Color("#89c9dc")
    sky.sky_material = sky_mat
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#b8d8ff")
    e.ambient_light_energy = 0.72
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_color = Color("#fff1d0")
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100.0
    add_child(sun)

    var camera := Camera3D.new()
    camera.name = "MainCamera"
    camera.position = Vector3(0, 4.7, 11.0)
    camera.look_at(Vector3(0, 1.2, -25), Vector3.UP)
    camera.fov = 67.0
    add_child(camera)

func _build_environment() -> void:
    var grass := mat(Color("#236b32"), 0.0, 1.0)
    var road := mat(Color("#252a30"), 0.0, 0.9)
    var line := mat(Color("#f8e7a8"), 0.0, 0.55)
    var barrier := mat(Color("#c8d0d4"), 0.65, 0.35)
    var rock := mat(Color("#46525a"), 0.0, 1.0)
    var snow := mat(Color("#f4f7fa"), 0.0, 0.7)
    var pine := mat(Color("#0b4a2a"), 0.0, 1.0)
    var trunk := mat(Color("#5a3828"), 0.0, 1.0)
    var warning := mat(Color("#ffb000"), 0.0, 0.5)

    box(self, Vector3(100, 0.5, ROAD_LENGTH), Vector3(0, -0.7, -65), grass)
    box(self, Vector3(12.5, 0.2, ROAD_LENGTH - 10), Vector3(0, -0.38, -68), road)

    for z in range(-190, 35, 10):
        box(self, Vector3(0.16, 0.04, 4.8), Vector3(-3.5, -0.25, z), line)
        box(self, Vector3(0.16, 0.04, 4.8), Vector3(3.5, -0.25, z), line)
        box(self, Vector3(0.28, 0.65, 9.0), Vector3(-6.3, -0.03, z), barrier)
        box(self, Vector3(0.28, 0.65, 9.0), Vector3(6.3, -0.03, z), barrier)

    for i in range(24):
        var z := -8.0 - float(i) * 8.5
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * (9.0 + float((i * 5) % 7))
        cyl(self, 0.32, 2.2, Vector3(x, 0.45, z), trunk)
        var crown := sphere(self, 1.8, Vector3(x, 2.05, z), pine)
        crown.scale = Vector3(1.0, 1.35, 1.0)
        sphere(self, 1.15, Vector3(x, 3.75, z), pine)

    for i in range(13):
        var z := -12.0 - float(i) * 18.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * (21.0 + float(i % 3) * 3.0)
        var mountain := cyl(self, 9.0 + float(i % 3) * 2.0, 22.0, Vector3(x, 7.0, z), rock)
        mountain.scale = Vector3(1.45, 1.0, 1.0)
        cyl(self, 5.0, 9.0, Vector3(x, 18.0, z), snow)

    for i in range(9):
        var z := -16.0 - float(i) * 22.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * 6.8
        cyl(self, 0.07, 1.55, Vector3(x, 0.5, z), barrier)
        box(self, Vector3(1.0, 0.75, 0.08), Vector3(x, 1.35, z), warning)

func _build_player() -> void:
    player = Node3D.new()
    player.name = "PlayerSUV"
    add_child(player)
    player.position = Vector3(0, 0.65, 4.0)

    var body := mat(Color("#0b1117"), 0.65, 0.22)
    var glass := mat(Color("#17394f"), 0.3, 0.16)
    var chrome := mat(Color("#c7d0d5"), 0.9, 0.2)
    var red := mat(Color("#ff2020"), 0.2, 0.28)
    var white := mat(Color("#fff4d0"), 0.05, 0.22)
    var tire := mat(Color("#0c0c0c"), 0.0, 0.98)

    box(player, Vector3(2.55, 0.7, 4.0), Vector3(0, 0.12, 0), body)
    box(player, Vector3(2.05, 0.72, 1.85), Vector3(0, 0.72, -0.18), body)
    box(player, Vector3(1.7, 0.52, 1.08), Vector3(0, 0.82, -0.38), glass)
    box(player, Vector3(2.18, 0.12, 3.65), Vector3(0, 0.6, 0), chrome)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(-0.78, 0.4, -2.03), red)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(0.78, 0.4, -2.03), red)
    box(player, Vector3(0.6, 0.18, 0.15), Vector3(-0.78, 0.42, 2.03), white)
    box(player, Vector3(0.6, 0.18, 0.15), Vector3(0.78, 0.42, 2.03), white)
    for x in [-1.15, 1.15]:
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, -1.25), tire, Vector3(PI/2, 0, 0))
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, 1.25), tire, Vector3(PI/2, 0, 0))

func _make_car(parent: Node3D, color: Color) -> void:
    var body := mat(color, 0.35, 0.3)
    var glass := mat(Color("#1c4057"), 0.25, 0.2)
    var tire := mat(Color("#101010"), 0.0, 1.0)
    box(parent, Vector3(2.2, 0.58, 3.2), Vector3(0, 0.2, 0), body)
    box(parent, Vector3(1.7, 0.58, 1.55), Vector3(0, 0.7, -0.1), body)
    box(parent, Vector3(1.45, 0.42, 0.95), Vector3(0, 0.78, -0.25), glass)
    for x in [-0.88, 0.88]:
        cyl(parent, 0.33, 0.24, Vector3(x, -0.16, -1.0), tire, Vector3(PI/2, 0, 0))
        cyl(parent, 0.33, 0.24, Vector3(x, -0.16, 1.0), tire, Vector3(PI/2, 0, 0))

func _make_truck(parent: Node3D) -> void:
    var cab := mat(Color("#e85d04"), 0.25, 0.35)
    var cargo := mat(Color("#e7b44b"), 0.0, 0.65)
    var dark := mat(Color("#273238"), 0.0, 0.8)
    box(parent, Vector3(2.5, 1.0, 1.8), Vector3(0, 0.35, 0.8), cab)
    box(parent, Vector3(2.4, 1.75, 2.4), Vector3(0, 0.7, -0.9), cargo)
    box(parent, Vector3(1.8, 0.5, 0.08), Vector3(0, 0.8, 1.72), dark)
    for x in [-1.0, 1.0]:
        cyl(parent, 0.38, 0.3, Vector3(x, -0.2, -0.8), dark, Vector3(PI/2, 0, 0))
        cyl(parent, 0.38, 0.3, Vector3(x, -0.2, 0.9), dark, Vector3(PI/2, 0, 0))

func _build_traffic() -> void:
    for i in range(TRAFFIC_COUNT):
        var v := Node3D.new()
        v.name = "Traffic_%02d" % i
        add_child(v)
        var lane := i % 3
        v.position = Vector3(LANES[lane], 0.55, FAR_Z - float(i) * 20.0)
        if i % 4 == 0:
            _make_truck(v)
        else:
            var colors := [Color("#d62828"), Color("#f1faee"), Color("#3a86ff"), Color("#ffbe0b")]
            _make_car(v, colors[i % colors.size()])
        traffic.append(v)
        traffic_lane.append(lane)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    _create_menu_layer()
    _create_garage_layer()
    _create_levels_layer()
    _create_settings_layer()
    _create_gameplay_layer()

func _panel(parent: Control, pos: Vector2, size: Vector2, color := Color(0.02, 0.03, 0.04, 0.92)) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.corner_radius_top_left = 14
    sb.corner_radius_top_right = 14
    sb.corner_radius_bottom_left = 14
    sb.corner_radius_bottom_right = 14
    sb.border_width_left = 1
    sb.border_width_right = 1
    sb.border_width_top = 1
    sb.border_width_bottom = 1
    sb.border_color = Color(1, 1, 1, 0.12)
    p.add_theme_stylebox_override("panel", sb)
    parent.add_child(p)
    return p

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", font_size)
    parent.add_child(l)
    return l

func _game_button(parent: Control, text: String, pos: Vector2, size: Vector2, accent := false) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 24)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#12a83a") if accent else Color("#11181d")
    normal.corner_radius_top_left = 10
    normal.corner_radius_top_right = 10
    normal.corner_radius_bottom_left = 10
    normal.corner_radius_bottom_right = 10
    normal.border_width_left = 1
    normal.border_width_right = 1
    normal.border_width_top = 1
    normal.border_width_bottom = 1
    normal.border_color = Color(1, 1, 1, 0.12)
    b.add_theme_stylebox_override("normal", normal)
    parent.add_child(b)
    return b

func _title(parent: Control) -> void:
    _label(parent, "PARAS", Vector2(0, 28), Vector2(1280, 70), 58, HORIZONTAL_ALIGNMENT_CENTER)
    _label(parent, "MOUNTAIN", Vector2(0, 83), Vector2(1280, 72), 56, HORIZONTAL_ALIGNMENT_CENTER)
    var sub := _label(parent, "TRAFFIC 3D", Vector2(0, 135), Vector2(1280, 62), 48, HORIZONTAL_ALIGNMENT_CENTER)
    sub.modulate = Color("#ff2424")
    _label(parent, "RISK THE ROAD  •  FEEL THE THRILL", Vector2(0, 198), Vector2(1280, 36), 18, HORIZONTAL_ALIGNMENT_CENTER)

func _create_menu_layer() -> void:
    menu_layer = Control.new()
    menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(menu_layer)
    _title(menu_layer)
    var play := _game_button(menu_layer, "▶   PLAY", Vector2(470, 275), Vector2(340, 66), true)
    var garage := _game_button(menu_layer, "🚙   GARAGE", Vector2(470, 350), Vector2(340, 58))
    var settings := _game_button(menu_layer, "⚙   SETTINGS", Vector2(470, 417), Vector2(340, 58))
    var levels := _game_button(menu_layer, "🎮   LEVEL SELECT", Vector2(470, 484), Vector2(340, 58))
    var exit := _game_button(menu_layer, "EXIT", Vector2(470, 551), Vector2(340, 58))
    play.pressed.connect(func(): _start_game())
    garage.pressed.connect(func(): _show_garage())
    settings.pressed.connect(func(): _show_settings())
    levels.pressed.connect(func(): _show_levels())
    exit.pressed.connect(func(): get_tree().quit())
    _label(menu_layer, "Version 1.0.0  •  OFFLINE", Vector2(30, 675), Vector2(300, 30), 16)
    _label(menu_layer, "DRIVE BEYOND LIMITS", Vector2(950, 675), Vector2(300, 30), 16, HORIZONTAL_ALIGNMENT_RIGHT)

func _create_garage_layer() -> void:
    garage_layer = Control.new()
    garage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(garage_layer)
    _label(garage_layer, "‹   GARAGE", Vector2(35, 25), Vector2(500, 60), 34)
    _label(garage_layer, "🪙  1250", Vector2(1010, 25), Vector2(180, 50), 24, HORIZONTAL_ALIGNMENT_RIGHT)
    var card := _panel(garage_layer, Vector2(355, 105), Vector2(570, 365), Color(0.015, 0.02, 0.025, 0.96))
    _label(card, "SUV 01", Vector2(0, 18), Vector2(570, 42), 28, HORIZONTAL_ALIGNMENT_CENTER)
    _label(card, "PARAS EDITION", Vector2(0, 58), Vector2(570, 30), 16, HORIZONTAL_ALIGNMENT_CENTER)
    _label(card, "SPEED      ████████░░\nHANDLING  ██████░░░░\nBRAKING    ███████░░░", Vector2(70, 110), Vector2(430, 110), 20)
    var select := _game_button(card, "SELECTED", Vector2(165, 270), Vector2(240, 55), true)
    select.pressed.connect(func(): selected_vehicle = 0)
    for i in range(5):
        var x := 70.0 + float(i) * 230.0
        var b := _game_button(garage_layer, "SUV %02d" % (i + 1), Vector2(x, 510), Vector2(190, 90), i == 0)
        if i == 4:
            b.text = "🔒 SUV 05"
        b.pressed.connect(func(idx=i): selected_vehicle = idx)
    var back := _game_button(garage_layer, "‹  BACK", Vector2(35, 610), Vector2(160, 55))
    back.pressed.connect(func(): _show_menu())

func _create_levels_layer() -> void:
    levels_layer = Control.new()
    levels_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(levels_layer)
    _label(levels_layer, "‹   LEVEL SELECT", Vector2(35, 25), Vector2(600, 60), 34)
    for i in range(6):
        var row := i / 3
        var col := i % 3
        var p := _panel(levels_layer, Vector2(85 + col * 380, 120 + row * 230), Vector2(330, 190), Color(0.03,0.045,0.055,0.96))
        _label(p, "LEVEL %d" % (i + 1), Vector2(15, 12), Vector2(300, 42), 24)
        _label(p, "MOUNTAIN ROAD\n%d / 3 ★" % (1 if i == 0 else 0), Vector2(15, 60), Vector2(300, 70), 18)
        var b := _game_button(p, "PLAY" if i == 0 else "🔒 LOCKED", Vector2(15, 135), Vector2(300, 42), i == 0)
        if i == 0:
            b.pressed.connect(func(): _start_game())
    var back := _game_button(levels_layer, "‹  BACK", Vector2(35, 650), Vector2(160, 50))
    back.pressed.connect(func(): _show_menu())

func _create_settings_layer() -> void:
    settings_layer = Control.new()
    settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(settings_layer)
    _label(settings_layer, "‹   SETTINGS", Vector2(35, 25), Vector2(600, 60), 34)
    var items := ["♫   MUSIC", "🔊  SOUND EFFECTS", "▣   GRAPHICS", "◉   CONTROL", "◎   LANGUAGE"]
    var values := ["ON", "ON", "HIGH", "TOUCH", "ENGLISH"]
    for i in range(items.size()):
        var y := 120.0 + float(i) * 88.0
        var p := _panel(settings_layer, Vector2(250, y), Vector2(780, 70), Color(0.03,0.045,0.055,0.96))
        _label(p, items[i], Vector2(20, 5), Vector2(430, 60), 21)
        var v := _label(p, values[i], Vector2(580, 5), Vector2(170, 60), 20, HORIZONTAL_ALIGNMENT_RIGHT)
        v.modulate = Color("#39e75f") if i < 2 else Color("#e7e7e7")
    var back := _game_button(settings_layer, "‹  BACK", Vector2(35, 650), Vector2(160, 50))
    back.pressed.connect(func(): _show_menu())

func _create_gameplay_layer() -> void:
    gameplay_layer = Control.new()
    gameplay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(gameplay_layer)
    score_label = _label(gameplay_layer, "SCORE  0", Vector2(25, 20), Vector2(260, 44), 22)
    speed_label = _label(gameplay_layer, "SPEED  0 KM/H", Vector2(1010, 20), Vector2(240, 44), 22, HORIZONTAL_ALIGNMENT_RIGHT)
    status_label = _label(gameplay_layer, "", Vector2(0, 55), Vector2(1280, 50), 24, HORIZONTAL_ALIGNMENT_CENTER)
    var left := _game_button(gameplay_layer, "◀", Vector2(28, 575), Vector2(120, 105))
    var right := _game_button(gameplay_layer, "▶", Vector2(160, 575), Vector2(120, 105))
    var brake := _game_button(gameplay_layer, "BRAKE", Vector2(1010, 585), Vector2(110, 80))
    var boost := _game_button(gameplay_layer, "BOOST", Vector2(1145, 485), Vector2(110, 80), true)
    var pause := _game_button(gameplay_layer, "Ⅱ", Vector2(28, 85), Vector2(65, 55))
    left.button_down.connect(func(): left_pressed = true)
    left.button_up.connect(func(): left_pressed = false)
    right.button_down.connect(func(): right_pressed = true)
    right.button_up.connect(func(): right_pressed = false)
    brake.button_down.connect(func(): brake_pressed = true)
    brake.button_up.connect(func(): brake_pressed = false)
    boost.button_down.connect(func(): boost_pressed = true)
    boost.button_up.connect(func(): boost_pressed = false)
    pause.pressed.connect(func(): _show_menu())

func _hide_all() -> void:
    menu_layer.visible = false
    garage_layer.visible = false
    levels_layer.visible = false
    settings_layer.visible = false
    gameplay_layer.visible = false

func _show_menu() -> void:
    state = "menu"
    started = false
    _hide_all()
    menu_layer.visible = true

func _show_garage() -> void:
    state = "garage"
    _hide_all()
    garage_layer.visible = true

func _show_levels() -> void:
    state = "levels"
    _hide_all()
    levels_layer.visible = true

func _show_settings() -> void:
    state = "settings"
    _hide_all()
    settings_layer.visible = true

func _start_game() -> void:
    state = "gameplay"
    started = true
    crashed = false
    speed = 16.0
    target_speed = 16.0
    distance = 0.0
    score = 0
    player_x = 0.0
    player.position.x = 0.0
    _hide_all()
    gameplay_layer.visible = true
    status_label.text = "LEVEL %d  •  MOUNTAIN PASS" % selected_level

func _process(delta: float) -> void:
    if state != "gameplay" or not started:
        return
    var steering := 0.0
    if left_pressed:
        steering -= 1.0
    if right_pressed:
        steering += 1.0
    if Input.is_action_pressed("steer_left"):
        steering -= 1.0
    if Input.is_action_pressed("steer_right"):
        steering += 1.0
    if brake_pressed or Input.is_action_pressed("brake"):
        target_speed = 7.0
    elif boost_pressed or Input.is_action_pressed("boost"):
        target_speed = 29.0
    else:
        target_speed = 18.0
    speed = lerp(speed, target_speed, delta * 3.0)
    player_x = clamp(player_x + steering * delta * 6.0, -4.45, 4.45)
    player.position.x = lerp(player.position.x, player_x, delta * 10.0)
    distance += speed * delta
    score = int(distance * 3.0)
    score_label.text = "SCORE  %d" % score
    speed_label.text = "SPEED  %d KM/H" % int(speed * 4.0)

    for i in range(traffic.size()):
        var v := traffic[i]
        v.position.z += speed * delta * 0.82
        if v.position.z > RESET_Z:
            v.position.z = FAR_Z - rng.randf_range(0.0, 80.0)
            var lane := rng.randi_range(0, 2)
            traffic_lane[i] = lane
            v.position.x = LANES[lane]
            score += 20
        if abs(v.position.z - player.position.z) < 2.8 and abs(v.position.x - player.position.x) < 1.75:
            _crash()

func _crash() -> void:
    if crashed:
        return
    crashed = true
    speed = 0.0
    target_speed = 0.0
    status_label.text = "CRASH!  TAP PLAY AGAIN"
    await get_tree().create_timer(1.1).timeout
    if state == "gameplay":
        _start_game()
