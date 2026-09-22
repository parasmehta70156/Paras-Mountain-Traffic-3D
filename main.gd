extends Node3D

# Paras Mountain Traffic 3D - mobile friendly procedural 3D build
var player: Node3D
var player_body: Node3D
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
var road_segments: Array[Node3D] = []
var game_started := false
var crashed := false
var rng := RandomNumberGenerator.new()
var speed_label: Label
var score_label: Label
var health_label: Label
var status_label: Label
var menu: Control
var env_node: WorldEnvironment
var environment: Environment
var sun: DirectionalLight3D
var headlight_l: SpotLight3D
var headlight_r: SpotLight3D
var rain_particles: GPUParticles3D

func _ready():
    rng.seed = 70156
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
        m.emission_energy_multiplier = 2.2
    return m

func box(size: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = size
    n.mesh = b
    n.material_override = material
    return n

func cyl(radius: float, height: float, material: Material, top_radius := -1.0) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = radius if top_radius < 0.0 else top_radius
    c.bottom_radius = radius
    c.height = height
    n.mesh = c
    n.material_override = material
    return n

func _build_world():
    env_node = WorldEnvironment.new()
    environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.28,0.43,0.60)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.82,0.9,1.0)
    environment.ambient_light_energy = 1.35
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.25
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.52,0.63,0.70)
    environment.fog_light_energy = 0.42
    environment.fog_density = 0.004
    env_node.environment = environment
    add_child(env_node)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-28,0)
    sun.light_color = Color(1.0,0.92,0.78)
    sun.light_energy = 1.9
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 180
    add_child(sun)

    _build_road()
    _build_mountains()
    _build_decor()

    player = Node3D.new()
    player.position = Vector3(0,0.72,24)
    add_child(player)
    player_body = _make_vehicle(selected_vehicle, true)
    player.add_child(player_body)

    camera = Camera3D.new()
    camera.position = Vector3(0,4.5,8.8)
    camera.rotation_degrees = Vector3(-9,180,0)
    camera.fov = 67
    player.add_child(camera)
    camera.current = true

    headlight_l = _headlight(Vector3(-0.65,0.65,1.7))
    headlight_r = _headlight(Vector3(0.65,0.65,1.7))
    player.add_child(headlight_l)
    player.add_child(headlight_r)

func _build_road():
    for i in range(-16, 28):
        var z := float(i * 18)
        var bend := sin(float(i) * 0.34) * 4.0 + sin(float(i) * 0.12) * 3.0
        var seg := Node3D.new()
        seg.position = Vector3(bend,-0.18,z)
        seg.rotation.y = -cos(float(i) * 0.34) * 0.055
        add_child(seg)
        road_segments.append(seg)
        seg.add_child(box(Vector3(12.5,0.34,18.5), mat(Color(0.055,0.062,0.068),0.9)))
        for x in [-6.15,6.15]:
            var edge := box(Vector3(0.20,0.50,18.5), mat(Color(0.64,0.66,0.62),0.65))
            edge.position = Vector3(x,0.18,0)
            seg.add_child(edge)
        var center := box(Vector3(0.13,0.05,4.8), mat(Color(0.92,0.82,0.36),0.5,Color(0.12,0.09,0.01)))
        center.position = Vector3(0,0.2,-4.5)
        seg.add_child(center)

func _build_mountains():
    for i in range(-18, 32):
        var z := float(i * 16)
        for side in [-1,1]:
            var h := rng.randf_range(16.0,34.0)
            var mountain := cyl(rng.randf_range(5.0,9.0),h,mat(Color(0.10,0.15,0.18),0.98),0.35)
            mountain.position = Vector3(side*rng.randf_range(12.0,23.0),h*0.5-0.25,z+rng.randf_range(-8,8))
            mountain.scale.x = rng.randf_range(1.0,1.7)
            mountain.scale.z = rng.randf_range(0.9,1.5)
            add_child(mountain)
            var snow := cyl(0.9,h*0.30,mat(Color(0.78,0.83,0.85),0.95),0.05)
            snow.position = mountain.position + Vector3(0,h*0.33,0)
            snow.scale.x = mountain.scale.x*0.65
            snow.scale.z = mountain.scale.z*0.65
            add_child(snow)

func _build_decor():
    for i in range(-12,24):
        var z := float(i*22)
        var bend := sin(float(i)*0.34)*4.0 + sin(float(i)*0.12)*3.0
        for side in [-1,1]:
            var pole := cyl(0.055,1.8,mat(Color(0.14,0.15,0.15)))
            pole.position = Vector3(bend + side*6.7,0.9,z+8)
            add_child(pole)
            var lamp := box(Vector3(0.25,0.16,0.25),mat(Color(1,0.72,0.28),0.2,Color(1,0.55,0.15)))
            lamp.position = pole.position + Vector3(0,0.9,0)
            add_child(lamp)

