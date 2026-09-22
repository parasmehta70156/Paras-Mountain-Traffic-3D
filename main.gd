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
var rain := true
var night := true
var traffic: Array[Node3D] = []
var game_started := false
var crashed := false
var rng := RandomNumberGenerator.new()
var speed_label: Label
var score_label: Label
var health_label: Label
var status_label: Label
var menu: Control

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
        m.emission_energy_multiplier = 2.0
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
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.015,0.02,0.035)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.30,0.34,0.45)
    e.ambient_light_energy = 0.55
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-45,-25,0)
    sun.light_energy = 0.65
    sun.shadow_enabled = true
    add_child(sun)

    var moon := OmniLight3D.new()
    moon.position = Vector3(0,18,15)
    moon.light_color = Color(0.25,0.35,0.65)
    moon.light_energy = 4.0
    moon.omni_range = 70
    add_child(moon)

    for z in range(-180, 260, 20):
        var road := box(Vector3(10,0.35,20), mat(Color(0.035,0.04,0.045)))
        road.position = Vector3(0,-0.2,z)
        add_child(road)
        for x in [-3.2,3.2]:
            var barrier := box(Vector3(0.18,0.9,20), mat(Color(0.8,0.75,0.58)))
            barrier.position = Vector3(x,0.25,z)
            add_child(barrier)
        for x in [-1.65,1.65]:
            var line := box(Vector3(0.12,0.03,5.0), mat(Color(0.95,0.9,0.35)))
            line.position = Vector3(x,0.02,z)
            add_child(line)
        _add_mountain_pair(z)

    for i in range(5):
        var slab := box(Vector3(2.2,0.3,5.0), mat(Color(0.22,0.23,0.24)))
        slab.position = Vector3(-3.9 + i*2.0, -0.05, 125 + i*0.6)
        slab.rotation_degrees.y = -3 if i%2==0 else 4
        add_child(slab)

    player = Node3D.new()
    player.position = Vector3(0,0.8,30)
    add_child(player)
    player_body = _make_vehicle(selected_vehicle, true)
    player.add_child(player_body)

    camera = Camera3D.new()
    camera.position = Vector3(0,5.0,10.0)
    camera.rotation_degrees = Vector3(-12,180,0)
    player.add_child(camera)
    camera.current = true

func _add_mountain_pair(z: float):
    for side in [-1,1]:
        var h := rng.randf_range(12,28)
        var mountain := cyl(rng.randf_range(5.0,8.0), h, mat(Color(0.07,0.085,0.11)))
        mountain.position = Vector3(side*rng.randf_range(10,17), h/2.0-0.2, z+rng.randf_range(-7,7))
        mountain.scale.x = 1.4
        mountain.scale.z = 1.3
        add_child(mountain)

func _make_vehicle(kind: int, player_car := false) -> MeshInstance3D:
    var root := MeshInstance3D.new()
    var body := BoxMesh.new()
    if kind == 0:
        body.size = Vector3(1.9,0.8,3.6)
        root.material_override = mat(Color(0.06,0.07,0.08))
    elif kind == 1:
        body.size = Vector3(2.0,0.9,3.7)
        root.material_override = mat(Color(0.88,0.88,0.9))
    else:
        body.size = Vector3(0.8,0.55,2.2)
        root.material_override = mat(Color(0.65,0.05,0.03))
    root.mesh = body
    var cabin := box(Vector3(body.size.x*0.72, body.size.y*0.72, body.size.z*0.42), mat(Color(0.04,0.09,0.12),0.35))
    cabin.position.y = body.size.y*0.62
    root.add_child(cabin)
    for sx in [-1,1]:
        for sz in [-1,1]:
            var wheel := cyl(0.28 if kind<2 else 0.18, 0.22, mat(Color(0.01,0.01,0.012)))
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(sx*(body.size.x*0.52), -body.size.y*0.55, sz*(body.size.z*0.33))
            root.add_child(wheel)
    if player_car:
        var head := box(Vector3(body.size.x*0.82,0.12,0.08), mat(Color(0.95,0.98,1),0.2,Color(0.5,0.7,1)))
        head.position = Vector3(0,0.05,body.size.z*0.52)
        root.add_child(head)
    return root

