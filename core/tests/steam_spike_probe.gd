## Spike #54: lista o que o GodotSteam registra na Godot 4.3 (sem chamar a Steam).
## "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/steam_spike_probe.gd
extends SceneTree

const METHODS: Array[String] = ["steamInit", "steamInitEx", "isSteamRunning", "getSteamID", "getPersonaName",
	"createLobby", "setLobbyData", "getLobbyData", "addRequestLobbyListStringFilter",
	"addRequestLobbyListDistanceFilter", "addRequestLobbyListResultCountFilter", "requestLobbyList",
	"joinLobby", "leaveLobby", "getLobbyOwner", "getNumLobbyMembers", "getLobbyMemberByIndex",
	"activateGameOverlayInviteDialog", "sendMessageToUser", "receiveMessagesOnChannel",
	"acceptSessionWithUser", "closeSessionWithUser", "getSessionConnectionInfo", "run_callbacks",
	"getAppID", "isSubscribed", "steamShutdown", "initRelayNetworkAccess", "getRelayNetworkStatus"]
const SIGNALS: Array[String] = ["lobby_created", "lobby_match_list", "lobby_joined", "lobby_chat_update",
	"join_requested", "network_messages_session_request", "network_messages_session_failed",
	"steamworks_error", "relay_network_status"]


func _initialize() -> void:
	print("PROBE godot=", Engine.get_version_info().string)
	print("PROBE class_exists(Steam)=", ClassDB.class_exists("Steam"), " has_singleton=", Engine.has_singleton("Steam"))
	print("PROBE SteamMultiplayerPeer=", ClassDB.class_exists("SteamMultiplayerPeer"), " MultiplayerPeerExtension=", ClassDB.class_exists("MultiplayerPeerExtension"))
	if not ClassDB.class_exists("Steam"):
		print("PROBE RESULT fails=1")
		quit(1)
		return
	var methods: Dictionary = {}
	for m: Dictionary in ClassDB.class_get_method_list("Steam", true):
		methods[m["name"]] = m
	print("PROBE total_methods=", methods.size())
	for name: String in METHODS:
		if not methods.has(name):
			print("PROBE missing ", name)
			continue
		var m: Dictionary = methods[name]
		var args: Array[String] = []
		for a: Dictionary in m["args"]:
			args.append("%s:%s" % [a["name"], type_string(int(a["type"]))])
		print("PROBE %s(%s) defaults=%s -> %s" % [name, ", ".join(args), str(m["default_args"]), type_string(int(m["return"]["type"]))])
	var sigs: Dictionary = {}
	for s: Dictionary in ClassDB.class_get_signal_list("Steam", true):
		sigs[s["name"]] = s
	for name: String in SIGNALS:
		if not sigs.has(name):
			print("PROBE missing signal ", name)
			continue
		var args: Array[String] = []
		for a: Dictionary in sigs[name]["args"]:
			args.append(String(a["name"]))
		print("PROBE signal %s(%s)" % [name, ", ".join(args)])
	print("PROBE RESULT fails=0")
	quit(0)