func _headlight(pos: Vector3) -> SpotLight3D:
    var l := SpotLight3D.new()
    l.position = pos
    l.rotation_degrees = Vector3(0,180,0)
    l.light_color = Color(1.0,0.94,0.78)
    l.light_energy = 0.0
    l.spot_range = 24
    l.spot_angle = 32
    l.shadow_enabled = true
    return l

func _make_vehicle(kind: int, player_car := false) -> Node3D:
    var root := Node3D.new()
    var body_size := Vector3(2.0,0.72,3.8)
    var color := Color(0.035,0.04,0.045)
    if kind == 1:
        body_size = Vector3(2.08,0.80,3.95)
        color = Color(0.88,0.88,0.90)
    elif kind == 2:
        body_size = Vector3(0.72,0.50,2.45)
        color = Color(0.78,0.05,0.025)
    var body := box(body_size,mat(color,0.40))
    root.add_child(body)
    body.position.y = 0.65
    if kind < 2:
        var cabin := box(Vector3(body_size.x*0.72,0.65,body_size.z*0.44),mat(Color(0.035,0.09,0.12),0.18))
        cabin.position = Vector3(0,1.17,-0.08)
        root.add_child(cabin)
        var hood := box(Vector3(body_size.x*0.84,0.18,body_size.z*0.20),mat(color,0.36))
        hood.position = Vector3(0,0.98,1.25)
        root.add_child(hood)
        var grille := box(Vector3(body_size.x*0.52,0.24,0.08),mat(Color(0.02,0.02,0.02),0.3))
        grille.position = Vector3(0,0.70,2.0)
        root.add_child(grille)
        for sx in [-1,1]:
            var light := box(Vector3(0.34,0.14,0.10),mat(Color(1,0.9,0.65),0.18,Color(1,0.6,0.2)))
            light.position = Vector3(sx*0.62,0.84,1.94)
            root.add_child(light)
        for sx in [-1,1]:
            for sz in [-1,1]:
                var wheel := cyl(0.31,0.24,mat(Color(0.008,0.009,0.01),0.98))
                wheel.rotation_degrees.z = 90
                wheel.position = Vector3(sx*(body_size.x*0.54),0.34,sz*(body_size.z*0.34))
                root.add_child(wheel)
    else:
        var tank := box(Vector3(0.60,0.32,0.78),mat(Color(0.04,0.04,0.05),0.34))
        tank.position = Vector3(0,1.0,0.10)
        root.add_child(tank)
        var seat := box(Vector3(0.45,0.18,0.55),mat(Color(0.015,0.015,0.018),0.8))
        seat.position = Vector3(0,1.17,-0.42)
        root.add_child(seat)
        for z in [-0.78,0.78]:
            var wheel := cyl(0.29,0.12,mat(Color(0.01,0.01,0.012)))
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(0,0.34,z)
            root.add_child(wheel)
        var handle := box(Vector3(0.82,0.08,0.10),mat(Color(0.07,0.07,0.08)))
        handle.position = Vector3(0,1.37,0.62)
        root.add_child(handle)
    if player_car:
        var plate := box(Vector3(min(body_size.x*0.50,0.85),0.13,0.05),mat(Color(0.92,0.92,0.88),0.6))
        plate.position = Vector3(0,0.57,-body_size.z*0.52)
        root.add_child(plate)
    return root

func _spawn_traffic():
    for n in traffic:
        if is_instance_valid(n): n.queue_free()
    traffic.clear()
    for i in range(15):
        var v := Node3D.new()
        var kind := rng.randi_range(0,2)
        v.add_child(_make_vehicle(kind))
        var z := -70.0 - i*24.0
        var bend := sin(z*0.018)*4.0 + sin(z*0.006)*3.0
        v.position = Vector3(bend+rng.randf_range(-2.7,2.7),0.0,z)
        v.set_meta("speed",rng.randf_range(18.0,42.0))
        add_child(v)
        traffic.append(v)

func _build_ui():
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    speed_label = _label(root,"0 KM/H",Vector2(30,25),30)
    score_label = _label(root,"SCORE 0",Vector2(30,65),21)
    health_label = _label(root,"CAR 100%",Vector2(30,96),21)
    status_label = _label(root,"",Vector2(30,128),18)
    var left := _button(root,"◀",Vector2(35,560),Vector2(115,88),32)
    left.button_down.connect(func(): lane -= 0.55)
    var right := _button(root,"▶",Vector2(165,560),Vector2(115,88),32)
    right.button_down.connect(func(): lane += 0.55)
    var brake := _button(root,"BRAKE",Vector2(1030,555),Vector2(190,70),22)
    brake.button_down.connect(func(): speed=max(speed-12,0))
    var boost := _button(root,"BOOST",Vector2(1030,635),Vector2(190,70),22)
    boost.button_down.connect(func(): speed=min(speed+22,125))