func _spawn_traffic():
    for n in traffic:
        if is_instance_valid(n): n.queue_free()
    traffic.clear()
    for i in range(10):
        var v := Node3D.new()
        var kind := rng.randi_range(0,2)
        var body := _make_vehicle(kind)
        v.add_child(body)
        v.position = Vector3(rng.randf_range(-3.0,3.0),0.8,-80 - i*24)
        v.set_meta("speed", rng.randf_range(4.0,10.0))
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

    for data in [["◀",Vector2(45,570),Vector2(100,100)], ["▶",Vector2(160,570),Vector2(100,100)], ["BRAKE",Vector2(1030,570),Vector2(180,70)], ["BOOST",Vector2(1030,650),Vector2(180,50)]]:
        var b := Button.new()
        b.text = data[0]
        b.position = data[1]
        b.size = data[2]
        b.add_theme_font_size_override("font_size", 24)
        root.add_child(b)
        if data[0] == "◀": b.button_down.connect(func(): lane -= 0.06)
        elif data[0] == "▶": b.button_down.connect(func(): lane += 0.06)
        elif data[0] == "BRAKE": b.button_down.connect(func(): speed = max(speed-3,0))
        else: b.button_down.connect(func(): speed = min(speed+10,120))

    menu = Panel.new()
    menu.position = Vector2(0,0)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.modulate = Color(0.02,0.025,0.04,0.94)
    root.add_child(menu)

    var title := _label(menu,"MOUNTAIN TRAFFIC 3D",Vector2(0,70),46)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.size.x = 1280
    var sub := _label(menu,"DANGEROUS ROADS • REAL TRAFFIC • OFFLINE",Vector2(0,130),22)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.size.x = 1280
    var play := Button.new(); play.text = "PLAY"; play.position=Vector2(500,220); play.size=Vector2(280,70); play.add_theme_font_size_override("font_size",30); menu.add_child(play); play.pressed.connect(_start_game)
    var garage := Button.new(); garage.text = "SCORPIO  •  FORTUNER  •  BIKE"; garage.position=Vector2(400,310); garage.size=Vector2(480,55); garage.add_theme_font_size_override("font_size",18); menu.add_child(garage); garage.pressed.connect(_cycle_vehicle)
    var mode := Button.new(); mode.text = "RAIN / NIGHT: ON"; mode.position=Vector2(500,390); mode.size=Vector2(280,55); menu.add_child(mode); mode.pressed.connect(func(): rain = not rain; night = not night; mode.text = ("RAIN / NIGHT: ON" if rain else "RAIN / NIGHT: OFF"))

func _label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new(); l.text=text; l.position=pos; l.add_theme_font_size_override("font_size",size); parent.add_child(l); return l

func _show_menu():
    menu.visible = true
    game_started = false

func _start_game():
    menu.visible = false
    game_started = true
    crashed = false
    health = 100
    speed = 0
    distance = 0
    score = 0
    lane = 0
    player.position = Vector3(0,0.8,30)
    _spawn_traffic()

func _cycle_vehicle():
    selected_vehicle = (selected_vehicle + 1) % 3
    if is_instance_valid(player_body): player_body.queue_free()
    player_body = _make_vehicle(selected_vehicle,true)
    player.add_child(player_body)

func _physics_process(delta):
    if not game_started: return
    if crashed:
        speed = max(speed-delta*20,0)
        if speed <= 0.1:
            status_label.text = "CRASHED — TAP PLAY TO RESTART"
            menu.visible = true
        return

    var steer := Input.get_axis("steer_left","steer_right")
    lane += steer * delta * 2.4
    if Input.is_action_pressed("brake"): speed = max(speed-delta*30,0)
    else: speed = min(speed + delta*7.0, 95.0)
    if Input.is_action_pressed("boost"): speed = min(speed + delta*25.0, 120.0)
    lane = clamp(lane,-3.0,3.0)
    player.position.x = lerp(player.position.x,lane,delta*6.0)
    player.rotation.z = lerp(player.rotation.z,-steer*0.15,delta*8.0)
    distance += speed*delta*0.01
    score += int(speed*delta)

    for v in traffic:
        if not is_instance_valid(v): continue
        var vs: float = float(v.get_meta("speed"))
        v.position.z += (speed-vs)*delta
        if v.position.z > 50:
            v.position.z = -180-rng.randf_range(0,100)
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
    status_label.text = "DISTANCE " + str(snapped(distance,0.1)) + " KM"
