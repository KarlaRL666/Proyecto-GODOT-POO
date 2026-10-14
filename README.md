# 🎮 Proyecto de Videojuego en Godot 4 - IDGS 1004

**Carrera:** Ingeniería en Desarrollo y Gestión de Software  
**Grupo:** IDGS 1004  
**Motor de Desarrollo:** Godot Engine 4.7+ (Forward+ / Jolt Physics)  
**Lenguaje:** GDScript 2.0  
**Proyectos Base de Referencia:** `P2.2 IDGS1004` & `P2.3 IDGS1004`  

---

## 📖 Descripción General

Este proyecto consiste en una aplicación interactiva de videojuego en 3D desarrollada en **Godot Engine 4**. Integra y amplía los conocimientos adquiridos en las prácticas de la asignatura:
- De **`P2.2 IDGS1004`**: El sistema de físicas cinemáticas (`CharacterBody3D`), gravedad constante, salto con impulso vertical y navegación sobre plataformas tridimensionales.
- De **`P2.3 IDGS1004`**: La arquitectura de doble cámara desacoplada que permite alternar dinámicamente entre **Primera Persona (FPS)** y **Tercera Persona (TPS)** mediante un brazo orbital (`SpringArm3D`).

Sobre esta base se diseñó una arquitectura desacoplada basada en el patrón **Singleton / Gestor de Juego (`GameManager`)**, implementando de manera exhaustiva los conceptos fundamentales de la materia: **eventos**, **comportamientos**, **transacciones**, **acciones**, **colisiones**, **puntaje** y el sistema de **oportunidades-intentos (vidas)** del jugador.

---

## 🏛️ Arquitectura del Sistema

```mermaid
graph TD
    subgraph ENTRADA Y ACCIONES
        Input[Teclado y Ratón<br>WASD | Espacio | Shift | C | R | Esc]
    end

    subgraph ESCENARIO Y ENTIDADES 3D
        Jugador[Jugador CharacterBody3D<br>FPS / TPS / Salto / Daño]
        Coleccionables[Coleccionables Area3D<br>Monedas, Gemas, Vida Extra]
        Obstaculos[Obstáculos Area3D<br>Patrullas Móviles, Rotatorios]
        Checkpoint[Checkpoint Area3D<br>Punto de Control Activo]
        Meta[Meta Area3D<br>Zona de Victoria]
        ZonaCaida[ZonaCaida Area3D<br>Killzone / Detección de Vacío]
    end

    subgraph CONTROLADOR GLOBAL
        GM[GameManager Singleton<br>Gestión de Estados, Vidas y Puntos]
    end

    subgraph INTERFAZ DE USUARIO
        HUD[HUD CanvasLayer<br>Marcador, Corazones, Alertas, Modales]
    end

    Input --> Jugador
    Jugador -->|Colisión Física| Escenario[(Plataformas StaticBody3D)]
    Jugador -->|Colisión Trigger| Coleccionables
    Jugador -->|Colisión Trigger| Obstaculos
    Jugador -->|Colisión Trigger| Checkpoint
    Jugador -->|Colisión Trigger| Meta
    Jugador -->|Colisión Trigger| ZonaCaida

    Coleccionables -->|Transacción Puntos / Vida| GM
    Obstaculos -->|Transacción Daño| GM
    Checkpoint -->|Transacción Guardado| GM
    Meta -->|Transacción Victoria| GM
    ZonaCaida -->|Transacción Caída| GM

    GM -->|Señales / Eventos| HUD
    GM -->|Señales / Eventos| Jugador
```

---

## 🧩 Implementación de Requerimientos

### 1. ⚡ Eventos (Signals & Event-Driven Architecture)
El juego se comunica mediante un sistema de señales reactivo y desacoplado:
- `puntaje_actualizado(nuevo_puntaje, incremento)`: Notifica cada alteración en los puntos del jugador para actualizar el marcador y disparar animaciones en el HUD.
- `vidas_actualizadas(vidas_restantes, cambio)`: Informa el descuento o suma de oportunidades para refrescar los corazones visuales.
- `jugador_recibio_dano(vidas_restantes)`: Dispara la animación de parpadeo de invulnerabilidad y la respuesta visual.
- `jugador_reaparecer(posicion_checkpoint)`: Notifica al jugador para posicionarlo en las coordenadas del último punto de control guardado.
- `checkpoint_activado(posicion, nombre)`: Confirma la captura de una nueva posición segura en el mapa.
- `juego_completado(puntaje_final, vidas_restantes)`: Notifica la victoria al cruzar la meta y calcula bonos.
- `juego_terminado(puntaje_final)`: Dispara la pantalla de Game Over cuando las vidas llegan a 0.
- `notificacion_mostrada(mensaje, color)`: Muestra avisos flotantes contextuales en pantalla ("¡+50 Puntos!", "¡Punto de Control Guardado!").
- `camara_cambiada(es_primera_persona)`: Notifica el cambio de modo de cámara para actualizar la etiqueta de la interfaz.
- `pausa_cambiada(esta_pausado)`: Maneja la detención/reanudación del árbol de procesos.

