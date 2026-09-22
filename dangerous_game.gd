extends Node3D

# Paras Mountain Traffic 3D - Dangerous Road Edition
# Fully offline. Procedural 3D assets; no network/API dependency.

var player: Node3D
var camera: Camera3D
var road_root: Node3D
var traffic: Array[Node3D] = []
var traffic_speed: Array[float] = []
var traffic_lane: Array[int] = []
var obstacles: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

var player_lane := 1
var player_offset := 0.0
var speed := 0.0
var target_speed := 19.0
var distance := 0.0
var score := 0
var coins := 1250
var started := false
var crashed := false
var state := "menu"
var music_on := true
var sound_on := true
var graphics := 2

var ui: CanvasLayer
var menu_layer: Control
var garage_layer: Control
var levels_layer: Control
var settings_layer: Control
var gameplay_layer: Control
var score_label: Label
var speed_label: Label
var warning_label: Label

const LANES := [-3.2, 0.0, 3.2]
const ROAD_WIDTH := 11.0
const SEGMENT_LEN := 8.0
const SEGMENTS := 42
const TRAFFIC_COUNT := 12
const OBSTACLE_COUNT := 8
const START_Z := 10.0
const FAR_Z := -330.0
const RESET_Z := 24.0

func _ready() -> void:
    rng.seed = 90210
    _setup_world()
    _build_road()
    _build_player()
    _build_traffic()
    _build_obstacles()
    _build_ui()
    _show_menu()

func mat(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_y := 0.0) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.rotation.y = rot_y
    n.material_override = material
    parent.add_child(n)
    return n

func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    n.mesh = mesh
    n.position = pos
    n.rotation = rot
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

func curve_x(z: float) -> float:
    return sin((-z + 20.0) * 0.055) * 5.0 + sin((-z) * 0.021) * 2.2

func curve_slope(z: float) -> float:
    return -cos((-z + 20.0) * 0.055) * 0.275 - cos((-z) * 0.021) * 0.046

func road_pos(z: float, lane_offset: float = 0.0) -> Vector3:
    return Vector3(curve_x(z) + lane_offset, 0.0, z)

func _setup_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = Color("#0d3d6b")
    sm.sky_horizon_color = Color("#ffcf83")
    sm.ground_horizon_color = Color("#86b7c5")
    sm.ground_bottom_color = Color("#15261b")
    sky.sky_material = sm
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#b9d8ff")
    e.ambient_light_energy = 0.78
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_color = Color("#fff0d0")
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 120.0
    add_child(sun)
    camera = Camera3D.new()
    camera.name = "MainCamera"
    camera.fov = 68.0
    add_child(camera)
    _update_camera(0.0)

func _build_road() -> void:
    road_root = Node3D.new()
    road_root.name = "DangerousMountainRoad"
    add_child(road_root)
    var road_mat := mat(Color("#252a2e"), 0.0, 0.9)
    var edge_mat := mat(Color("#f2d36b"), 0.0, 0.55)
    var rail_mat := mat(Color("#b9c1c6"), 0.7, 0.35)
    var rock_mat := mat(Color("#3f4b52"), 0.0, 1.0)
    var grass_mat := mat(Color("#1f6a31"), 0.0, 1.0)
    var snow_mat := mat(Color("#eef5f8"), 0.0, 0.7)
    var pine_mat := mat(Color("#0b4829"), 0.0, 1.0)
    var trunk_mat := mat(Color("#573829"), 0.0, 1.0)
    var warning_mat := mat(Color("#ffb000"), 0.0, 0.5)
    box(self, Vector3(100, 0.45, 370), Vector3(0, -1.0, -150), grass_mat)
    for i in range(SEGMENTS):
        var z := START_Z - float(i) * SEGMENT_LEN
        var x := curve_x(z)
        var angle := -atan(curve_slope(z))
        box(road_root, Vector3(ROAD_WIDTH, 0.20, SEGMENT_LEN + 0.15), Vector3(x, -0.38, z), road_mat, angle)
        box(road_root, Vector3(0.20, 0.04, SEGMENT_LEN), Vector3(x - 3.55, -0.25, z), edge_mat, angle)
        box(road_root, Vector3(0.20, 0.04, SEGMENT_LEN), Vector3(x + 3.55, -0.25, z), edge_mat, angle)
        for side in [-1.0, 1.0]:
            var rail_x := x + side * 6.0
            box(road_root, Vector3(0.25, 0.75, SEGMENT_LEN), Vector3(rail_x, 0.0, z), rail_mat, angle)
            cyl(road_root, 0.10, 0.95, Vector3(rail_x, -0.05, z - 2.7), rail_mat)
        if i % 6 == 2:
            var side := -1.0 if curve_slope(z) > 0.0 else 1.0
            var sign_x := x + side * 5.0
            box(road_root, Vector3(1.0, 0.85, 0.10), Vector3(sign_x, 0.65, z), warning_mat, angle)
        if i % 7 == 4 or i % 11 == 8:
            var cliff_side := -1.0 if i % 2 == 0 else 1.0
            var cliff_x := x + cliff_side * 8.5
            box(road_root, Vector3(5.5, 1.0, SEGMENT_LEN), Vector3(cliff_x, -0.5, z), rock_mat, angle)
    for i in range(18):
        var z := -10.0 - float(i) * 17.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := curve_x(z) + side * (15.0 + float(i % 3) * 3.0)
        var mountain := cyl(self, 9.0 + float(i % 3) * 2.0, 24.0, Vector3(x, 8.0, z), rock_mat)
        mountain.scale = Vector3(1.45, 1.0, 1.0)
        cyl(self, 5.0, 9.0, Vector3(x, 19.0, z), snow_mat)
        var tree_x := curve_x(z) + (-1.0 if i % 2 == 0 else 1.0) * 10.0
        cyl(self, 0.30, 2.4, Vector3(tree_x, 0.5, z - 4.0), trunk_mat)
        var crown := sphere(self, 1.9, Vector3(tree_x, 2.25, z - 4.0), pine_mat)
        crown.scale = Vector3(1.0, 1.35, 1.0)

