extends Button

# Called when the node enters the scene tree for the first time.
func _ready():
	self.pressed.connect(_on_save_pressed)

func _on_save_pressed():
	get_node("../../../ChunkManager").save_world()