### 2. 🧠 Comportamientos (Behaviors)
- **Jugador ([`scripts/jugador.gd`](scripts/jugador.gd))**:
  - Movimiento en 3D en relación a la dirección de la cámara activa.
  - Gravedad vertical (`GRAVITY = 20.0 m/s²`) y salto con verificación de suelo (`is_on_floor()`).
  - Carrera acelerada (`SPRINT_SPEED = 9.5 m/s`) manteniendo presionada la tecla `Shift`.
  - Giro suave del modelo del personaje (`lerp_angle`) hacia la dirección de avance en tercera persona.
  - Estado de **invulnerabilidad temporal** (1.6 segundos) con efecto estroboscópico de parpadeo para evitar daño en bucle.
  - Detección autónoma de caída al vacío si `global_position.y < -12.0`.
- **Coleccionables ([`scripts/coleccionable.gd`](scripts/coleccionable.gd))**:
  - Rotación continua sobre el eje vertical (`rotate_y`).
  - Levitación senoidal armónica (`sin(tiempo * frecuencia) * amplitud`).
  - Animación de escala rápida (Tween) al ser absorbidos por el jugador antes de destruirse.
- **Obstáculos y Trampas ([`scripts/obstaculo.gd`](scripts/obstaculo.gd))**:
  - Patrulla móvil oscilante (`sin(tiempo) * desplazamiento`) entre dos puntos en el espacio.
  - Bloques rotatorios continuos que imponen ventanas de tiempo para el paso del jugador.
  - Aplicación de retroceso físico (*knockback*) al jugador al sufrir un impacto.
- **Punto de Control ([`scripts/checkpoint.gd`](scripts/checkpoint.gd))**:
  - Comportamiento reactivo: Al ser tocado por primera vez, cambia su color de amarillo a verde brillante, incrementa su intensidad lumínica y realiza un pulso de escala.
- **Meta Final ([`scripts/meta.gd`](scripts/meta.gd))**:
  - Rotación continua del portal toroidal y emisión de luz dorada.

### 3. 🔄 Transacciones (Flujo del Juego y Economía)
- **Transacción de Recolección de Puntos**: Monedas estándar (+15 pts) y Gemas de valor alto (+50 pts).
- **Transacción de Recompensa por Rendimiento**: Si el jugador acumula **150 puntos** y no tiene la salud al máximo, el sistema premia su destreza otorgándole **+1 vida / intento adicional**.
- **Transacción de Consumo de Vidas / Intentos**:
  - Al colisionar con un peligro o caer al vacío, se reduce 1 intento.
  - Si `vidas > 0`: Transición a estado de **Reaparición (Respawn)** en el Checkpoint, reseteando la inercia del jugador y otorgando 2 segundos de inmunidad.
  - Si `vidas == 0`: Transición al estado irreversible de **Game Over**, liberando el cursor y mostrando el resumen de la partida.
- **Transacción de Victoria**: Al entrar en el portal de meta, se calcula una bonificación especial de **+50 puntos por cada vida restante** y se despliega la pantalla de felicitación.
- **Transacción de Pausa**: Detiene el tiempo del juego y despliega el menú contextual.

### 4. 🎮 Acciones del Jugador
Configuradas en el mapa de entradas de [`project.godot`](project.godot):
| Acción | Teclas / Entradas | Función |
| :--- | :--- | :--- |
| `ui_left` / `ui_right` | `A` / `D` o Flechas | Desplazamiento lateral (izquierda / derecha) |
| `ui_up` / `ui_down` | `W` / `S` o Flechas | Desplazamiento frontal (adelante / atrás) |
| `saltar` / `ui_accept` | Barra Espaciadora | Impulso de salto vertical |
| `correr` | Tecla `Shift` | Aumento de velocidad de traslación |
| `cambiar_camara` | Tecla `C` | Alternar entre 1ª Persona (FPS) y 3ª Persona (TPS) |
| `pausa` | Tecla `Escape` | Pausar la partida y liberar el cursor del ratón |
| `reiniciar` | Tecla `R` | Reiniciar el nivel de forma instantánea |

### 5. 💥 Colisiones
- **Colisiones Cinemáticas**: El personaje utiliza `CharacterBody3D` con una forma de cápsula (`CapsuleShape3D`), interactuando mediante `move_and_slide()` con el terreno del nivel (`StaticBody3D` con `BoxShape3D`).
- **Detección por Sensores (`Area3D`)**: Coleccionables, obstáculos, checkpoints, meta y la zona de vacío inferior están aislados por capas y máscaras de colisión:
  - **Capa 1:** Geometría del escenario y plataformas.
  - **Capa 2:** Jugador.
  - **Capa 3:** Áreas interactivas (Triggers).
- Las señales `body_entered` validan la pertenencia del nodo al grupo `"jugador"` para garantizar consistencia.

### 6. 🏆 Puntaje
- Administrado globalmente por la variable `GameManager.puntaje`.
- Reflejado en tiempo real en la interfaz de usuario con animación de escala interactiva cada vez que se consiguen puntos.
- Contabilizado y presentado en los modales de fin de juego.

