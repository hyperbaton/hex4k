extends RefCounted
class_name ChunkData

var coord: Vector2i  # (chunk_q, chunk_r)
var tiles := {}      # Dictionary<Vector2i, TileData>

static func save_chunk(chunk: ChunkData, path: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	print(FileAccess.get_open_error())
	file.store_16(chunk.coord.x)
	file.store_16(chunk.coord.y)

	file.store_32(chunk.tiles.size())

	for tile in chunk.tiles.values():
		tile.write_tile(file, tile)

	file.close()

static func load_chunk(path: String) -> ChunkData:
	var file = FileAccess.open(path, FileAccess.READ)

	var chunk := ChunkData.new()
	chunk.coord = Vector2i(file.get_16(), file.get_16())

	var count = file.get_32()
	for i in count:
		var tile = HexTileData.read_tile(file)
		var local = Vector2i(
			tile.q - chunk.coord.x * WorldConfig.CHUNK_SIZE,
			tile.r - chunk.coord.y * WorldConfig.CHUNK_SIZE
		)
		chunk.tiles[local] = tile

	file.close()
	return chunk
