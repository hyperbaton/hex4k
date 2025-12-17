extends Control

func _ready():
	$CenterContainer/VBoxContainer/ButtonNewGame.pressed.connect(_on_new_game)
	$CenterContainer/VBoxContainer/ButtonQuit.pressed.connect(_on_quit)
	$CenterContainer/VBoxContainer/ButtonLoadGame.pressed.connect(_on_load_game)

func _on_new_game():
	GameState.start_new_game(randi())
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_quit():
	get_tree().quit()

func _on_load_game():
	GameState.load_game("save_001")
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")
	
