extends Node

signal connection_status_changed(message: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const PORT := 24567
const MAX_PLAYERS := 8

var _peer: ENetMultiplayerPeer


func is_active() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func host_game() -> Error:
	close_session()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		connection_status_changed.emit("No se pudo crear la partida (error %d)." % error)
		return error
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	connection_status_changed.emit("Partida creada. Comparte tu IP local; puerto %d." % PORT)
	return OK


func join_game(address: String) -> Error:
	close_session()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		connection_status_changed.emit("No se pudo conectar (error %d)." % error)
		return error
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	connection_status_changed.emit("Conectando a %s:%d…" % [address, PORT])
	return OK


func close_session() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer = null


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)
	connection_status_changed.emit("Jugador %d se unió." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)
	connection_status_changed.emit("Jugador %d salió." % peer_id)


func _on_connected_to_server() -> void:
	connection_status_changed.emit("Conectado. Entrando al mundo…")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")


func _on_connection_failed() -> void:
	connection_status_changed.emit("Falló la conexión. Revisa la IP y el puerto %d." % PORT)
	close_session()


func _on_server_disconnected() -> void:
	connection_status_changed.emit("Se perdió la conexión con el anfitrión.")
	close_session()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/character_creator.tscn")
