extends Control

func _ready():
	$CenterContainer/VBoxContainer/ButtonNewGame.pressed.connect(_on_new_game)
	$CenterContainer/VBoxContainer/ButtonQuit.pressed.connect(_on_quit)

func _on_new_game():
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_quit():
	get_tree().quit()