### 7. ❤️ Oportunidades - Intentos (Vidas)
- El jugador dispone de un máximo de **3 oportunidades** por partida.
- Representación gráfica en el HUD mediante una hilera dinámica de corazones:
  - 3 vidas: `❤️❤️❤️`
  - 2 vidas: `❤️❤️🖤`
  - 1 vida: `❤️🖤🖤`
  - 0 vidas: `🖤🖤🖤`
- Cuenta con un coleccionable especial en el nivel para recuperar vidas perdidas.
- Mecanismo de reaparición (*Respawn*) que previene el reinicio frustrante del nivel completo al registrar el progreso mediante Checkpoints.

---

## 📁 Estructura del Repositorio

```
proyecto-godot/
├── project.godot                   # Configuración del motor, inputs y Autoload GameManager
├── icon.svg                        # Icono representativo de Godot
├── README.md                       # Documentación técnica completa del proyecto
│
├── scripts/                        # Lógica de programación (GDScript)
│   ├── game_manager.gd             # Singleton global: eventos, vidas, puntaje y estados
│   ├── jugador.gd                  # Controlador del jugador: físicas, salto, invulnerabilidad
│   ├── controlador_camara.gd       # Lógica de alternancia de cámaras FPS / TPS (de P2.3)
│   ├── coleccionable.gd            # Monedas, gemas y vidas extra con levitación y rotación
│   ├── obstaculo.gd                # Trampas con patrulla móvil, rotación y daño
│   ├── checkpoint.gd               # Punto de guardado con respuesta lumínica
│   ├── meta.gd                     # Portal de victoria y finalización de nivel
│   ├── zona_caida.gd               # Detección de caída al vacío (Killzone)
│   └── hud.gd                      # Controlador de la interfaz gráfica y ventanas modales
│
└── scenes/                         # Escenas y nodos jerárquicos (.tscn)
    ├── nivel.tscn                  # Escena principal con circuito completo de plataformas
    ├── jugador.tscn                # Modelo de jugador, visor, cabeza FPS y brazo TPS
    ├── hud.tscn                    # Interfaz gráfica CanvasLayer con estilos y botones
    ├── coleccionable.tscn          # Modelo 3D de moneda/gema dorada
    ├── obstaculo.tscn              # Cubo de advertencia rojo con luz de peligro
    ├── checkpoint.tscn             # Base, poste e indicador prismático interactivo
    ├── meta.tscn                   # Portal toroidal con núcleo flotante y luz dorada
    └── zona_caida.tscn             # Área de detección amplia ubicada bajo el nivel
```

---

## 🚀 Instrucciones de Instalación y Ejecución

### Prerrequisitos
- Tener instalado **Godot Engine 4.x** (probado y verificado en Godot 4.7.1).

### Pasos para Ejecutar
1. Clona o abre la carpeta del proyecto en tu equipo:
   ```text
   C:\Users\karla\OneDrive\Documentos\proyecto-godot
   ```
2. Inicia Godot Engine y selecciona la opción **Importar** (o *Import*).
3. Selecciona el archivo [`project.godot`](project.godot) dentro del directorio.
4. Presiona el botón **Editar** (o *Edit*) para cargar el proyecto en el editor.
5. Presiona la tecla **F5** (o el botón de reproducción ▶ en la esquina superior derecha) para ejecutar la escena principal [`nivel.tscn`](scenes/nivel.tscn).

---

## 🎯 Guía de Pruebas del Circuito del Nivel

1. **Zona de Inicio:**
   - Comprueba la respuesta de movimiento con `WASD`.
   - Presiona `Shift` para verificar el sprint y la barra espaciadora para el salto.
   - Presiona la tecla `C` para alternar entre la cámara en **primera persona** y la cámara orbital en **tercera persona**.
   - Recolecta las 3 monedas iniciales (+45 puntos en total). Observa cómo reacciona el marcador en el HUD.
2. **Zona de Plataformas Flotantes:**
   - Salta sobre las islas elevadas calculando la inercia y gravedad.
   - Recoge las gemas flotantes (+50 puntos c/u).
   - *(Opcional)* Déjate caer al vacío para verificar la detección de la **Killzone**: se te descontará 1 vida y reaparecerás en el punto inicial con parpadeo de invulnerabilidad.
3. **Zona de Obstáculos y Checkpoint:**
   - Esquiva la púa móvil que patrulla de lado a lado. Si te toca, notarás el retroceso físico y la pérdida de 1 corazón.
   - Pasa por el **Punto de Control (Checkpoint)**: observa cómo cambia su luz a verde y recibes la notificación emergente.
   - Recoge el corazón de **Vida Extra** ubicado en la plataforma para restaurar tu salud.
4. **Zona de Obstáculo Rotatorio y Puente:**
   - Atraviesa la barrera giratoria temporizando tu avance.
5. **Zona de Meta:**
   - Llega al portal de victoria para concluir la partida, recibir el bono por vidas conservadas y ver el modal triunfal.
