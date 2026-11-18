extends "res://ui/tests/hud_money_dial_test.gd"

## Executar com janela apenas na lease exclusiva da #212, perfil isolado.
func _initialize() -> void:
	_capture_money = true
	_run.call_deferred()
