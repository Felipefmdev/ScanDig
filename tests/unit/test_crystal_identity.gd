extends GutTest

const SCENE: PackedScene = preload("res://gameplay/quests/cratera/cratera_secrets.tscn")
const NAMES: Array[String] = ["CrystalViolet", "CrystalCyan", "CrystalAmber"]


func test_each_real_crystal_emits_one_distinct_audio_stream_on_use() -> void:
	var scene: Node3D = _scene(false)
	add_child_autofree(scene)
	await wait_frames(3)
	var streams: Array[int] = []
	for crystal_name: String in NAMES:
		var crystal: FlagInteractable = scene.get_node("Ground/" + crystal_name)
		assert_gt(crystal.use_note_hz, 0.0, crystal_name + " declares an actual note")
		var before: Array[Node] = _audio_nodes()
		crystal.request_interact()
		var created: Array[Node] = []
		for node: Node in _audio_nodes():
			if not before.has(node):
				created.append(node)
		assert_eq(created.size(), 1, crystal_name + " creates one real AudioStreamPlayer3D")
		if created.size() == 1:
			var audio: AudioStreamPlayer3D = created[0]
			assert_true(audio.stream is AudioStreamWAV)
			var wav: AudioStreamWAV = audio.stream as AudioStreamWAV
			if wav != null:
				assert_gt(wav.data.size(), 1000)
				streams.append(hash(wav.data))
	assert_eq(_unique(streams), 3, "Three distinct rendered waveforms, not only three text labels")


func test_crystal_forms_and_colors_are_distinct_even_without_color_cues() -> void:
	var scene: Node3D = _scene(false)
	add_child_autofree(scene)
	await wait_frames(2)
	var forms: Array[int] = []
	var palettes: Array[int] = []
	var silhouettes: Array[Vector3] = []
	for crystal_name: String in NAMES:
		var model: Node3D = scene.get_node("Ground/" + crystal_name + "/Model")
		var mi: MeshInstance3D = model.get_node("ModelMesh")
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		forms.append(hash(arrays[Mesh.ARRAY_VERTEX]))
		palettes.append(hash(arrays[Mesh.ARRAY_COLOR]))
		silhouettes.append(mi.mesh.get_aabb().size)
		assert_eq(mi.mesh.get_surface_count(), 1)
		assert_lt((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 6000, "Small procedural asset budget")
	assert_eq(_unique(forms), 3, "Geometry itself differs, preserving identity when palette is not distinguishable")
	assert_eq(_unique(palettes), 3)
	assert_ne(silhouettes[0], silhouettes[1], "Tall single and forked forms remain distinguishable by outline")
	assert_ne(silhouettes[1], silhouettes[2], "Forked and broad cluster have distinct silhouettes")


func test_sequence_inputs_order_and_reactions_are_preserved() -> void:
	var scene: Node3D = _scene(true)
	# Avoid spawning a boss: preserve/observe puzzle's success flag rather than combat fixture.
	scene.get_node("EchoTrigger").free()
	add_child_autofree(scene)
	await wait_frames(2)
	var sequence: SequencePuzzle = scene.get_node("CrystalSequence")
	var flags: WorldFlags = scene.get_node("WorldFlags")
	assert_eq(sequence.solution, PackedInt32Array([0, 1, 2]))
	assert_eq(sequence.inputs.size(), 3)
	(scene.get_node("Ground/CrystalCyan") as Interactable).request_interact()
	assert_eq(sequence.progress, 0, "Wrong input still resets without a new punishment")
	for crystal_name: String in NAMES:
		(scene.get_node("Ground/" + crystal_name) as Interactable).request_interact()
	assert_true(sequence.is_solved)
	assert_true(flags.has_flag(&"eco_acordado"))


func _scene(with_sequence: bool) -> Node3D:
	var scene: Node3D = SCENE.instantiate()
	if not with_sequence:
		scene.get_node("CrystalSequence").free()
		scene.get_node("EchoTrigger").free()
	return scene


func _audio_nodes() -> Array[Node]:
	return get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false)


func _unique(values: Array[int]) -> int:
	var found: Dictionary = {}
	for value: int in values:
		found[value] = true
	return found.size()
