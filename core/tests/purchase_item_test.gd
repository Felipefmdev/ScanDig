# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/purchase_item_test.gd
extends SceneTree
const WORLD_SHOP: Script = preload("res://core/tests/world_shop_fixture.gd")
var _shop: Variant = null

var _fails: int = 0
var _last_result: Dictionary = {}
var _upgrade_signals: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _on_item_purchase_result(item_id: String, success: bool, message: String) -> void:
	_last_result = {"item_id": item_id, "success": success, "message": message}

func _on_upgrade_purchase_result(_upgrade_id: String, _success: bool, _message: String) -> void:
	_upgrade_signals += 1

func _on_world_upgrade_result(_request_id: int, _upgrade_id: String, _success: bool, _message: String) -> void:
	_upgrade_signals += 1

func _purchase(_gs: GameState, item_id: String) -> Dictionary:
	return await _shop.buy_item(item_id)

func _run() -> void:
	_shop = WORLD_SHOP.new()
	if not _shop.setup(self,"purchase_item"):
		_check(false,"physical fixture: "+str(_shop.errors))
		_shop.cleanup()
		quit(_fails)
		return
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	gs.item_purchase_result.connect(_on_item_purchase_result)
	gs.purchase_result.connect(_on_upgrade_purchase_result)
	gs.world_upgrade_result.connect(_on_world_upgrade_result)
	gs.load_snapshot({"team_money": 300, "current_day": 1, "discovered_items": [], "upgrade_levels": {}})
	_last_result = {}
	gs.request_purchase_item("estilingue")
	await _wait(3)
	_check(_last_result.get("success",true) == false and gs.team_money == 300,"legacy item endpoint denied without context/debit")

	var estilingue: ToolData = gs.get_tool_data("estilingue")
	_check(estilingue != null and estilingue.price == 250, "get_tool_data estilingue preço 250")
	_check(gs.get_tool_data("nao_existe") == null, "get_tool_data inexistente null")
	_check(gs.get_tool_data("../catalog/alianca_ouro") == null, "get_tool_data caminho malicioso null")
	_check(gs.get_tool_data("") == null, "get_tool_data vazio null")

	var result: Dictionary = await _purchase(gs, "estilingue")
	_check(result.get("success", false) == true, "compra estilingue ok")
	_check(result.get("item_id", "") == "estilingue", "item_id estilingue: %s" % str(result.get("item_id", "")))
	_check(gs.team_money == 50, "saldo 50: %d" % gs.team_money)
	_check(_shop.product_count("estilingue") == 1,"real broker grants exactly one slingshot to Player Inventory")
	_check(str(result.get("message", "")).contains("Comprado"), "mensagem Comprado: %s" % str(result.get("message", "")))

	result = await _purchase(gs, "estilingue")
	_check(result.get("success", true) == false, "segunda compra falha")
	_check(gs.team_money == 50, "saldo continua 50: %d" % gs.team_money)
	_check(str(result.get("message", "")).contains("Saldo insuficiente"), "mensagem Saldo insuficiente: %s" % str(result.get("message", "")))

	result = await _purchase(gs, "nao_existe")
	_check(result.get("success", true) == false, "compra inexistente falha")
	_check(not str(result.get("message", "")).is_empty(), "recusa contextual de produto inexistente tem motivo: %s" % str(result.get("message", "")))
	_check(gs.team_money == 50, "saldo continua 50 após inexistente: %d" % gs.team_money)

	result = await _purchase(gs, "../catalog/alianca_ouro")
	_check(result.get("success", true) == false, "compra maliciosa falha")
	_check(gs.team_money == 50, "saldo continua 50 após malicioso: %d" % gs.team_money)

	_check(_upgrade_signals == 0, "purchase_result de upgrade não emitido: %d" % _upgrade_signals)

	_check(_shop.product_count("estilingue") == 1,"denied requests do not grant another item")
	_check(_shop.errors.is_empty(),"bounded correlated physical replies: "+str(_shop.errors))
	_shop.cleanup()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
