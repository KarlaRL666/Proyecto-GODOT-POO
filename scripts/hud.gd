extends CanvasLayer

# ==============================================================================
# PROYECTO GODOT - INTERFAZ DE USUARIO (HUD)
#
# Funcionalidades implementadas:
# - Visualización interactiva en tiempo real del puntaje.
# - Oportunidades / intentos (vidas) representados con iconos gráficos.
# - Indicador de la cámara activa (Primera vs Tercera Persona).
# - Notificaciones emergentes dinámicas ante eventos del juego.
# - Paneles de fin de partida (Game Over, Victoria y Pausa).
# ==============================================================================

# Referencias a elementos de la UI
@onready var label_puntaje: Label = $MargenPrincipal/VBoxArriba/HBoxStats/PuntajeContainer/LabelPuntaje
@onready var label_vidas: Label = $MargenPrincipal/VBoxArriba/HBoxStats/VidasContainer/LabelVidas
@onready var label_camara: Label = $MargenPrincipal/VBoxArriba/HBoxStats/CamaraContainer/LabelCamara
@onready var label_notificacion: Label = $MargenPrincipal/VBoxCentro/LabelNotificacion
@onready var panel_pausa: PanelContainer = $PanelPausa
@onready var panel_game_over: PanelContainer = $PanelGameOver
@onready var panel_victoria: PanelContainer = $PanelVictoria
@onready var label_puntaje_game_over: Label = $PanelGameOver/VBox/LabelPuntajeFinal
@onready var label_puntaje_victoria: Label = $PanelVictoria/VBox/LabelPuntajeVictoria

## Animador de la notificación emergente
var tween_notificacion: Tween


func _ready() -> void:
	# Permitir procesar interfaz incluso en estado pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ocultar paneles emergentes
	panel_pausa.visible = false
	panel_game_over.visible = false
	panel_victoria.visible = false
	label_notificacion.modulate.a = 0.0

	# Conectar con las señales del GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.connect("puntaje_actualizado", Callable(self, "_on_puntaje_actualizado"))
		gm.connect("vidas_actualizadas", Callable(self, "_on_vidas_actualizadas"))
		gm.connect("notificacion_mostrada", Callable(self, "_on_notificacion_mostrada"))
		gm.connect("camara_cambiada", Callable(self, "_on_camara_cambiada"))
		gm.connect("pausa_cambiada", Callable(self, "_on_pausa_cambiada"))
		gm.connect("juego_terminado", Callable(self, "_on_juego_terminado"))
		gm.connect("juego_completado", Callable(self, "_on_juego_completado"))

		# Inicializar visualización con valores actuales
		actualizar_texto_puntaje(gm.puntaje)
		actualizar_texto_vidas(gm.vidas)
		actualizar_texto_camara(false)


# ------------------------------------------------------------------------------
# ACTUALIZACIÓN DE ESTADÍSTICAS EN PANTALLA
# ------------------------------------------------------------------------------
func _on_puntaje_actualizado(nuevo_puntaje: int, _incremento: int) -> void:
	actualizar_texto_puntaje(nuevo_puntaje)

	# Animación de pulso visual al ganar puntos
	if label_puntaje:
		label_puntaje.pivot_offset = label_puntaje.size / 2.0
		var tween = create_tween()
		tween.tween_property(label_puntaje, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(label_puntaje, "scale", Vector2.ONE, 0.1)


func actualizar_texto_puntaje(puntos: int) -> void:
	if label_puntaje:
		label_puntaje.text = "Puntaje: %03d" % puntos


func _on_vidas_actualizadas(vidas_restantes: int, _cambio: int) -> void:
	actualizar_texto_vidas(vidas_restantes)

	# Animación de sacudida visual al perder o ganar vidas
	if label_vidas:
		label_vidas.pivot_offset = label_vidas.size / 2.0
		var tween = create_tween()
		tween.tween_property(label_vidas, "scale", Vector2(1.25, 1.25), 0.12)
		tween.tween_property(label_vidas, "scale", Vector2.ONE, 0.12)


func actualizar_texto_vidas(vidas_restantes: int) -> void:
	if label_vidas:
		var corazones := ""
		for i in range(vidas_restantes):
			corazones += "❤️"
		for i in range(3 - vidas_restantes):
			corazones += "🖤"
		label_vidas.text = "Intentos: %s (%d/3)" % [corazones, vidas_restantes]


func _on_camara_cambiada(es_fps: bool) -> void:
	actualizar_texto_camara(es_fps)


func actualizar_texto_camara(es_fps: bool) -> void:
	if label_camara:
		if es_fps:
			label_camara.text = "Cámara: 1ª Persona (FPS) [C]"
		else:
			label_camara.text = "Cámara: 3ª Persona (TPS) [C]"


# ------------------------------------------------------------------------------
# NOTIFICACIONES FLOTANTES (EVENTOS)
# ------------------------------------------------------------------------------
func _on_notificacion_mostrada(mensaje: String, color: Color) -> void:
	if not label_notificacion:
		return

	if tween_notificacion and tween_notificacion.is_valid():
		tween_notificacion.kill()

	label_notificacion.text = mensaje
	label_notificacion.modulate = color
	label_notificacion.modulate.a = 0.0

	tween_notificacion = create_tween()
	tween_notificacion.tween_property(label_notificacion, "modulate:a", 1.0, 0.15)
	tween_notificacion.tween_interval(1.5)
	tween_notificacion.tween_property(label_notificacion, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------------------------
# PANELES DE ESTADO (PAUSA, DERROTA Y VICTORIA)
# ------------------------------------------------------------------------------
func _on_pausa_cambiada(esta_pausado: bool) -> void:
	if panel_pausa:
		panel_pausa.visible = esta_pausado


func _on_juego_terminado(puntaje_final: int) -> void:
	if panel_game_over:
		if label_puntaje_game_over:
			label_puntaje_game_over.text = "Puntaje alcanzado: %d puntos\n¡Te has quedado sin oportunidades!" % puntaje_final
		panel_game_over.visible = true


func _on_juego_completado(puntaje_final: int, vidas_restantes: int) -> void:
	if panel_victoria:
		if label_puntaje_victoria:
			label_puntaje_victoria.text = "¡Felicitaciones! Has llegado a la meta.\nVidas conservadas: %d/3\nPuntaje total: %d puntos" % [vidas_restantes, puntaje_final]
		panel_victoria.visible = true


# ------------------------------------------------------------------------------
# BOTONES DE LA INTERFAZ
# ------------------------------------------------------------------------------
func _on_boton_continuar_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.alternar_pausa()


func _on_boton_reintentar_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reiniciar_partida()


func _on_boton_salir_pressed() -> void:
	get_tree().quit()
