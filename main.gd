extends Node3D

# Paras Mountain Traffic 3D - fully offline procedural 3D gameplay.
# No network, API, downloaded assets, or external runtime dependency.

var player: Node3D
var player_x := 0.0
var speed := 16.0
var target_speed := 16.0
var distance := 0.0
var score := 0
var started := false
var crashed := false
var left_pressed := false
var right_pressed := false
var traffic: Array[Node3D] = []
var traffic_z: Array[float] = []
var traffic_lane: Array[int] = []
var rng := RandomNumberGenerator.new()
var score_label: Label
var speed_label: Label
var message_label: Label
var steer_left: Button
var steer_right: Button
var brake_button: Button
var boost_button: Button

const ROAD_WIDTH := 12.0
const LANES := [-3.6, 0.0, 3.6]
const TRAFFIC_COUNT := 8
const FAR_Z := -150.0
const RESET_Z := 28.0

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
    sky_mat.sky_top_color = Color("#1769aa")
    sky_mat.sky_horizon_color = Color("#f7c873")
    sky_mat.ground_bottom_color = Color("#1d3522")
    sky_mat.ground_horizon_color = Color("#9bd5e8")
    sky.sky_material = sky_mat
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#b8d8ff")
    e.ambient_light_energy = 0.65
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_color = Color("#fff2d0")
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 80.0
    add_child(sun)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 4.4, 10.5)
    camera.look_at(Vector3(0, 1.4, -24), Vector3.UP)
    camera.fov = 68.0
    add_child(camera)

func _build_environment() -> void:
    var grass := mat(Color("#2e7d32"), 0.0, 1.0)
    var road := mat(Color("#30343b"), 0.0, 0.92)
    var line := mat(Color("#fff4c2"), 0.0, 0.65)
    var barrier := mat(Color("#cfd8dc"), 0.5, 0.4)
    var rock := mat(Color("#59636a"), 0.0, 1.0)
    var snow := mat(Color("#f4f8fb"), 0.0, 0.65)
    var pine := mat(Color("#14532d"), 0.0, 0.95)
    var trunk := mat(Color("#5d4037"), 0.0, 1.0)

    box(self, Vector3(90, 0.5, 260), Vector3(0, -0.7, -65), grass)
    box(self, Vector3(ROAD_WIDTH, 0.18, 230), Vector3(0, -0.38, -70), road)

    for z in range(-180, 31, 12):
        box(self, Vector3(0.22, 0.04, 5.2), Vector3(0, -0.26, z), line)
        box(self, Vector3(0.18, 0.04, 5.2), Vector3(-3.6, -0.25, z), line)
        box(self, Vector3(0.18, 0.04, 5.2), Vector3(3.6, -0.25, z), line)
        box(self, Vector3(0.28, 0.65, 11.5), Vector3(-6.25, -0.05, z), barrier)
        box(self, Vector3(0.28, 0.65, 11.5), Vector3(6.25, -0.05, z), barrier)

    for i in range(18):
        var z := -8.0 - float(i) * 10.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * (10.0 + float((i * 7) % 8))
        cyl(self, 0.35, 2.4, Vector3(x, 0.5, z), trunk)
        var tree := sphere(self, 2.0, Vector3(x, 2.2, z), pine)
        tree.scale = Vector3(1.0, 1.35, 1.0)
        sphere(self, 1.35, Vector3(x, 4.0, z), pine)

    for i in range(10):
        var z := -15.0 - float(i) * 16.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * (22.0 + float(i % 3) * 3.0)
        var mountain := cyl(self, 10.0 + float(i % 3) * 2.0, 22.0, Vector3(x, 8.0, z), rock)
        mountain.scale = Vector3(1.4, 1.0, 1.0)
        cyl(self, 5.0, 9.0, Vector3(x, 19.0, z), snow)

    # Roadside warning signs.
    for i in range(7):
        var z := -12.0 - float(i) * 25.0
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * 8.0
        cyl(self, 0.08, 1.6, Vector3(x, 0.55, z), barrier)
        box(self, Vector3(1.1, 0.9, 0.08), Vector3(x, 1.45, z), mat(Color("#f59e0b"), 0.0, 0.5))

