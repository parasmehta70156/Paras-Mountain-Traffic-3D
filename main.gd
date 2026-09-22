extends Node3D

var player: Node3D
var player_body: MeshInstance3D
var camera: Camera3D
var speed := 0.0
var distance := 0.0
var health := 100.0
var score := 0
var lane := 0.0
var selected_vehicle := 0
var rain := false
var night := false
var traffic: Array[Node3D] = []
var game_started := false
var crashed := false
var rng := RandomNumberGenerator.new()
var speed_label: Label
var score_label: Label
var health_label: Label
var status_label: Label
var menu: Control
var env: WorldEnvironment
var environment: Environment
var sun: DirectionalLight3D

func _ready():
    rng.seed = 92715
    _build_world()
    _build_ui()
    _show_menu()

func mat(c: Color, roughness := 0.75, emission := Color(0,0,0)) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = roughness
    if emission != Color(0,0,0):
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = 1.5
    return m

func box(size: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = size
    n.mesh = b
    n.material_override = material
    return n

func cyl(radius: float, height: float, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = radius
    c.bottom_radius = radius
    c.height = height
    n.mesh = c
    n.material_override = material
    return n

func _build_world():
    env = WorldEnvironment.new()
    environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.32, 0.48, 0.68)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.9, 0.95, 1.0)
    environment.ambient_light_energy = 1.25
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.25
    env.environment = environment
    add_child(env)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-25,0)
    sun.light_color = Color(1.0,0.94,0.82)
    sun.light_energy = 1.8
    sun.shadow_enabled = true
    add_child(sun)

    var fill := OmniLight3D.new()
    fill.position = Vector3(0,12,25)
    fill.light_color = Color(0.55,0.72,1.0)
    fill.light_energy = 8.0
    fill.omni_range = 80
    add_child(fill)

    for z in range(-220, 300, 20):
        var road := box(Vector3(11,0.35,20), mat(Color(0.12,0.13,0.14)))
        road.position = Vector3(0,-0.2,z)
        add_child(road)
        for x in [-3.45,3.45]:
            var barrier := box(Vector3(0.22,0.95,20), mat(Color(0.82,0.78,0.60),0.6,Color(0.16,0.12,0.05)))
            barrier.position = Vector3(x,0.3,z)
            add_child(barrier)
        for x in [-1.65,1.65]:
            var line := box(Vector3(0.14,0.035,5.0), mat(Color(1.0,0.9,0.18),0.5,Color(0.3,0.25,0.02)))
            line.position = Vector3(x,0.03,z)
            add_child(line)
        _add_mountain_pair(z)

    player = Node3D.new()
    player.position = Vector3(0,0.8,30)
    add_child(player)
    player_body = _make_vehicle(selected_vehicle, true)
    player.add_child(player_body)

    camera = Camera3D.new()
    camera.position = Vector3(0,5.2,10.5)
    camera.rotation_degrees = Vector3(-11,180,0)
    camera.fov = 68
    player.add_child(camera)
    camera.current = true

func _add_mountain_pair(z: float):
    for side in [-1,1]:
        var h := rng.randf_range(12,28)
        var mountain := cyl(rng.randf_range(5.0,8.0), h, mat(Color(0.18,0.23,0.29)))
        mountain.position = Vector3(side*rng.randf_range(11,18), h/2.0-0.2, z+rng.randf_range(-7,7))
        mountain.scale.x = 1.4
        mountain.scale.z = 1.3
        add_child(mountain)

func _make_vehicle(kind: int, player_car := false) -> MeshInstance3D:
    var root := MeshInstance3D.new()
    var body := BoxMesh.new()
    if kind == 0:
        body.size = Vector3(1.9,0.8,3.6)
        root.material_override = mat(Color(0.06,0.07,0.08),0.55,Color(0.015,0.02,0.025))
    elif kind == 1:
        body.size = Vector3(2.0,0.9,3.7)
        root.material_override = mat(Color(0.88,0.88,0.92),0.5)
    else:
        body.size = Vector3(0.8,0.55,2.2)
        root.material_override = mat(Color(0.75,0.05,0.03),0.5)
    root.mesh = body
    var cabin := box(Vector3(body.size.x*0.72, body.size.y*0.72, body.size.z*0.42), mat(Color(0.06,0.14,0.19),0.25))
    cabin.position.y = body.size.y*0.62
    root.add_child(cabin)
    for sx in [-1,1]:
        for sz in [-1,1]:
            var wheel := cyl(0.28 if kind<2 else 0.18, 0.22, mat(Color(0.01,0.01,0.012)))
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(sx*(body.size.x*0.52), -body.size.y*0.55, sz*(body.size.z*0.33))
            root.add_child(wheel)
    if player_car:
        var head := box(Vector3(body.size.x*0.82,0.14,0.08), mat(Color(1,0.98,0.82),0.2,Color(1,0.75,0.35)))
        head.position = Vector3(0,0.05,body.size.z*0.52)
        root.add_child(head)
    return root

