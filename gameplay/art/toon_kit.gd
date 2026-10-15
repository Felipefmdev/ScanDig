@tool
class_name ToonKit
extends RefCounted

## Kit de materiais toon do ScanDig (docs/GAME_DESIGN.md §2, #36). Materiais em
## res://assets/materials/toon/ (shader res://world/shaders/toon.gdshader + contorno preto em
## next_pass). Uso típico num modelo procedural:
##   var mi := MeshInstance3D.new()
##   mi.mesh = ToonKit.commit(st)                    # malha + normais suavizadas p/ o contorno
##   mi.material_override = ToonKit.vertex_material()
## Materiais com desgaste: ToonKit.material(&"metal_rust" | &"wood" | &"paint_red" |
## &"paint_green" | &"carapace"). Cada chamada devolve uma cópia (pode-se mudar parâmetros e
## animar flash_amount sem afetar os outros); o next_pass do contorno é partilhado.
## Modelos importados (Kenney): ToonKit.apply_to_imported(raiz) troca os materiais.

const DIR: String = "res://assets/materials/toon/"
const KINDS: Array[StringName] = [
	&"vertex", &"terrain", &"foliage", &"grass",
	&"metal_rust", &"wood", &"paint_red", &"paint_green", &"carapace",
]
const OUTLINE: Material = preload("res://assets/materials/toon/outline.tres")
const OUTLINE_CARD: Material = preload("res://assets/materials/toon/outline_card.tres")
## Peças importadas finas (cartões): toon de dupla face e sem contorno. Procura-se no nome do nó
## e no ficheiro do modelo (os Kenney pirata vêm todos com cull desligado, mesmo os fechados).
const THIN_NAME_HINTS: Array[String] = ["grass", "flower", "flat", "leaf", "leaves", "sail", "flag"]
## Precisão (m) com que vértices na mesma posição se juntam ao suavizar as normais.
const WELD_STEP: float = 0.0005

## Kenney: malha original -> malha com normais do contorno; material original -> toon.
static var _baked_meshes: Dictionary = {}
static var _converted_mats: Dictionary = {}


## Cópia de um material do kit (ver KINDS).
static func material(kind: StringName) -> ShaderMaterial:
	var base: ShaderMaterial = load(DIR + String(kind) + ".tres") as ShaderMaterial
	return base.duplicate() as ShaderMaterial


## Material toon com cor por vértice. srgb = as cores dos vértices estão em sRGB (cenário);
## os inimigos antigos usam cores lineares (srgb = false) para manter o tom.
static func vertex_material(outline: bool = true, srgb: bool = true) -> ShaderMaterial:
	var mat: ShaderMaterial = material(&"vertex")
	mat.set_shader_parameter(&"vertex_color_srgb", srgb)
	if not outline:
		mat.next_pass = null
	return mat


## SurfaceTool -> ArrayMesh com as normais suavizadas em CUSTOM0 (o contorno fica sem buracos
## nas arestas duras). card = true para folhas de dupla face (direção no plano do triângulo).
static func commit(st: SurfaceTool, card: bool = false) -> ArrayMesh:
	return bake_outline_normals(st.commit(), card)


## Copia `src` acrescentando CUSTOM0 (RGB float) com a direção do contorno de cada vértice.
static func bake_outline_normals(src: Mesh, card: bool = false) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	if src == null:
		return out
	for s: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var dirs: PackedVector3Array = _card_dirs(verts, indices) if card else _smooth_dirs(verts, normals)
		var custom: PackedFloat32Array = PackedFloat32Array()
		custom.resize(verts.size() * 3)
		for i: int in verts.size():
			custom[i * 3] = dirs[i].x
			custom[i * 3 + 1] = dirs[i].y
			custom[i * 3 + 2] = dirs[i].z
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var fmt: int = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, [], {}, fmt)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	return out


static func _smooth_dirs(verts: PackedVector3Array, normals: PackedVector3Array) -> PackedVector3Array:
	# Por posição soldada: soma das normais de face DIFERENTES (um quad são 2 triângulos com a
	# mesma normal; contá-la duas vezes entortava o casco nos cantos).
	var faces: Dictionary = {}
	var keys: Array[Vector3i] = []
	keys.resize(verts.size())
	var has_normals: bool = normals.size() == verts.size()
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var key: Vector3i = Vector3i(roundi(v.x / WELD_STEP), roundi(v.y / WELD_STEP), roundi(v.z / WELD_STEP))
		keys[i] = key
		if not has_normals:
			continue
		var n: Vector3 = normals[i]
		if not faces.has(key):
			faces[key] = PackedVector3Array([n])
			continue
		var list: PackedVector3Array = faces[key]
		var seen: bool = false
		for m: Vector3 in list:
			if m.dot(n) > 0.999:
				seen = true
				break
		if not seen:
			list.append(n)
			faces[key] = list
	var acc: Dictionary = {}
	for key: Vector3i in faces:
		var total: Vector3 = Vector3.ZERO
		for m: Vector3 in (faces[key] as PackedVector3Array):
			total += m
		acc[key] = total
	var dirs: PackedVector3Array = PackedVector3Array()
	dirs.resize(verts.size())
	for i: int in verts.size():
		var sum: Vector3 = acc.get(keys[i], Vector3.ZERO)
		if sum.length_squared() > 1e-8:
			dirs[i] = sum.normalized()
		elif has_normals:
			dirs[i] = normals[i]
	return dirs


