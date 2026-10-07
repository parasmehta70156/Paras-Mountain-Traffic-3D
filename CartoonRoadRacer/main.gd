extends Node2D

const W := 480.0
const H := 854.0
const LANES := [145.0, 240.0, 335.0]
const PLAYER_Y := 680.0

var lane := 1
var traffic: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var road_offset := 0.0
var spawn_timer := 0.0
var coin_timer := 0.0
var speed := 390.0
var score := 0.0
var collected := 0
var game_over := false
var started := false
var best := 0
var touch_start := Vector2.ZERO

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(480, 854)
	best = int(load_best())
	set_process(true)

func load_best() -> int:
	return int(ConfigFile.new().get_value("scores", "best", 0)) if FileAccess.file_exists("user://scores.cfg") else 0

func save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best)
	cfg.save("user://scores.cfg")

func _process(delta: float) -> void:
	if started and not game_over:
		speed = minf(610.0, speed + delta * 2.4)
		score += delta * speed * 0.045
		road_offset = fmod(road_offset + speed * delta, 120.0)
		spawn_timer -= delta
		coin_timer -= delta
		if spawn_timer <= 0.0:
			spawn_traffic()
			spawn_timer = maxf(0.48, 1.05 - score / 950.0) + randf_range(0.05, 0.35)
		if coin_timer <= 0.0:
			coins.append({"lane": randi_range(0, 2), "y": -50.0})
			coin_timer = randf_range(0.9, 1.6)
		for car in traffic:
			car.y += speed * delta
		for coin in coins:
			coin.y += speed * delta
		check_collisions()
		traffic = traffic.filter(func(c): return c.y < H + 100.0)
		coins = coins.filter(func(c): return c.y < H + 40.0 and not c.get("taken", false))
	queue_redraw()

func spawn_traffic() -> void:
	var available := [0, 1, 2]
	if traffic.size() > 0:
		var last: Dictionary = traffic[traffic.size() - 1]
		if last.y < 170.0:
			available.erase(int(last.lane))
	var l := int(available.pick_random())
	traffic.append({"lane": l, "y": -100.0, "color": [Color("#ff595e"), Color("#ffca3a"), Color("#6a4c93"), Color("#1982c4"), Color("#f15bb5")].pick_random()})

func check_collisions() -> void:
	for car in traffic:
		if int(car.lane) == lane and absf(float(car.y) - PLAYER_Y) < 82.0:
			game_over = true
			best = maxi(best, int(score))
			save_best()
	for coin in coins:
		if int(coin.lane) == lane and absf(float(coin.y) - PLAYER_Y) < 55.0:
			coin.taken = true
			collected += 1
			score += 40.0

func move_left() -> void:
	if not game_over:
		started = true
		lane = maxi(0, lane - 1)

func move_right() -> void:
	if not game_over:
		started = true
		lane = mini(2, lane + 1)

func restart() -> void:
	lane = 1
	traffic.clear()
	coins.clear()
	road_offset = 0.0
	spawn_timer = 0.0
	coin_timer = 0.6
	speed = 390.0
	score = 0.0
	collected = 0
	game_over = false
	started = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A: move_left()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D: move_right()
		elif event.keycode == KEY_SPACE and game_over: restart()
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			var dx := event.position.x - touch_start.x
			if game_over:
				if event.position.y > 440.0: restart()
			elif absf(dx) > 28.0:
				if dx < 0: move_left()
				else: move_right()
			elif event.position.x < W * 0.42: move_left()
			else: move_right()
	if event is InputEventMouseButton and event.pressed:
		if game_over:
			restart()
		elif event.position.x < W * 0.42: move_left()
		else: move_right()

func rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)

func draw_car(x: float, y: float, color: Color, player: bool) -> void:
	# Tires and soft cartoon shadow
	draw_rounded_rect(Rect2(x - 31, y - 43, 62, 88), 12, Color(0.08, 0.12, 0.17, 0.38))
	rounded_rect(Rect2(x - 32, y - 42, 64, 84), 12, Color("#20252b"))
	rounded_rect(Rect2(x - 27, y - 47, 54, 94), 13, color)
	# Windscreen, roof and front glass
	rounded_rect(Rect2(x - 20, y - 25, 40, 27), 7, Color("#bdefff"))
	draw_rect(Rect2(x - 17, y - 21, 34, 3), Color(1, 1, 1, 0.75))
	rounded_rect(Rect2(x - 19, y + 9, 38, 18), 5, Color("#243d55"))
	# lights and bumper
	rounded_rect(Rect2(x - 23, y - 43, 14, 7), 3, Color("#fff4bd"))
	rounded_rect(Rect2(x + 9, y - 43, 14, 7), 3, Color("#fff4bd"))
	rounded_rect(Rect2(x - 23, y + 37, 13, 5), 2, Color("#ff4655"))
	rounded_rect(Rect2(x + 10, y + 37, 13, 5), 2, Color("#ff4655"))
	if player:
		draw_circle(Vector2(x, y + 1), 5, Color("#ffffff"))
		draw_circle(Vector2(x, y + 1), 2, Color("#39d98a"))