func _build_player() -> void:
    player = Node3D.new()
    player.name = "PlayerSUV"
    add_child(player)
    player.position = road_pos(4.0, 0.0)
    player.position.y = 0.62
    var body := mat(Color("#0b1117"), 0.7, 0.22)
    var glass := mat(Color("#173b52"), 0.3, 0.16)
    var chrome := mat(Color("#c9d1d5"), 0.9, 0.2)
    var red := mat(Color("#ff2020"), 0.2, 0.28)
    var white := mat(Color("#fff2cf"), 0.05, 0.22)
    var tire := mat(Color("#0b0b0b"), 0.0, 1.0)
    box(player, Vector3(2.55, 0.70, 4.0), Vector3(0, 0.12, 0), body)
    box(player, Vector3(2.04, 0.72, 1.85), Vector3(0, 0.72, -0.18), body)
    box(player, Vector3(1.70, 0.52, 1.08), Vector3(0, 0.82, -0.38), glass)
    box(player, Vector3(2.18, 0.12, 3.65), Vector3(0, 0.60, 0), chrome)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(-0.78, 0.40, -2.03), red)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(0.78, 0.40, -2.03), red)
    box(player, Vector3(0.60, 0.18, 0.15), Vector3(-0.78, 0.42, 2.03), white)
    box(player, Vector3(0.60, 0.18, 0.15), Vector3(0.78, 0.42, 2.03), white)
    for x in [-1.15, 1.15]:
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, -1.25), tire, Vector3(PI/2, 0, 0))
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, 1.25), tire, Vector3(PI/2, 0, 0))

func _make_car(parent: Node3D, color: Color, police := false) -> void:
    var body := mat(color, 0.35, 0.30)
    var glass := mat(Color("#173b52"), 0.25, 0.20)
    var tire := mat(Color("#101010"), 0.0, 1.0)
    box(parent, Vector3(2.2, 0.58, 3.2), Vector3(0, 0.2, 0), body)
    box(parent, Vector3(1.7, 0.58, 1.55), Vector3(0, 0.7, -0.1), body)
    box(parent, Vector3(1.45, 0.42, 0.95), Vector3(0, 0.78, -0.25), glass)
    if police:
        box(parent, Vector3(0.65, 0.10, 0.25), Vector3(0, 1.05, 0), mat(Color("#1565ff"), 0.0, 0.4))
    for x in [-0.88, 0.88]:
        cyl(parent, 0.33, 0.24, Vector3(x, -0.16, -1.0), tire, Vector3(PI/2, 0, 0))
        cyl(parent, 0.33, 0.24, Vector3(x, -0.16, 1.0), tire, Vector3(PI/2, 0, 0))

