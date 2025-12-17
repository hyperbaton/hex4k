extends Node2D
class_name Chunk

var chunk_data: ChunkData

func build_from_data(data: ChunkData):
	chunk_data = data

	for local_coord in data.tiles.keys():
		var tile_data: HexTileData = data.tiles[local_coord]

		var tile := HexTile.new()
		tile.setup_from_data(tile_data)

		add_child(tile)
