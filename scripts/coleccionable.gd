extends Area3D

# ==============================================================================
# PROYECTO GODOT - ENTIDAD: COLECCIONABLE (Monedas, Gemas, Vidas Extra)
#
# Funcionalidades implementadas:
# - Eventos: Señal 'body_entered' para detectar al jugador.
# - Comportamientos: Rotación continua en eje Y y levitación senoidal suave.
# - Transacciones: Suma de puntaje económico o bonificación de vidas en GameManager.
# - Colisiones: Área de interacción física tridimensional (Area3D con Sphere/BoxShape).
# ==============================================================================

## Tipos de coleccionables disponibles en el juego.
enum TipoColeccionable {
	MONEDA,      # Otorga puntos estándar (+15 pts)
	GEMA,        # Otorga puntos altos (+50 pts)
	VIDA_EXTRA   # Otorga +1 intento / vida al jugador
}

## Define qué tipo de ítem representa esta instancia.
@export var tipo: TipoColeccionable = TipoColeccionable.MONEDA

## Valor en puntos que otorga (si es Moneda o Gema).
@export var valor_puntos: int = 15

## Velocidad de giro sobre su propio eje (radianes por segundo).
@export var velocidad_rotacion: float = 3.0

## Amplitud de la oscilación vertical en metros.
@export var amplitud_flotacion: float = 0.25

## Frecuencia de la oscilación de flotación.
@export var frecuencia_flotacion: float = 3.0

## Altura inicial para calcular la función seno.
var altura_base: float = 0.0

## Acumulador de tiempo interno.
var tiempo: float = 0.0

## Nodo de colisión para desactivar inmediatamente tras ser recolectado.
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_node: Node3D = $Visual


func _ready() -> void:
	altura_base = position.y
	# Desfasar ligeramente el tiempo con una semilla aleatoria para que no todos oscilen idénticos
	tiempo = randf_range(0.0, 6.28)

	# Conectar evento de colisión al entrar un cuerpo en el área
	connect("body_entered", Callable(self, "_on_body_entered"))


func _process(delta: float) -> void:
	tiempo += delta

	# Comportamiento 1: Rotación continua en el eje Y
	rotate_y(velocidad_rotacion * delta)

	# Comportamiento 2: Levitación senoidal suave
	position.y = altura_base + sin(tiempo * frecuencia_flotacion) * amplitud_flotacion


func _on_body_entered(body: Node3D) -> void:
	# Validar que el objeto que entró sea el jugador
	if not body.is_in_group("jugador"):
		return

	# Desactivar colisión para evitar múltiples ejecuciones en el mismo cuadro
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Transacción: Notificar al GameManager según el tipo de ítem
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		match tipo:
			TipoColeccionable.MONEDA:
				gm.monedas_recolectadas += 1
				gm.sumar_puntos(valor_puntos, "Moneda")
			TipoColeccionable.GEMA:
				gm.gemas_recolectadas += 1
				gm.sumar_puntos(valor_puntos, "Gema Preciosa")
			TipoColeccionable.VIDA_EXTRA:
				gm.otorgar_vida(1, "Corazón Recolectado")

	# Animación de escala rápida antes de desaparecer
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "queue_free"))
