extends Area3D

# ==============================================================================
# PROYECTO GODOT - ENTIDAD: PUNTO DE CONTROL (CHECKPOINT)
#
# Funcionalidades implementadas:
# - Eventos: Señal 'body_entered' al llegar el jugador.
# - Transacciones: Registro del punto de reaparición seguro en GameManager.
# - Comportamientos: Retroalimentación visual cambiando el color a verde al activarse.
# ==============================================================================

## Nombre identificador del Checkpoint (ej. "Campamento 1").
@export var nombre_checkpoint: String = "Punto de Control #1"

## Estado de activación.
var activado: bool = false

## Nodo visual del cristal o indicador.
@onready var indicador_mesh: MeshInstance3D = $Indicador
@onready var luz: OmniLight3D = $OmniLight3D


func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("jugador") or activado:
		return

	activado = true

	# Transacción: Guardar nueva coordenada de reaparición en el GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.registrar_checkpoint(global_position + Vector3(0.0, 1.0, 0.0), nombre_checkpoint)

	# Comportamiento visual: Cambiar color de amarillo/apagado a verde brillante
	if luz:
		luz.light_color = Color.GREEN
		luz.light_energy = 3.0

	if indicador_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.4)
		mat.emission_energy_multiplier = 2.0
		indicador_mesh.material_override = mat

		# Animación de pulso visual
		var tween = create_tween()
		tween.tween_property(indicador_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.2)
		tween.tween_property(indicador_mesh, "scale", Vector3.ONE, 0.2)