func _make_truck(parent: Node3D, color: Color) -> void:
    var cab := mat(color, 0.25, 0.35)
    var cargo := mat(Color("#e6b54d"), 0.0, 0.65)
    var dark := mat(Color("#273238"), 0.0, 0.8)
    box(parent, Vector3(2.5, 1.0, 1.8), Vector3(0, 0.35, 0.8), cab)
    box(parent, Vector3(2.4, 1.75, 2.4), Vector3(0, 0.70, -0.9), cargo)
    box(parent, Vector3(1.8, 0.5, 0.08), Vector3(0, 0.80, 1.72), dark)
    for x in [-1.0, 1.0]:
        cyl(parent, 0.38, 0.30, Vector3(x, -0.2, -0.8), dark, Vector3(PI/2, 0, 0))
        cyl(parent, 0.38, 0.30, Vector3(x, -0.2, 0.9), dark, Vector3(PI/2, 0, 0))

func _build_traffic() -> void:
    for i in range(TRAFFIC_COUNT):
        var v := Node3D.new()
        v.name = "Traffic_%02d" % i
        add_child(v)
        var lane := i % 3
        var z := -35.0 - float(i) * 23.0
        v.position = road_pos(z, LANES[lane])
        v.position.y = 0.55
        var oncoming := i % 4 == 1
        if i % 3 == 0:
            _make_truck(v, Color("#e85d04") if not oncoming else Color("#c1121f"))
        else:
            var colors := [Color("#d62828"), Color("#f1faee"), Color("#3a86ff"), Color("#ffbe0b")]
            _make_car(v, colors[i % 4], i == 7)
        traffic.append(v)
        traffic_lane.append(lane)
        traffic_speed.append(10.0 + float(i % 4) * 2.0 + (7.0 if oncoming else 0.0))

func _build_obstacles() -> void:
    for i in range(OBSTACLE_COUNT):
        var o := Node3D.new()
        o.name = "Rockfall_%02d" % i
        add_child(o)
        var lane := (i * 2) % 3
        var z := -75.0 - float(i) * 31.0
        o.position = road_pos(z, LANES[lane])
        o.position.y = 0.35
        var rock := mat(Color("#59646a"), 0.0, 1.0)
        sphere(o, 0.65 + float(i % 3) * 0.22, Vector3.ZERO, rock)
        sphere(o, 0.35, Vector3(0.35, 0.25, 0.2), rock)
        obstacles.append(o)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    _create_menu()
    _create_garage()
    _create_levels()
    _create_settings()
    _create_gameplay()

func _make_layer() -> Control:
    var c := Control.new()
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(c)
    return c

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, fs: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", fs)
    parent.add_child(l)
    return l

func _button(parent: Control, text: String, pos: Vector2, size: Vector2, accent := false) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 22)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("#15b83d") if accent else Color("#11171c")
    sb.corner_radius_top_left = 10
    sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10
    sb.corner_radius_bottom_right = 10
    sb.border_width_left = 1
    sb.border_width_right = 1
    sb.border_width_top = 1
    sb.border_width_bottom = 1
    sb.border_color = Color(1, 1, 1, 0.16)
    b.add_theme_stylebox_override("normal", sb)
    parent.add_child(b)
    return b

func _create_menu() -> void:
    menu_layer = _make_layer()
    _label(menu_layer, "PARAS MOUNTAIN", Vector2(0, 45), Vector2(700, 70), 52, HORIZONTAL_ALIGNMENT_CENTER)
    _label(menu_layer, "TRAFFIC 3D", Vector2(0, 112), Vector2(700, 60), 44, HORIZONTAL_ALIGNMENT_CENTER)
    _label(menu_layer, "RISK THE ROAD • FEEL THE THRILL", Vector2(0, 180), Vector2(700, 45), 20, HORIZONTAL_ALIGNMENT_CENTER)
    var p := _button(menu_layer, "▶  PLAY", Vector2(255, 255), Vector2(360, 68), true)
    var g := _button(menu_layer, "GARAGE", Vector2(255, 330), Vector2(360, 60))
    var l := _button(menu_layer, "LEVEL SELECT", Vector2(255, 397), Vector2(360, 60))
    var s := _button(menu_layer, "SETTINGS", Vector2(255, 464), Vector2(360, 60))
    p.pressed.connect(func(): _start_game())
    g.pressed.connect(func(): _show_layer("garage"))
    l.pressed.connect(func(): _show_layer("levels"))
    s.pressed.connect(func(): _show_layer("settings"))
    _label(menu_layer, "Version 1.0.0 • OFFLINE", Vector2(0, 650), Vector2(700, 40), 18, HORIZONTAL_ALIGNMENT_CENTER)

