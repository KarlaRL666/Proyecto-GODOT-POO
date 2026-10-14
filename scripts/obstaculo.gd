extends Area3D

# ==============================================================================
# PROYECTO GODOT - ENTIDAD: OBSTÁCULO DAÑINO / TRAMPA
#
# Funcionalidades implementadas:
# - Eventos: Señal 'body_entered' para colisión con el personaje.
# - Comportamientos: Patrulla móvil entre dos puntos y rotación de aspas/bloque.
# - Colisiones: Área 3D peligrosa que resta oportunidades/vidas al jugador.
# ==============================================================================

## Modo de comportamiento del obstáculo.
enum ModoObstaculo {
	ESTATICO,   # Se mantiene fijo en el sitio (ej. púas en el suelo)
	MOVIL,      # Patrulla entre su posición y un desplazamiento tridimensional
	ROTATORIO   # Gira constantemente sobre un eje creando un obstáculo con tiempo
}

## Tipo de comportamiento asignado a este obstáculo.
@export var modo: ModoObstaculo = ModoObstaculo.MOVIL

## Vector de desplazamiento máximo para la patrulla móvil (en metros).
@export var desplazamiento: Vector3 = Vector3(4.0, 0.0, 0.0)

## Velocidad de movimiento o de patrulla.
@export var velocidad: float = 2.0

## Velocidad de giro para obstáculos rotatorios (radianes/seg).
@export var velocidad_giro: Vector3 = Vector3(0.0, 2.5, 0.0)

## Nombre descriptivo del obstáculo para notificaciones.
@export var nombre_obstaculo: String = "Púa Móvil"

## Posición tridimensional de origen.
var posicion_inicial: Vector3

## Acumulador de tiempo interno.
var tiempo: float = 0.0


func _ready() -> void:
	posicion_inicial = position
	# Conectar señal de colisión física
	connect("body_entered", Callable(self, "_on_body_entered"))


func _physics_process(delta: float) -> void:
	tiempo += delta

	match modo:
		ModoObstaculo.MOVIL:
			# Comportamiento: Oscilación sinusoidal suave entre origen y destino
			var factor := (sin(tiempo * velocidad) + 1.0) * 0.5
			position = posicion_inicial + desplazamiento * factor

		ModoObstaculo.ROTATORIO:
			# Comportamiento: Rotación constante sobre los ejes definidos
			rotate_x(velocidad_giro.x * delta)
			rotate_y(velocidad_giro.y * delta)
			rotate_z(velocidad_giro.z * delta)

		ModoObstaculo.ESTATICO:
			pass


func _on_body_entered(body: Node3D) -> void:
	# Evento de colisión con el jugador:
	if body.is_in_group("jugador"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1, nombre_obstaculo)
		else:
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.registrar_dano_jugador(nombre_obstaculo)
