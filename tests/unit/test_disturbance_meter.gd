extends GutTest

var meter: DisturbanceMeter


func before_each() -> void:
	meter = DisturbanceMeter.new()
	add_child_autofree(meter)
	meter.set_process(false)  # sem decaimento durante o teste


func test_noise_crosses_thresholds_in_order() -> void:
	watch_signals(meter)
	meter.add_noise(40.0, Vector3.ZERO)
	assert_eq(meter.current_level, 1)
	meter.add_noise(30.0, Vector3.ZERO)
	assert_eq(meter.current_level, 2)
	assert_signal_emit_count(meter, "threshold_reached", 2)


func test_noise_is_clamped() -> void:
	meter.add_noise(1000.0, Vector3.ZERO)
	assert_eq(meter.current_noise, meter.max_noise)
	assert_eq(meter.current_level, meter.thresholds.size())


func test_report_without_meter_is_safe() -> void:
	meter.free()
	DisturbanceMeter.report(10.0, Vector3.ZERO)
	pass_test("report() sem medidor não rebenta")
