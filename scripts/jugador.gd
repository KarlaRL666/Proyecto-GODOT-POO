extends CharacterBody3D

# ==============================================================================
# PROYECTO GODOT - CONTROLADOR DEL JUGADOR
# Basado en la integración de P2.2 IDGS1004 y P2.3 IDGS1004
#
# Funcionalidades implementadas:
# - Eventos: Señales de daño, reaparición e invulnerabilidad.
# - Comportamientos: Movimiento 3D, salto, carrera, caída al vacío y físicas.
# - Cámaras: Soporte unificado de 1ra persona (FPS) y 3ra persona orbital (TPS).
# - Colisiones: Detección con CharacterBody3D, trampas, vacío y coleccionables.
# - Oportunidades: Gestión de vidas e invulnerabilidad temporal al reaparecer.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PARÁMETROS DE MOVIMIENTO Y FÍSICAS
# ------------------------------------------------------------------------------
## Velocidad de caminata estándar (metros por segundo).
const SPEED: float = 6.0

## Velocidad al correr manteniendo Shift o la acción 'correr'.
const SPRINT_SPEED: float = 9.5

## Impulso vertical del salto.
const JUMP_VELOCITY: float = 8.5

## Fuerza gravitatoria constante que tira del jugador hacia abajo.
const GRAVITY: float = 20.0

## Sensibilidad para la rotación del ratón.
const MOUSE_SENSITIVITY: float = 0.003

## Velocidad de giro suave de la malla del personaje en 3ra persona.
const TURN_SPEED: float = 10.0

## Límite inferior en el eje Y para detectar caída mortal al vacío.
const LIMITE_CAIDA_Y: float = -12.0


# ------------------------------------------------------------------------------
# 2. NODOS REFERENCIADOS
# ------------------------------------------------------------------------------
@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


# ------------------------------------------------------------------------------
# 3. ESTADOS INTERNOS DEL JUGADOR
# ------------------------------------------------------------------------------
## Determina si la cámara activa es primera persona (true) o tercera persona (false).
var modo_fps: bool = false

## Estado de invulnerabilidad tras recibir daño o reaparecer.
var es_invulnerable: bool = false

## Temporizador para la duración de la invulnerabilidad.
var tiempo_invulnerabilidad: float = 0.0
const DURACION_INVULNERABILIDAD: float = 1.6

## Permite deshabilitar el control al terminar la partida (Game Over o Victoria).
var control_habilitado: bool = true


# ------------------------------------------------------------------------------
# 4. INICIALIZACIÓN Y CONEXIÓN DE EVENTOS
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Agregar al grupo 'jugador' para facilitar detección en colisiones y áreas
	add_to_group("jugador")

	# Capturar el cursor del ratón dentro de la ventana de juego
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Conectar con el GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.nodo_jugador = self
		gm.connect("jugador_reaparecer", Callable(self, "_on_jugador_reaparecer"))
		gm.connect("juego_terminado", Callable(self, "_on_juego_finalizado"))
		gm.connect("juego_completado", Callable(self, "_on_juego_finalizado"))

		# Guardar la posición inicial en el GameManager si es el comienzo
		gm.checkpoint_actual = global_position


# ------------------------------------------------------------------------------
# 5. CONTROL DEL RATÓN Y CÁMARAS (FPS Y TPS)
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not control_habilitado:
		return

	# Si se mueve el ratón y está capturado:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if modo_fps:
			# Primera Persona: el cuerpo entero rota horizontalmente (eje Y)
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			# La cabeza (con la cámara dentro) rota verticalmente (eje X)
			head.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		else:
			# Tercera Persona: el brazo orbital (SpringArm) gira alrededor del personaje
			spring_arm.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
			spring_arm.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(25))


## Llamado por el ControladorCamara cuando el usuario presiona la tecla de alternar cámara
func set_modo_fps(valor: bool) -> void:
	modo_fps = valor
	if modo_fps:
		# Al pasar a primera persona, alinear la orientación del cuerpo con la vista orbital
		if spring_arm:
			rotation.y = spring_arm.global_rotation.y
			spring_arm.rotation.y = 0.0
		if mesh:
			mesh.rotation.y = 0.0
			mesh.visible = false
	else:
		# Al volver a tercera persona, restablecer la visibilidad de la malla
		if mesh:
			mesh.visible = true