func _create_garage() -> void:
    garage_layer = _make_layer()
    _label(garage_layer, "←   GARAGE", Vector2(55, 35), Vector2(500, 60), 36)
    _label(garage_layer, "COINS  %d" % coins, Vector2(900, 35), Vector2(300, 55), 26, HORIZONTAL_ALIGNMENT_RIGHT)
    _label(garage_layer, "BLACK SUV", Vector2(420, 120), Vector2(440, 60), 34, HORIZONTAL_ALIGNMENT_CENTER)
    _label(garage_layer, "SPEED     ████████░░\nHANDLING  ██████░░░░\nBRAKING   ███████░░░", Vector2(430, 195), Vector2(420, 130), 22)
    for i in range(4):
        var b := _button(garage_layer, ["BLACK SUV", "WHITE SUV", "RED SUV", "BLUE SUV"][i], Vector2(80 + i * 290, 500), Vector2(250, 75), i == 0)
        b.pressed.connect(func(): _show_layer("garage"))
    var back := _button(garage_layer, "← BACK", Vector2(55, 610), Vector2(190, 55))
    back.pressed.connect(func(): _show_layer("menu"))

func _create_levels() -> void:
    levels_layer = _make_layer()
    _label(levels_layer, "←   LEVEL SELECT", Vector2(55, 35), Vector2(600, 60), 36)
    for i in range(6):
        var col := i % 3
        var row := i / 3
        var title := "LEVEL %d" % (i + 1)
        if i > 0:
            title += "  LOCKED"
        var b := _button(levels_layer, title, Vector2(100 + col * 370, 150 + row * 170), Vector2(330, 125), i == 0)
        if i == 0:
            b.pressed.connect(func(): _start_game())
    var back := _button(levels_layer, "← BACK", Vector2(55, 610), Vector2(190, 55))
    back.pressed.connect(func(): _show_layer("menu"))

func _create_settings() -> void:
    settings_layer = _make_layer()
    _label(settings_layer, "←   SETTINGS", Vector2(55, 35), Vector2(600, 60), 36)
    var music := _button(settings_layer, "MUSIC   " + ("ON" if music_on else "OFF"), Vector2(160, 160), Vector2(900, 70))
    var sound := _button(settings_layer, "SOUND EFFECTS   " + ("ON" if sound_on else "OFF"), Vector2(160, 245), Vector2(900, 70))
    var gfx := _button(settings_layer, "GRAPHICS   HIGH", Vector2(160, 330), Vector2(900, 70))
    var control := _button(settings_layer, "CONTROL   TOUCH", Vector2(160, 415), Vector2(900, 70))
    music.pressed.connect(func(): music_on = not music_on; _show_layer("settings"))
    sound.pressed.connect(func(): sound_on = not sound_on; _show_layer("settings"))
    gfx.pressed.connect(func(): graphics = (graphics + 1) % 3; _show_layer("settings"))
    control.pressed.connect(func(): _show_layer("settings"))
    var back := _button(settings_layer, "← BACK", Vector2(55, 610), Vector2(190, 55))
    back.pressed.connect(func(): _show_layer("menu"))

func _create_gameplay() -> void:
    gameplay_layer = _make_layer()
    score_label = _label(gameplay_layer, "SCORE 0", Vector2(28, 22), Vector2(300, 42), 24)
    speed_label = _label(gameplay_layer, "SPEED 0 KM/H", Vector2(28, 62), Vector2(340, 42), 22)
    warning_label = _label(gameplay_layer, "", Vector2(220, 22), Vector2(700, 50), 26, HORIZONTAL_ALIGNMENT_CENTER)
    var left := _button(gameplay_layer, "◀", Vector2(30, 555), Vector2(145, 105))
    var right := _button(gameplay_layer, "▶", Vector2(190, 555), Vector2(145, 105))
    var brake := _button(gameplay_layer, "BRAKE", Vector2(1030, 570), Vector2(130, 85))
    var boost := _button(gameplay_layer, "BOOST", Vector2(1175, 470), Vector2(100, 85), true)
    left.button_down.connect(func(): player_lane = max(0, player_lane - 1))
    right.button_down.connect(func(): player_lane = min(2, player_lane + 1))
    brake.button_down.connect(func(): target_speed = 7.0)
    brake.button_up.connect(func(): target_speed = 19.0)
    boost.button_down.connect(func(): target_speed = 31.0)
    boost.button_up.connect(func(): target_speed = 19.0)
    var pause := _button(gameplay_layer, "Ⅱ", Vector2(1165, 25), Vector2(70, 55))
    pause.pressed.connect(func(): _show_layer("menu"))

