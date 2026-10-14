extends Node3D

# ==============================================================================
# PROYECTO GODOT - CONTROLADOR DE CÁMARA DUAL (FPS / TPS)
# Basado en la arquitectura del proyecto P2.3 IDGS1004
#
# Permite alternar con la tecla "C" (acción 'cambiar_camara') entre:
# - Cámara en Primera Persona (FPS): Inmersiva, fija a la cabeza del personaje.
# - Cámara en Tercera Persona (TPS): Vista orbital alejada con SpringArm3D.
# ==============================================================================

## Cámara asignada para la vista en primera persona (hija del nodo Head).
@export var camera_fp: Camera3D

## Cámara asignada para la vista en tercera persona (hija del SpringArm3D).
@export var camera_tp: Camera3D

## Bandera que define el estado activo de la vista.
var usando_primera_persona: bool = false

## Referencia al nodo padre (el Jugador).
@onready var jugador: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	# Iniciar en modo Tercera Persona por defecto (igual que en P2.3)
	configurar_camara(false)


func _unhandled_input(event: InputEvent) -> void:
	# Evento: Cambio de cámara mediante la tecla C o la acción configurada
	if event.is_action_pressed("cambiar_camara"):
		alternar_camara()


## Alterna entre vista FPS y TPS
func alternar_camara() -> void:
	usando_primera_persona = not usando_primera_persona
	configurar_camara(usando_primera_persona)


## Aplica la activación de cámaras y sincroniza con el script del jugador y la UI
func configurar_camara(primera_persona: bool) -> void:
	usando_primera_persona = primera_persona

	if camera_fp:
		camera_fp.current = usando_primera_persona
	if camera_tp:
		camera_tp.current = not usando_primera_persona

	# Notificar al jugador para que adapte su rotación y movimientos
	if jugador and jugador.has_method("set_modo_fps"):
		jugador.set_modo_fps(usando_primera_persona)

	# Notificar al GameManager para actualizar el HUD
	if Engine.has_singleton("GameManager") or get_node_or_null("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.notificar_cambio_camara(usando_primera_persona)