# ------------------------------------------------------------------------------
# 6. FÍSICAS, MOVIMIENTO, ACCIONES Y COMPORTAMIENTOS
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# Manejar temporizador de invulnerabilidad y parpadeo visual
	_procesar_invulnerabilidad(delta)

	# Si el juego terminó, frenar y no procesar controles
	if not control_habilitado:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	# Comportamiento: Detección de caída mortal al vacío
	if global_position.y < LIMITE_CAIDA_Y:
		caer_al_vacio()
		return

	# 1. Aplicación de Gravedad
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 2. Acción: Salto
	var quiere_saltar := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("saltar")
	if quiere_saltar and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Acción: Detección de dirección de entrada (WASD / Flechas)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Determinar velocidad actual (caminata vs carrera con Shift)
	var esta_corriendo := Input.is_action_pressed("correr") or Input.is_key_pressed(KEY_SHIFT)
	var velocidad_objetivo := SPRINT_SPEED if esta_corriendo else SPEED

	# Calcular la orientación según la cámara activa (FPS o TPS)
	var yaw: float = global_rotation.y if modo_fps else spring_arm.global_rotation.y
	var direction := (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 4. Comportamiento de desplazamiento horizontal
	if direction != Vector3.ZERO:
		velocity.x = direction.x * velocidad_objetivo
		velocity.z = direction.z * velocidad_objetivo

		# En tercera persona: girar la malla suavemente hacia la dirección de avance
		if not modo_fps and mesh:
			var target_yaw := atan2(-direction.x, -direction.z) - rotation.y
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, TURN_SPEED * delta)
	else:
		# Frenado cuando no hay pulsación de teclas
		velocity.x = move_toward(velocity.x, 0.0, velocidad_objetivo)
		velocity.z = move_toward(velocity.z, 0.0, velocidad_objetivo)

	# 5. Ejecutar movimiento con resolución de colisiones en 3D
	move_and_slide()


# ------------------------------------------------------------------------------
# 7. EVENTOS DE DAÑO, VIDAS, CAÍDAS Y REAPARICIÓN (RESPAWN)
# ------------------------------------------------------------------------------
## Comportamiento: Recibir daño de un obstáculo o enemigo
func recibir_dano(cantidad: int = 1, fuente: String = "Obstáculo") -> void:
	if es_invulnerable or not control_habilitado:
		return

	# Activar período de invulnerabilidad
	activar_invulnerabilidad(DURACION_INVULNERABILIDAD)

	# Aplicar un pequeño impulso físico de retroceso (knockback)
	velocity.y = 5.0
	velocity.x = -velocity.x * 0.5
	velocity.z = -velocity.z * 0.5

	# Notificar la transacción al GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.registrar_dano_jugador(fuente)


## Comportamiento: Caída mortal fuera de las plataformas
func caer_al_vacio() -> void:
	if es_invulnerable or not control_habilitado:
		return

	velocity = Vector3.ZERO
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.registrar_dano_jugador("Caída al vacío")
	else:
		# Fallback si no hay GameManager
		_on_jugador_reaparecer(Vector3(0, 2, 0))


## Activa el temporizador de invulnerabilidad y el parpadeo de la malla
func activar_invulnerabilidad(duracion: float) -> void:
	es_invulnerable = true
	tiempo_invulnerabilidad = duracion


## Procesa el parpadeo visual mientras dura la invulnerabilidad
func _procesar_invulnerabilidad(delta: float) -> void:
	if es_invulnerable:
		tiempo_invulnerabilidad -= delta
		if mesh:
			if not modo_fps:
				# Efecto estroboscópico de parpadeo solo en tercera persona
				mesh.visible = fmod(tiempo_invulnerabilidad, 0.2) > 0.1
			else:
				mesh.visible = false

		if tiempo_invulnerabilidad <= 0.0:
			es_invulnerable = false
			if mesh:
				mesh.visible = not modo_fps


## Evento: Reaparecer en la posición del último Checkpoint activo
func _on_jugador_reaparecer(posicion_checkpoint: Vector3) -> void:
	# Colocar al personaje ligeramente por encima del suelo para evitar atascos
	global_position = posicion_checkpoint + Vector3(0.0, 1.2, 0.0)
	velocity = Vector3.ZERO
	activar_invulnerabilidad(2.0)
	if mesh:
		mesh.visible = not modo_fps


## Evento: El juego ha finalizado (Victoria o Derrota)
func _on_juego_finalizado(_arg1 = null, _arg2 = null) -> void:
	control_habilitado = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mesh:
		mesh.visible = true
