extends Node2D

var car_x := 640.0
var speed := 0.0
var road_offset := 0.0
var traffic := [380.0, 540.0, 760.0, 900.0]
var started := false
var rng := RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    queue_redraw()

func _process(delta):
    if started:
        speed = min(speed + delta * 180.0, 520.0)
        road_offset = fmod(road_offset + speed * delta, 160.0)
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): car_x -= 300.0 * delta
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): car_x += 300.0 * delta
        car_x = clamp(car_x, 250.0, 1030.0)
    queue_redraw()

func _input(event):
    if event is InputEventScreenTouch and event.pressed:
        if not started:
            started = true
        elif event.position.x < 640:
            car_x -= 90
        else:
            car_x += 90
    if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
        started = true

func _draw():
    var s = get_viewport_rect().size
    # sky and mountains
    draw_rect(Rect2(Vector2.ZERO, s), Color("#111827"))
    draw_colored_polygon(PackedVector2Array([Vector2(0,430),Vector2(180,230),Vector2(330,390),Vector2(500,170),Vector2(700,400),Vector2(880,210),Vector2(1100,390),Vector2(1280,250),Vector2(1280,720),Vector2(0,720)]), Color("#26374a"))
    draw_colored_polygon(PackedVector2Array([Vector2(0,500),Vector2(220,300),Vector2(420,470),Vector2(610,250),Vector2(820,470),Vector2(1040,280),Vector2(1280,470),Vector2(1280,720),Vector2(0,720)]), Color("#182536"))
    # road
    draw_colored_polygon(PackedVector2Array([Vector2(250,720),Vector2(430,300),Vector2(850,300),Vector2(1030,720)]), Color("#20242a"))
    for y in range(-160, 900, 160):
        var yy = y + road_offset
        draw_rect(Rect2(Vector2(632, yy), Vector2(16, 75)), Color("#f4f4f5"))
    # road edges
    draw_line(Vector2(430,300),Vector2(250,720),Color("#f59e0b"),6)
    draw_line(Vector2(850,300),Vector2(1030,720),Color("#f59e0b"),6)
    # traffic cars
    for i in traffic.size():
        var x = traffic[i]
        var y = 300.0 + float(i) * 90.0 + fmod(road_offset * (0.35 + i*0.08), 300.0)
        draw_rect(Rect2(Vector2(x-32,y-22),Vector2(64,44)),Color("#dc2626") if i%2==0 else Color("#f8fafc"),true)
        draw_circle(Vector2(x-20,y+23),7,Color("#050505"))
        draw_circle(Vector2(x+20,y+23),7,Color("#050505"))
    # player SUV
    var py = 600.0
    draw_rect(Rect2(Vector2(car_x-55,py-45),Vector2(110,90)),Color("#111111"),true)
    draw_rect(Rect2(Vector2(car_x-38,py-28),Vector2(76,32)),Color("#334155"),true)
    draw_circle(Vector2(car_x-42,py+42),12,Color("#050505"))
    draw_circle(Vector2(car_x+42,py+42),12,Color("#050505"))
    draw_rect(Rect2(Vector2(car_x-35,py-8),Vector2(70,8)),Color("#ef4444"),true)
    if not started:
        draw_rect(Rect2(Vector2(0,0),s),Color(0,0,0,0.35))
        draw_string(ThemeDB.fallback_font,Vector2(440,150),"PARAS MOUNTAIN TRAFFIC 3D",HORIZONTAL_ALIGNMENT_LEFT,700,42,Color("#ffffff"))
        draw_string(ThemeDB.fallback_font,Vector2(470,210),"TAP TO START • OFFLINE",HORIZONTAL_ALIGNMENT_LEFT,600,26,Color("#fbbf24"))
        draw_string(ThemeDB.fallback_font,Vector2(430,660),"◀ STEER LEFT        STEER RIGHT ▶",HORIZONTAL_ALIGNMENT_LEFT,700,24,Color("#ffffff"))
