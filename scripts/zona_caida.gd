extends Area3D

# ==============================================================================
# PROYECTO GODOT - ZONA DE CAÍDA MORTAL (KILLZONE)
#
# Funcionalidades implementadas:
# - Colisiones: Área tridimensional amplia ubicada debajo del nivel.
# - Eventos: Señal 'body_entered' al precipitarse el jugador fuera de plataformas.
# - Transacciones: Descuenta una vida/intento y reposiciona al jugador en el Checkpoint.
# ==============================================================================

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.registrar_dano_jugador("Caída fuera del nivel")