func _build_player() -> void:
    player = Node3D.new()
    player.name = "PlayerSUV"
    add_child(player)
    player.position = Vector3(0, 0.65, 4.0)
    var body := mat(Color("#101820"), 0.55, 0.25)
    var glass := mat(Color("#183a56"), 0.25, 0.18)
    var chrome := mat(Color("#bfc7cc"), 0.85, 0.22)
    var red := mat(Color("#ff3030"), 0.15, 0.3)
    var white := mat(Color("#fff7d6"), 0.05, 0.25)
    box(player, Vector3(2.5, 0.65, 4.0), Vector3(0, 0.15, 0), body)
    box(player, Vector3(2.0, 0.72, 1.75), Vector3(0, 0.72, -0.15), body)
    box(player, Vector3(1.65, 0.52, 1.0), Vector3(0, 0.82, -0.35), glass)
    box(player, Vector3(2.15, 0.12, 3.7), Vector3(0, 0.62, 0.0), chrome)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(-0.75, 0.38, -2.03), red)
    box(player, Vector3(0.62, 0.16, 0.15), Vector3(0.75, 0.38, -2.03), red)
    box(player, Vector3(0.6, 0.18, 0.15), Vector3(-0.75, 0.42, 2.03), white)
    box(player, Vector3(0.6, 0.18, 0.15), Vector3(0.75, 0.42, 2.03), white)
    for x in [-1.15, 1.15]:
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, -1.25), ColorMaterial.new(), Vector3(PI/2,0,0)).material_override = ColorMaterial.new()
        var w := player.get_child(player.get_child_count()-1) as MeshInstance3D
        w.material_override = mat(Color("#121212"), 0.0, 0.95)
        cyl(player, 0.38, 0.28, Vector3(x, -0.15, 1.25), mat(Color("#121212"),0,0.95), Vector3(PI/2,0,0))

func _make_traffic_car(parent: Node3D, color: Color) -> void:
    var body := mat(color, 0.35, 0.32)
    var glass := mat(Color("#1f4560"), 0.2, 0.2)
    box(parent, Vector3(2.25, 0.58, 3.2), Vector3(0, 0.2, 0), body)
    box(parent, Vector3(1.7, 0.6, 1.55), Vector3(0, 0.7, -0.1), body)
    box(parent, Vector3(1.45, 0.42, 0.95), Vector3(0, 0.78, -0.25), glass)
    for x in [-0.9,0.9]:
        cyl(parent, 0.34, 0.24, Vector3(x,-0.16,-1.0), mat(Color("#111111"),0,1), Vector3(PI/2,0,0))
        cyl(parent, 0.34, 0.24, Vector3(x,-0.16,1.0), mat(Color("#111111"),0,1), Vector3(PI/2,0,0))

func _make_truck(parent: Node3D) -> void:
    var cab := mat(Color("#e85d04"),0.2,0.4)
    var cargo := mat(Color("#f2c14e"),0.0,0.65)
    var dark := mat(Color("#273238"),0.0,0.8)
    box(parent, Vector3(2.5, 1.0, 1.8), Vector3(0,0.35,0.8), cab)
    box(parent, Vector3(2.4, 1.8, 2.4), Vector3(0,0.7,-0.9), cargo)
    box(parent, Vector3(1.8,0.55,0.08), Vector3(0,0.8,1.72), dark)
    for x in [-1.0,1.0]:
        cyl(parent,0.38,0.3,Vector3(x,-0.2,-0.8),dark,Vector3(PI/2,0,0))
        cyl(parent,0.38,0.3,Vector3(x,-0.2,0.9),dark,Vector3(PI/2,0,0))

