extends GutTest

func test_expiration_follows_debris_lifetime_and_still_removes_old_debris() -> void:
	var strip: TideStrip = TideStrip.new()
	add_child_autofree(strip)
	strip.set_process(false)
	strip.call(&"_add_debris", 0, Vector3.ZERO, 0.0)
	var debris_root: Node = strip.get("_debris_root")
	var debris: Node = debris_root.get_child(0)
	var timer: Timer = debris.get_node_or_null(^"Expiry") as Timer
	assert_not_null(timer, "Expiry must leave the scene with its debris, not outlive the map")
	if timer == null: return
	assert_eq(timer.wait_time, TideStrip.DEBRIS_LIFETIME)
	assert_eq(timer.process_mode, Node.PROCESS_MODE_ALWAYS, "Visual expiry keeps original pause behavior")
	assert_true(timer.one_shot)
	timer.start(0.01)
	await get_tree().create_timer(0.05).timeout
	assert_eq(strip.get_debris_count(), 0, "Old debris still expires normally")
	strip.call(&"_add_debris", 1, Vector3.ZERO, 0.0)
	debris = debris_root.get_child(0)
	var expiry_ref: WeakRef = weakref(debris.get_node(^"Expiry"))
	debris.queue_free()
	# process_frame is emitted before deletion flush; wait through one complete frame.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(expiry_ref.get_ref(), "Leaving/clearing debris also destroys the pending expiry")
