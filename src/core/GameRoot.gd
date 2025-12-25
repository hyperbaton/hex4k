extends Node

@onready var game := $Game
@onready var registry := $Registry
@onready var world := $World

func _ready():
	#registry.register_data(loader)
	#world.initialize_world()
	print("Game initialized.")