func _spawn_traffic():
    for n in traffic:
        if is_instance_valid(n): n.queue_free()
    traffic.clear()
    for i in range(12):
        var v := Node3D.new()
        var kind := rng.randi_range(0,2)
        v.add_child(_make_vehicle(kind))
        v.position = Vector3(rng.randf_range(-3.0,3.0),0.8,-60 - i*26)
        v.set_meta("speed", rng.randf_range(12.0,28.0))
        add_child(v)
        traffic.append(v)

func _build_ui():
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)

    speed_label = _label(root, "0 KM/H", Vector2(32,28), 30)
    score_label = _label(root, "SCORE 0", Vector2(32,68), 22)
    health_label = _label(root, "CAR 100%", Vector2(32,100), 22)
    status_label = _label(root, "", Vector2(32,140), 18)

    var left := _button(root,"◀",Vector2(45,570),Vector2(110,90),30)
    left.button_down.connect(func(): lane -= 0.18)
    var right := _button(root,"▶",Vector2(170,570),Vector2(110,90),30)
    right.button_down.connect(func(): lane += 0.18)
    var brake := _button(root,"BRAKE",Vector2(1030,555),Vector2(190,70),24)
    brake.button_down.connect(func(): speed = max(speed-8,0))
    var boost := _button(root,"BOOST",Vector2(1030,640),Vector2(190,60),24)
    boost.button_down.connect(func(): speed = min(speed+20,120))

    menu = Panel.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.modulate = Color(0.035,0.05,0.075,0.96)
    root.add_child(menu)

    var title := _label(menu,"MOUNTAIN TRAFFIC 3D",Vector2(0,70),46)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.size.x = 1280
    var sub := _label(menu,"DANGEROUS ROADS • REAL TRAFFIC • OFFLINE",Vector2(0,135),22)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.size.x = 1280
    var play := _button(menu,"▶  PLAY",Vector2(500,220),Vector2(280,75),30)
    play.pressed.connect(_start_game)
    var garage := _button(menu,"SCORPIO  •  FORTUNER  •  BIKE",Vector2(400,315),Vector2(480,60),18)
    garage.pressed.connect(_cycle_vehicle)
    var mode := _button(menu,"DAY MODE",Vector2(500,395),Vector2(280,55),20)
    mode.pressed.connect(func():
        night = not night
        _set_lighting()
        mode.text = ("NIGHT MODE" if night else "DAY MODE")
    )

func _button(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size",font_size)
    parent.add_child(b)
    return b

func _label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.text=text
    l.position=pos
    l.add_theme_font_size_override("font_size",size)
    parent.add_child(l)
    return l

func _set_lighting():
    if night:
        environment.background_color = Color(0.035,0.055,0.10)
        environment.ambient_light_color = Color(0.55,0.65,0.9)
        environment.ambient_light_energy = 1.0
        sun.light_energy = 0.45
    else:
        environment.background_color = Color(0.32,0.48,0.68)
        environment.ambient_light_color = Color(0.9,0.95,1.0)
        environment.ambient_light_energy = 1.25
        sun.light_energy = 1.8

func _show_menu():
    menu.visible = true
    game_started = false

func _start_game():
    menu.visible = false
    game_started = true
    crashed = false
    health = 100
    speed = 42.0
    distance = 0
    score = 0
    lane = 0
    player.position = Vector3(0,0.8,30)
    _spawn_traffic()
    status_label.text = "DRIVE! USE ◀ ▶ TO STEER"

func _cycle_vehicle():
    selected_vehicle = (selected_vehicle + 1) % 3
    if is_instance_valid(player_body): player_body.queue_free()
    player_body = _make_vehicle(selected_vehicle,true)
    player.add_child(player_body)

func _physics_process(delta):
    if not game_started: return
    if crashed:
        speed = max(speed-delta*30,0)
        if speed <= 0.1:
            status_label.text = "CRASHED — TAP PLAY TO RESTART"
            menu.visible = true
        return

    var steer := Input.get_axis("steer_left","steer_right")
    lane += steer * delta * 2.4
    if Input.is_action_pressed("brake"):
        speed = max(speed-delta*30,0)
    else:
        speed = min(speed + delta*2.0,95.0)
    if Input.is_action_pressed("boost"):
        speed = min(speed + delta*25.0,120.0)
    lane = clamp(lane,-3.0,3.0)
    player.position.x = lerp(player.position.x,lane,delta*6.0)
    player.rotation.z = lerp(player.rotation.z,-steer*0.15,delta*8.0)
    distance += speed*delta*0.01
    score += int(speed*delta)

    for v in traffic:
        if not is_instance_valid(v): continue
        var vs: float = float(v.get_meta("speed"))
        v.position.z += (speed-vs)*delta
        if v.position.z > 55:
            v.position.z = -220-rng.randf_range(0,100)
            v.position.x = rng.randf_range(-3,3)
            score += 50
        if abs(v.position.z-player.position.z) < 2.8 and abs(v.position.x-player.position.x) < 1.4:
            health -= delta*28
            speed *= 0.92
            if health <= 0:
                health = 0
                crashed = true
                status_label.text = "💥 CRASH!"

    speed_label.text = str(int(speed)) + " KM/H"
    score_label.text = "SCORE " + str(score)
    health_label.text = "CAR " + str(int(health)) + "%"
    if not crashed:
        status_label.text = "DISTANCE " + str(snapped(distance,0.1)) + " KM"