func _hide_all() -> void:
    menu_layer.visible = false
    garage_layer.visible = false
    levels_layer.visible = false
    settings_layer.visible = false
    gameplay_layer.visible = false

func _show_layer(which: String) -> void:
    _hide_all()
    state = which
    if which == "menu": menu_layer.visible = true
    elif which == "garage": garage_layer.visible = true
    elif which == "levels": levels_layer.visible = true
    elif which == "settings": settings_layer.visible = true
    elif which == "game": gameplay_layer.visible = true

func _show_menu() -> void:
    _show_layer("menu")

func _start_game() -> void:
    _hide_all()
    gameplay_layer.visible = true
    state = "game"
    started = true
    crashed = false
    speed = 0.0
    target_speed = 19.0
    distance = 0.0
    score = 0
    player_lane = 1
    player_offset = 0.0
    player.position = road_pos(4.0, 0.0)
    player.position.y = 0.62
    for i in range(traffic.size()):
        var z := -35.0 - float(i) * 23.0
        traffic[i].position = road_pos(z, LANES[traffic_lane[i]])
    for i in range(obstacles.size()):
        var z := -75.0 - float(i) * 31.0
        var lane := (i * 2) % 3
        obstacles[i].position = road_pos(z, LANES[lane])
        obstacles[i].position.y = 0.35

func _update_camera(z: float) -> void:
    if camera == null: return
    var x := curve_x(z)
    camera.position = Vector3(x + player_offset, 4.8, 11.0)
    camera.look_at(Vector3(curve_x(-28.0) + player_offset * 0.35, 1.1, -28.0), Vector3.UP)

func _physics_process(delta: float) -> void:
    if state != "game" or not started or crashed: return
    speed = lerp(speed, target_speed, min(1.0, delta * 2.6))
    distance += speed * delta
    score = int(distance * 10.0)
    player_offset = lerp(player_offset, LANES[player_lane], min(1.0, delta * 7.0))
    player.position = road_pos(4.0, player_offset)
    player.position.y = 0.62
    player.rotation.y = -atan(curve_slope(4.0))
    _update_camera(4.0)

    for i in range(traffic.size()):
        var v := traffic[i]
        v.position.z += (speed - traffic_speed[i]) * delta
        var lane_offset := LANES[traffic_lane[i]]
        v.position.x = curve_x(v.position.z) + lane_offset
        v.rotation.y = -atan(curve_slope(v.position.z))
        if v.position.z > RESET_Z:
            v.position.z = FAR_Z - float((i * 17) % 70)
            traffic_lane[i] = (traffic_lane[i] + 1 + (i % 2)) % 3
            traffic_speed[i] = 10.0 + float(i % 5) * 2.0 + (6.0 if i % 4 == 1 else 0.0)
        if abs(v.position.z - 4.0) < 3.0 and abs((v.position.x - curve_x(4.0)) - player_offset) < 1.8:
            _crash("TRAFFIC COLLISION!")

    for i in range(obstacles.size()):
        var o := obstacles[i]
        o.position.z += speed * delta
        o.position.x = curve_x(o.position.z) + LANES[(i * 2) % 3]
        if o.position.z > RESET_Z:
            o.position.z = FAR_Z - float((i * 29) % 100)
        if abs(o.position.z - 4.0) < 2.4 and abs((o.position.x - curve_x(4.0)) - player_offset) < 1.6:
            _crash("ROCKFALL!")

    if abs(curve_slope(4.0)) > 0.18:
        warning_label.text = "⚠ SHARP TURN • DANGEROUS ROAD"
    elif speed > 28.0:
        warning_label.text = "⚠ HIGH SPEED • TRAFFIC AHEAD"
    else:
        warning_label.text = ""
    score_label.text = "SCORE  %d" % score
    speed_label.text = "SPEED  %d KM/H" % int(speed * 3.6)

func _crash(reason: String) -> void:
    crashed = true
    target_speed = 0.0
    speed = 0.0
    warning_label.text = "💥 " + reason + " • TAP PLAY TO RETRY"
