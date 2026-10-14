extends Area3D

# ==============================================================================
# PROYECTO GODOT - ENTIDAD: META / ZONA DE VICTORIA
#
# Funcionalidades implementadas:
# - Eventos: Señal 'body_entered' cuando el jugador alcanza el final del nivel.
# - Transacciones: Disparo de la victoria del juego y cálculo de puntuación final.
# - Comportamientos: Rotación continua del trofeo/portal y emisión de luz triunfal.
# ==============================================================================

@export var velocidad_rotacion: float = 2.0
@onready var visual: Node3D = $Visual
@onready var luz: OmniLight3D = $OmniLight3D

var ya_activado: bool = false


func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))


func _process(delta: float) -> void:
	if visual:
		visual.rotate_y(velocidad_rotacion * delta)


func _on_body_entered(body: Node3D) -> void:
	if ya_activado or not body.is_in_group("jugador"):
		return

	ya_activado = true

	# Transacción: Culminar el nivel y registrar victoria
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.registrar_victoria()

	if luz:
		luz.light_energy = 5.0
		luz.light_color = Color.GOLD