func _build_traffic() -> void:
    for i in range(TRAFFIC_COUNT):
        var v := Node3D.new()
        v.name = "Traffic_%02d" % i
        add_child(v)
        var lane := i % 3
        var z := FAR_Z - float(i) * 20.0
        v.position = Vector3(LANES[lane], 0.55, z)
        if i % 4 == 0:
            _make_truck(v)
        else:
            _make_traffic_car(v, [Color("#d62828"),Color("#f1faee"),Color("#3a86ff"),Color("#ffbe0b")][i % 4])
        traffic.append(v)
        traffic_z.append(z)
        traffic_lane.append(lane)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    score_label = Label.new()
    score_label.position = Vector2(28, 22)
    score_label.add_theme_font_size_override("font_size", 28)
    layer.add_child(score_label)
    speed_label = Label.new()
    speed_label.position = Vector2(28, 58)
    speed_label.add_theme_font_size_override("font_size", 22)
    layer.add_child(speed_label)
    message_label = Label.new()
    message_label.position = Vector2(0, 115)
    message_label.size = Vector2(1280, 120)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 38)
    layer.add_child(message_label)

    steer_left = _button(layer, "◀", Vector2(25, 585), Vector2(145, 105))
    steer_right = _button(layer, "▶", Vector2(190, 585), Vector2(145, 105))
    brake_button = _button(layer, "BRAKE", Vector2(1010, 590), Vector2(120, 90))
    boost_button = _button(layer, "BOOST", Vector2(1140, 490), Vector2(120, 90))
    steer_left.button_down.connect(func(): left_pressed = true)
    steer_left.button_up.connect(func(): left_pressed = false)
    steer_right.button_down.connect(func(): right_pressed = true)
    steer_right.button_up.connect(func(): right_pressed = false)
    brake_button.button_down.connect(func(): target_speed = 8.0)
    brake_button.button_up.connect(func(): target_speed = 18.0)
    boost_button.button_down.connect(func(): target_speed = 30.0)
    boost_button.button_up.connect(func(): target_speed = 18.0)

func _button(layer: CanvasLayer, text: String, pos: Vector2, size: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.modulate = Color(1,1,1,0.82)
    b.add_theme_font_size_override("font_size", 24)
    layer.add_child(b)
    return b

func _show_menu() -> void:
    message_label.text = "PARAS MOUNTAIN TRAFFIC 3D\nTAP THE SCREEN TO START • OFFLINE"
    score_label.text = ""
    speed_label.text = ""

func _start_game() -> void:
    started = true
    crashed = false
    message_label.text = ""
    target_speed = 18.0

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and not started:
        _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not started:
        _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R and crashed:
        get_tree().reload_current_scene()

func _process(delta: float) -> void:
    if not started or crashed:
        return
    var steer := 0.0
    if left_pressed or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): steer -= 1.0
    if right_pressed or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): steer += 1.0
    player_x = clamp(player_x + steer * delta * 8.0, -4.7, 4.7)
    player.position.x = player_x
    speed = lerp(speed, target_speed, delta * 2.5)
    distance += speed * delta
    score = int(distance * 2.0)

    for i in traffic.size():
        var v := traffic[i]
        v.position.z += speed * delta
        v.position.x = lerp(v.position.x, LANES[traffic_lane[i]], delta * 2.0)
        if v.position.z > RESET_Z:
            traffic_lane[i] = rng.randi_range(0,2)
            v.position.x = LANES[traffic_lane[i]]
            v.position.z = FAR_Z - rng.randf_range(0,65)
        if abs(v.position.z - player.position.z) < 2.6 and abs(v.position.x - player.position.x) < 1.7:
            _crash()

    score_label.text = "SCORE  %06d" % score
    speed_label.text = "SPEED  %03d km/h" % int(speed * 5.0)

func _crash() -> void:
    crashed = true
    speed = 0.0
    message_label.text = "CRASH!\nSCORE %06d\nPRESS R TO RESTART" % score