func _button(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int)->Button:
    var b:=Button.new()
    b.text=text
    b.position=pos
    b.size=size
    b.add_theme_font_size_override("font_size",font_size)
    parent.add_child(b)
    return b

func _label(parent: Node,text: String,pos: Vector2,size: int)->Label:
    var l:=Label.new()
    l.text=text
    l.position=pos
    l.add_theme_font_size_override("font_size",size)
    l.add_theme_color_override("font_color",Color(1,1,1))
    parent.add_child(l)
    return l

func _set_lighting():
    if night:
        environment.background_color=Color(0.015,0.025,0.055)
        environment.ambient_light_color=Color(0.35,0.45,0.70)
        environment.ambient_light_energy=0.78
        environment.fog_light_color=Color(0.10,0.16,0.28)
        environment.fog_density=0.009
        sun.light_energy=0.25
        headlight_l.light_energy=5.0
        headlight_r.light_energy=5.0
    else:
        environment.background_color=Color(0.28,0.43,0.60)
        environment.ambient_light_color=Color(0.82,0.90,1.0)
        environment.ambient_light_energy=1.35
        environment.fog_light_color=Color(0.52,0.63,0.70)
        environment.fog_density=0.004
        sun.light_energy=1.9
        headlight_l.light_energy=0.0
        headlight_r.light_energy=0.0

func _set_rain(enabled: bool):
    rain=enabled
    if enabled and rain_particles==null:
        rain_particles=GPUParticles3D.new()
        rain_particles.amount=260
        rain_particles.lifetime=1.2
        rain_particles.visibility_aabb=AABB(Vector3(-18,-2,-28),Vector3(36,20,56))
        var pm:=ParticleProcessMaterial.new()
        pm.direction=Vector3(0,-1,0)
        pm.initial_velocity_min=22
        pm.initial_velocity_max=34
        pm.gravity=Vector3(0,-12,0)
        pm.scale_min=0.025
        pm.scale_max=0.04
        var mesh:=QuadMesh.new()
        mesh.size=Vector2(0.035,0.65)
        mesh.material=mat(Color(0.55,0.72,0.95,0.55),0.2,Color(0.18,0.25,0.4))
        rain_particles.process_material=pm
        rain_particles.draw_pass_1=mesh
        player.add_child(rain_particles)
    if rain_particles:
        rain_particles.emitting=enabled
    if enabled:
        environment.fog_density=0.012
        environment.fog_light_color=Color(0.40,0.50,0.58)
    else:
        environment.fog_density=0.009 if night else 0.004

func _show_menu():
    menu=null
    game_started=false

func _start_game():
    game_started=true
    crashed=false
    health=100
    speed=48.0
    distance=0
    score=0
    lane=0
    player.position=Vector3(0,0.72,24)
    _spawn_traffic()
    status_label.text="DRIVE • STEER • SURVIVE"

func select_vehicle(kind: int):
    selected_vehicle=clamp(kind,0,2)
    if is_instance_valid(player_body): player_body.queue_free()
    player_body=_make_vehicle(selected_vehicle,true)
    player.add_child(player_body)

func _cycle_vehicle():
    select_vehicle((selected_vehicle+1)%3)

func _physics_process(delta):
    if not game_started:
        return
    if crashed:
        speed=max(speed-delta*28,0)
        if speed<=0.1:
            status_label.text="CRASHED • TAP PLAY TO RESTART"
        return
    var steer:=Input.get_axis("steer_left","steer_right")
    lane+=steer*delta*3.2
    if Input.is_action_pressed("brake"):
        speed=max(speed-delta*34,0)
    else:
        speed=min(speed+delta*2.4,105)
    if Input.is_action_pressed("boost"):
        speed=min(speed+delta*28,125)
    lane=clamp(lane,-4.4,4.4)
    player.position.x=lerp(player.position.x,lane,delta*7.0)
    player.rotation.z=lerp(player.rotation.z,-steer*0.10,delta*8.0)
    distance+=speed*delta*0.01
    score+=int(speed*delta)
    for v in traffic:
        if not is_instance_valid(v): continue
        var vs:float=float(v.get_meta("speed"))
        v.position.z+=(speed-vs)*delta
        v.position.x=sin(v.position.z*0.018)*4.0+sin(v.position.z*0.006)*3.0+rng.randf_range(-0.05,0.05)
        if v.position.z>55:
            v.position.z=-270-rng.randf_range(0,90)
            score+=75
        if abs(v.position.z-player.position.z)<2.9 and abs(v.position.x-player.position.x)<1.45:
            health-=delta*42
            speed*=0.91
            if health<=0:
                health=0
                crashed=true
                status_label.text="💥 CRASH!"
    speed_label.text=str(int(speed))+" KM/H"
    score_label.text="SCORE "+str(score)
    health_label.text="CAR "+str(int(health))+"%"
    if not crashed:
        status_label.text="DISTANCE "+str(snapped(distance,0.1))+" KM"
