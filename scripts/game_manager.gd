extends Node

# ==============================================================================
# PROYECTO GODOT - GESTOR GLOBAL DEL JUEGO (GameManager)
# Asignatura: IDGS 1004
#
# Este script implementa:
# 1. EVENTOS: Señales personalizadas para comunicar cambios a la UI y entidades.
# 2. TRANSACCIONES: Gestión de flujo de partida, economía de puntos, consumo de vidas.
# 3. COMPORTAMIENTOS: Manejo centralizado de estados (Jugando, Pausa, Victoria, Game Over).
# 4. OPORTUNIDADES / INTENTOS: Control de vidas del jugador y reaparición en Checkpoints.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EVENTOS (Señales personalizadas)
# ------------------------------------------------------------------------------
## Emitido cuando el puntaje del jugador cambia (suma de monedas/gemas).
signal puntaje_actualizado(nuevo_puntaje: int, incremento: int)

## Emitido cuando cambian las vidas / intentos del jugador.
signal vidas_actualizadas(vidas_restantes: int, cambio: int)

## Emitido cuando el jugador recibe daño de un obstáculo o enemigo.
signal jugador_recibio_dano(vidas_restantes: int)

## Emitido cuando el jugador pierde una oportunidad y debe reaparecer en el Checkpoint.
signal jugador_reaparecer(posicion_checkpoint: Vector3)

## Emitido cuando se activa un nuevo Checkpoint.
signal checkpoint_activado(posicion: Vector3, nombre_checkpoint: String)

## Emitido cuando el jugador completa el nivel alcanzando la meta.
signal juego_completado(puntaje_final: int, vidas_restantes: int)

## Emitido cuando el jugador agota todas sus oportunidades/intentos (Game Over).
signal juego_terminado(puntaje_final: int)

## Emitido para mostrar avisos o notificaciones emergentes en la interfaz de usuario.
signal notificacion_mostrada(mensaje: String, color: Color)

## Emitido cuando el modo de cámara cambia (1ra persona / 3ra persona).
signal camara_cambiada(es_primera_persona: bool)

## Emitido cuando cambia el estado de pausa del juego.
signal pausa_cambiada(esta_pausado: bool)


# ------------------------------------------------------------------------------
# 2. VARIABLES DE CONFIGURACIÓN Y ESTADO
# ------------------------------------------------------------------------------
## Cantidad inicial de oportunidades / vidas por partida.
const VIDAS_MAXIMAS: int = 3

## Vidas / intentos actuales del jugador.
var vidas: int = VIDAS_MAXIMAS

## Puntaje total acumulado por el jugador.
var puntaje: int = 0

## Contador de coleccionables obtenidos para estadísticas.
var monedas_recolectadas: int = 0
var gemas_recolectadas: int = 0

## Posición actual del último Checkpoint guardado.
var checkpoint_actual: Vector3 = Vector3(0.0, 2.0, 0.0)

## Umbral de puntos para recibir una oportunidad / vida adicional (transacción por mérito).
const PUNTOS_POR_VIDA_EXTRA: int = 150
var proximo_umbral_vida: int = PUNTOS_POR_VIDA_EXTRA

## Estados posibles del juego: "JUGANDO", "PAUSADO", "VICTORIA", "GAME_OVER".
var estado_actual: String = "JUGANDO"

## Referencia global al nodo del jugador.
var nodo_jugador: CharacterBody3D = null


# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Permitir que el GameManager procese entradas incluso cuando el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	reiniciar_variables()


func _unhandled_input(event: InputEvent) -> void:
	# Acción: Pausar / Reanudar juego con la tecla ESCAPE
	if event.is_action_pressed("pausa"):
		if estado_actual == "JUGANDO" or estado_actual == "PAUSADO":
			alternar_pausa()

	# Acción: Reiniciar partida rápida con la tecla R
	if event.is_action_pressed("reiniciar"):
		reiniciar_partida()


# ------------------------------------------------------------------------------
# 4. TRANSACCIONES: PUNTAJE Y ECONOMÍA DEL JUEGO
# ------------------------------------------------------------------------------
## Transacción: Incrementa el puntaje y valida recompensas por rendimiento.
func sumar_puntos(cantidad: int, origen: String = "Item") -> void:
	if estado_actual != "JUGANDO":
		return

	puntaje += cantidad
	emit_signal("puntaje_actualizado", puntaje, cantidad)
	emit_signal("notificacion_mostrada", "+%d Puntos (%s)" % [cantidad, origen], Color.GOLD)

	# Transacción especial: Si supera el umbral de puntos, se recompensa con +1 vida/intento
	if puntaje >= proximo_umbral_vida and vidas < VIDAS_MAXIMAS:
		proximo_umbral_vida += PUNTOS_POR_VIDA_EXTRA
		otorgar_vida(1, "¡Bono por Puntaje!")


