extends "res://ui/tests/expedition_notebook_access_test.gd"

# Inclui as duas capturas herdadas da regressão de desgaste normal/baixo.

func _initialize() -> void:
	_capture_access = true
	_run.call_deferred()
