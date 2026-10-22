
extends Node

var game
var ui
var sw_start := Vector2.ZERO
var sw_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = preload("res://scripts/game.gd").new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	ui = preload("res://scripts/ui.gd").new()
	add_child(ui)
	ui.setup(game)

func _input(e: InputEvent) -> void:
	if game.mode != "run" or get_tree().paused:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			sw_start = e.position
			sw_active = true
		else:
			sw_active = false
	elif e is InputEventScreenDrag and sw_active:
		var d: Vector2 = e.position - sw_start
		if d.length() > 55.0:
			if absf(d.x) > absf(d.y):
				if d.x > 0.0:
					game.move_right()
				else:
					game.move_left()
			else:
				if d.y < 0.0:
					game.do_jump()
				else:
					game.do_roll()
			sw_active = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				game.move_left()
			KEY_RIGHT, KEY_D:
				game.move_right()
			KEY_UP, KEY_W, KEY_SPACE:
				game.do_jump()
			KEY_DOWN, KEY_S:
				game.do_roll()