static func _card_dirs(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var dirs: PackedVector3Array = PackedVector3Array()
	dirs.resize(verts.size())
	var count: int = indices.size() if not indices.is_empty() else verts.size()
	@warning_ignore("integer_division")
	var tri_count: int = count / 3
	for t: int in tri_count:
		var ia: int = indices[t * 3] if not indices.is_empty() else t * 3
		var ib: int = indices[t * 3 + 1] if not indices.is_empty() else t * 3 + 1
		var ic: int = indices[t * 3 + 2] if not indices.is_empty() else t * 3 + 2
		var c: Vector3 = (verts[ia] + verts[ib] + verts[ic]) / 3.0
		for idx: int in [ia, ib, ic]:
			var d: Vector3 = verts[idx] - c
			dirs[idx] = d.normalized() if d.length_squared() > 1e-10 else Vector3.UP
	return dirs


## Troca os materiais dos modelos importados (.glb/.gltf, ex.: Kenney) debaixo de `root` por
## materiais toon com contorno (mesma cor/textura). Materiais transparentes ficam como estão.
## Devolve o número de MeshInstance3D convertidas.
static func apply_to_imported(root: Node) -> int:
	var count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null or not _is_imported(mi):
			continue
		if _convert_instance(mi):
			count += 1
	return count


static func _is_imported(mi: MeshInstance3D) -> bool:
	var o: Node = mi.owner
	while o != null:
		var ext: String = o.scene_file_path.get_extension().to_lower()
		if ext == "glb" or ext == "gltf":
			return true
		o = o.owner
	return false


static func _convert_instance(mi: MeshInstance3D) -> bool:
	var src_mesh: Mesh = mi.mesh
	if src_mesh is ArrayMesh and (src_mesh as ArrayMesh).get_meta(&"toon_baked", false):
		return false
	var surfaces: Array[Material] = []
	for s: int in src_mesh.get_surface_count():
		var m: Material = mi.get_surface_override_material(s)
		if m == null:
			m = mi.material_override if mi.material_override != null else src_mesh.surface_get_material(s)
		surfaces.append(m)
	var thin: bool = _is_thin(mi)
	var baked: ArrayMesh = _baked_meshes.get(src_mesh) as ArrayMesh
	if baked == null:
		baked = bake_outline_normals(src_mesh)
		baked.set_meta(&"toon_baked", true)
		_baked_meshes[src_mesh] = baked
	mi.mesh = baked
	var converted_any: bool = false
	for s: int in surfaces.size():
		var toon: Material = _toon_for(surfaces[s], thin)
		if toon != null:
			mi.set_surface_override_material(s, toon)
			converted_any = true
		elif surfaces[s] != null:
			mi.set_surface_override_material(s, surfaces[s])
	if mi.material_override != null and converted_any:
		mi.material_override = null
	return converted_any


static func _is_thin(mi: MeshInstance3D) -> bool:
	var names: String = String(mi.name).to_lower()
	if mi.owner != null:
		names += " " + mi.owner.scene_file_path.get_file().to_lower()
	for hint: String in THIN_NAME_HINTS:
		if names.contains(hint):
			return true
	return false


static func _toon_for(src: Material, thin: bool) -> Material:
	if src == null:
		return null
	var key: String = "%d:%d" % [src.get_instance_id(), int(thin)]
	if _converted_mats.has(key):
		return _converted_mats[key]
	var toon: ShaderMaterial = null
	var base: BaseMaterial3D = src as BaseMaterial3D
	if base != null and base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		# Cartões finos (relva, flores, velas): dupla face e sem contorno (o casco pintava-os de
		# preto). O resto é fechado: toon normal com contorno.
		toon = material(&"grass" if thin else &"vertex")
		toon.set_shader_parameter(&"albedo_color", base.albedo_color)
		toon.set_shader_parameter(&"use_vertex_color", base.vertex_color_use_as_albedo)
		if base.albedo_texture != null:
			toon.set_shader_parameter(&"use_texture", true)
			toon.set_shader_parameter(&"albedo_texture", base.albedo_texture)
	_converted_mats[key] = toon
	return toon
