## Gera assets/icon/scandig.ico (16, 32, 48, 64, 128 e 256 px, entradas PNG) a partir de
## assets/icon/scandig_icon.svg (#101). Rode depois de mudar o SVG:
##   "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/make_icon.gd
extends SceneTree

const SVG_PATH: String = "res://assets/icon/scandig_icon.svg"
const ICO_PATH: String = "res://assets/icon/scandig.ico"
const SIZES: Array[int] = [16, 32, 48, 64, 128, 256]


func _initialize() -> void:
	var svg: PackedByteArray = FileAccess.get_file_as_bytes(SVG_PATH)
	if svg.is_empty():
		push_error("make_icon: %s não encontrado." % SVG_PATH)
		quit(1)
		return
	var pngs: Array[PackedByteArray] = []
	for size: int in SIZES:
		var img: Image = Image.new()
		var err: Error = img.load_svg_from_buffer(svg, float(size) / 256.0)
		if err != OK or img.get_width() != size:
			push_error("make_icon: falha ao rasterizar %d px (erro %d, %d px)." % [size, err, img.get_width()])
			quit(1)
			return
		pngs.append(img.save_png_to_buffer())
	var ico: PackedByteArray = _build_ico(pngs)
	var file: FileAccess = FileAccess.open(ICO_PATH, FileAccess.WRITE)
	file.store_buffer(ico)
	file.close()
	print("make_icon: %s (%d bytes, %s px)" % [ICO_PATH, ico.size(), str(SIZES)])
	quit(0)


## ICO: cabeçalho de 6 bytes, uma entrada de 16 bytes por tamanho e os PNGs em seguida.
func _build_ico(pngs: Array[PackedByteArray]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(6 + 16 * pngs.size())
	out.encode_u16(0, 0)
	out.encode_u16(2, 1)
	out.encode_u16(4, pngs.size())
	var offset: int = out.size()
	for i: int in pngs.size():
		var size: int = SIZES[i]
		var entry: int = 6 + 16 * i
		out.encode_u8(entry, 0 if size >= 256 else size)
		out.encode_u8(entry + 1, 0 if size >= 256 else size)
		out.encode_u8(entry + 2, 0)
		out.encode_u8(entry + 3, 0)
		out.encode_u16(entry + 4, 1)
		out.encode_u16(entry + 6, 32)
		out.encode_u32(entry + 8, pngs[i].size())
		out.encode_u32(entry + 12, offset)
		offset += pngs[i].size()
	for png: PackedByteArray in pngs:
		out.append_array(png)
	return out
