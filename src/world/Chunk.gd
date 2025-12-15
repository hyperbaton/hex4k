extends Node2D
class_name Chunk

var chunk_q: int
var chunk_r: int

func generate(generator: TileGenerator):
	for q in range(WorldConfig.CHUNK_SIZE):
		for r in range(WorldConfig.CHUNK_SIZE):
			var world_q = chunk_q * WorldConfig.CHUNK_SIZE + q
			var world_r = chunk_r * WorldConfig.CHUNK_SIZE + r

			var tile := generator.generate_tile(world_q, world_r)
			add_child(tile)