func _draw() -> void:
	# grassy countryside
	draw_rect(Rect2(0, 0, W, H), Color("#5fbd68"))
	for i in range(9):
		var yy := fmod(float(i * 120) + road_offset * 0.5, H)
		draw_circle(Vector2(24 + (i % 2) * 18, yy), 18, Color("#48a957"))
		draw_circle(Vector2(451 - (i % 3) * 10, fmod(yy + 60, H)), 23, Color("#48a957"))
	# highway and shoulder
	draw_rect(Rect2(66, 0, 348, H), Color("#4b5059"))
	draw_rect(Rect2(66, 0, 9, H), Color("#f8f0ce"))
	draw_rect(Rect2(405, 0, 9, H), Color("#f8f0ce"))
	for yy_i in range(9):
		var yy := fmod(float(yy_i * 120) + road_offset, H)
		draw_rect(Rect2(179, yy, 6, 55), Color("#d8dbe2"))
		draw_rect(Rect2(295, yy, 6, 55), Color("#d8dbe2"))
	# roadside flowers / bushes
	for i in range(8):
		var yy2 := fmod(float(i * 137) + road_offset * 0.8, H)
		draw_circle(Vector2(48, yy2), 7, Color("#ffe66d"))
		draw_circle(Vector2(432, fmod(yy2 + 55, H)), 8, Color("#ff8fab"))
	# traffic and collectible coins
	for car in traffic:
		draw_car(LANES[int(car.lane)], float(car.y), car.color, false)
	for coin in coins:
		if not coin.get("taken", false):
			var cx: float = LANES[int(coin.lane)]
			var cy: float = float(coin.y)
			draw_circle(Vector2(cx, cy), 19, Color("#a96810"))
			draw_circle(Vector2(cx, cy), 15, Color("#ffd447"))
			draw_circle(Vector2(cx - 4, cy - 5), 5, Color("#fff0a1"))
			draw_string(ThemeDB.fallback_font, Vector2(cx - 5, cy + 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#a96810"))
	# player
	draw_car(LANES[lane], PLAYER_Y, Color("#32d6a0"), true)
	# HUD panels
	rounded_rect(Rect2(16, 18, 176, 73), 15, Color(0.06, 0.12, 0.18, 0.83))
	draw_string(ThemeDB.fallback_font, Vector2(30, 45), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#aee8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(30, 76), str(int(score)), HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color.WHITE)
	rounded_rect(Rect2(302, 18, 162, 73), 15, Color(0.06, 0.12, 0.18, 0.83))
	draw_string(ThemeDB.fallback_font, Vector2(318, 45), "COINS  +%d" % collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffd447"))
	draw_string(ThemeDB.fallback_font, Vector2(318, 75), "BEST  %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# touch hint / title overlay
	if not started and not game_over:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.08, 0.12, 0.35))
		rounded_rect(Rect2(32, 275, 416, 240), 26, Color("#102b45"))
		draw_string(ThemeDB.fallback_font, Vector2(58, 328), "CARTOON ROAD RACER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ffe66d"))
		draw_string(ThemeDB.fallback_font, Vector2(65, 374), "Dodge traffic • Collect coins", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(83, 427), "TAP LEFT / RIGHT TO DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#aee8ff"))
		draw_string(ThemeDB.fallback_font, Vector2(130, 471), "Tap anywhere to start", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ffd447"))
	if game_over:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.08, 0.68))
		rounded_rect(Rect2(34, 280, 412, 260), 24, Color("#152b45"))
		draw_string(ThemeDB.fallback_font, Vector2(112, 342), "CRASH! TRY AGAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#ff6978"))
		draw_string(ThemeDB.fallback_font, Vector2(120, 393), "Score: %d" % int(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(120, 430), "Coins: %d" % collected, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd447"))
		rounded_rect(Rect2(105, 462, 270, 54), 15, Color("#32d6a0"))
		draw_string(ThemeDB.fallback_font, Vector2(147, 496), "TAP TO RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#102b45"))
	# large bottom touch zones
	if started and not game_over:
		rounded_rect(Rect2(18, 766, 180, 65), 18, Color(0.05, 0.13, 0.2, 0.55))
		rounded_rect(Rect2(282, 766, 180, 65), 18, Color(0.05, 0.13, 0.2, 0.55))
		draw_string(ThemeDB.fallback_font, Vector2(80, 808), "◀ LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(324, 808), "RIGHT ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