## Transacción: Otorga intentos / vidas adicionales al jugador (por coleccionable o puntaje).
func otorgar_vida(cantidad: int = 1, motivo: String = "Vida Extra") -> void:
	if estado_actual != "JUGANDO":
		return

	vidas = min(vidas + cantidad, VIDAS_MAXIMAS)
	emit_signal("vidas_actualizadas", vidas, cantidad)
	emit_signal("notificacion_mostrada", "+%d Intento: %s" % [cantidad, motivo], Color.LIGHT_GREEN)


# ------------------------------------------------------------------------------
# 5. TRANSACCIONES: GESTIÓN DE OPORTUNIDADES / INTENTOS (VIDAS) Y RESPAWN
# ------------------------------------------------------------------------------
## Transacción: Ejecutada cuando el jugador sufre una colisión dañina o cae al vacío.
func registrar_dano_jugador(origen_dano: String = "Obstáculo") -> void:
	if estado_actual != "JUGANDO":
		return

	# Restamos una oportunidad / vida
	vidas -= 1
	emit_signal("vidas_actualizadas", vidas, -1)
	emit_signal("jugador_recibio_dano", vidas)

	if vidas > 0:
		# Si aún le quedan intentos, transiciona a evento de reaparición (Respawn)
		emit_signal("notificacion_mostrada", "¡Golpe! Te quedan %d vidas (%s)" % [vidas, origen_dano], Color.ORANGE_RED)
		emit_signal("jugador_reaparecer", checkpoint_actual)
	else:
		# Si se agotan los intentos, transiciona a estado GAME OVER
		vidas = 0
		estado_actual = "GAME_OVER"
		emit_signal("notificacion_mostrada", "¡Sin intentos restantes!", Color.RED)
		emit_signal("juego_terminado", puntaje)


## Transacción: Guarda la posición del jugador al pasar por un Checkpoint.
func registrar_checkpoint(posicion: Vector3, nombre: String = "Checkpoint") -> void:
	if estado_actual != "JUGANDO":
		return

	# Evitar registrar el mismo punto repetidamente
	if checkpoint_actual.distance_squared_to(posicion) > 1.0:
		checkpoint_actual = posicion
		emit_signal("checkpoint_activado", posicion, nombre)
		emit_signal("notificacion_mostrada", "¡Punto de control activado: %s!" % nombre, Color.AQUAMARINE)


# ------------------------------------------------------------------------------
# 6. TRANSACCIONES: FIN DE JUEGO (VICTORIA Y REINICIO)
# ------------------------------------------------------------------------------
## Transacción: Culmina exitosamente el nivel al alcanzar la zona de victoria / meta.
func registrar_victoria() -> void:
	if estado_actual != "JUGANDO":
		return

	estado_actual = "VICTORIA"
	# Bono especial: 50 puntos adicionales por cada vida conservada
	var bono_vidas = vidas * 50
	puntaje += bono_vidas

	emit_signal("notificacion_mostrada", "¡Nivel completado! Bono por vidas: +%d" % bono_vidas, Color.GREEN_YELLOW)
	emit_signal("juego_completado", puntaje, vidas)


## Transacción: Reinicia todas las variables y recarga la escena activa.
func reiniciar_partida() -> void:
	get_tree().paused = false
	reiniciar_variables()
	get_tree().reload_current_scene()


## Restablece los contadores de la partida a sus valores iniciales.
func reiniciar_variables() -> void:
	vidas = VIDAS_MAXIMAS
	puntaje = 0
	monedas_recolectadas = 0
	gemas_recolectadas = 0
	proximo_umbral_vida = PUNTOS_POR_VIDA_EXTRA
	estado_actual = "JUGANDO"
	checkpoint_actual = Vector3(0.0, 2.0, 0.0)


## Alterna la pausa del juego y libera/bloquea el ratón según corresponda.
func alternar_pausa() -> void:
	var nueva_pausa = not get_tree().paused
	get_tree().paused = nueva_pausa

	if nueva_pausa:
		estado_actual = "PAUSADO"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		estado_actual = "JUGANDO"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	emit_signal("pausa_cambiada", nueva_pausa)


## Notifica cambio en el tipo de cámara activa.
func notificar_cambio_camara(es_fps: bool) -> void:
	emit_signal("camara_cambiada", es_fps)
