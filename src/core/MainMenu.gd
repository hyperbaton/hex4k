extends Control

func _ready():
	$ButtonContainer/ButtonNewGame.pressed.connect(_on_new_game)
	$ButtonContainer/ButtonLoadGame.pressed.connect(_on_load_game)
	$ButtonContainer/ButtonQuit.pressed.connect(_on_quit)

	$VersionLabel.text = GameConfig.VERSION

func _on_new_game():
	GameState.start_new_game(randi())
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_quit():
	get_tree().quit()

func _on_load_game():
	GameState.load_game("save_001")
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")
