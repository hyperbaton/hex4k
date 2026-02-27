extends Node

enum Mode { NEW_GAME, LOAD_GAME }

var mode: Mode = Mode.NEW_GAME
var save_id: String = ""
var save_display_name: String = ""
var world_seed: int = 12345

func start_new_game(seed: int):
	mode = Mode.NEW_GAME
	world_seed = seed
	save_id = ""
	save_display_name = ""

func load_game(save: String):
	mode = Mode.LOAD_GAME
	save_id = save
