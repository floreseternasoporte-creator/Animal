# Mina Profunda — actualización del juego

Esta versión convierte la mina en un espacio grande, seguro y realmente excavable. La superficie ya no tapa la primera capa: ahora sólo hay una base perimetral y el centro queda abierto para que el jugador pueda entrar, excavar y construir dentro del subsuelo.

## Instalación en Roblox Studio

Antes de probar, elimina o desactiva cualquier script antiguo llamado simplemente `Script` dentro de `ServerScriptService`. El error `ServerScriptService.Script:69: attempt to compare nil < number` también puede aparecer si se ejecuta una versión anterior de `WorldGenerator`: esa versión comparaba `transparency < 1` sin dar un valor por defecto. La versión corregida normaliza `transparency` antes de comparar; no debes dejar scripts duplicados junto al sistema nuevo.

Coloca `WorldGenerator.server.lua` y `MiningHandler.server.lua` dentro de `ServerScriptService`. Coloca `MiningController.client.lua`, `MiningUI.client.lua` y `MiningAudio.client.lua` dentro de `StarterPlayer > StarterPlayerScripts`. Copia los archivos actualizados desde GitHub; Roblox Studio no sincroniza automáticamente los cambios del repositorio. No hace falta crear manualmente carpetas ni RemoteEvents: los scripts los crean y sincronizan al iniciar la partida.

Para que el guardado persistente funcione en una experiencia publicada, habilita **Game Settings > Security > Enable Studio Access to API Services** cuando pruebes desde Studio. En el servidor publicado, el DataStore guarda puntos, profundidad máxima, bloques excavados, tiempo jugado y récord de velocidad.

## Controles

| Acción | Control |
|---|---|
| Excavar | Click izquierdo o toque sobre un bloque |
| Excavar de forma continua | Mantener presionado click/toque |
| Cambiar a construcción | Botón superior o tecla `B` |
| Construir | En modo construcción, click/toque sobre la cara de un bloque |

El servidor valida distancia, cooldown, objetivo, límites de la mina y ocupación de la celda antes de aceptar cualquier acción.

## Cambios principales

La mina ahora mide **18 × 18 bloques por capa** y tiene **110 capas de profundidad**. La superficie de hierba fue reemplazada por un campamento en forma de anillo, con borde industrial iluminado, zona de aparición, faros y letrero de profundidad.

Se agregó un piso sólido de seguridad, cuatro muros físicos invisibles y `Workspace.FallenPartsDestroyHeight` por debajo del fondo. Esto evita que el jugador se vaya al vacío aunque llegue al límite de la mina o se rompan bloques de la zona inferior.

La excavación cuenta con selección luminosa, herramienta procedural visible, animación de golpe, compresión del bloque, partículas, vibración de cámara, efecto de rotura, puntuación flotante y pulso de color al colocar bloques.

La interfaz incluye avatar del usuario, identidad de excavador, progreso vertical, máximo personal, pico y potencia, barra hacia el siguiente pico, bloques excavados, tiempo jugado, récord y modo de construcción.

La versión de corrección mantiene la vista limpia: se eliminan el letrero flotante, la pantalla 3D y los textos de puntuación sobre la mina. El `ScreenGui` queda desactivado por defecto, por lo que la excavación no queda tapada por carteles; la tecla `B` sigue cambiando el modo construcción y todos los efectos visuales permanecen en el mundo.

## Notas de diseño

La lógica de minería y construcción vive en el servidor. Los LocalScripts sólo envían solicitudes y reproducen feedback visual cuando el servidor confirma la acción. Los bloques construidos se integran a `MineBlocks`, pero no entregan puntos; así se conserva la progresión sin permitir farmear recursos colocando y rompiendo bloques propios.

## Audio y niveles ampliados

Coloca también `MiningAudio.client.lua` en `StarterPlayer > StarterPlayerScripts`. Este script crea los canales de música y ambiente, cambia la atmósfera al descender y reproduce efectos en golpes, roturas, construcción, descubrimientos raros, récords y subidas de pico.

Los IDs de audio están centralizados al comienzo de `MiningAudio.client.lua`:

| Uso | Asset ID | Nota |
|---|---:|---|
| Ambiente y tema base de mina | `273398061` | Creator Store: **Cave Ambience**. |
| Subida de nivel y descubrimiento | `2686079706` | Creator Store: **level up sound effect**. |
| Rotura de roca | `9125931990` | Creator Store: **Shale Burst Smashing Rock With A Big Stone 1 (SFX)**. |
| Fragmentos, golpes y construcción | `9125929705` | Creator Store: **Shale Burst Rock Shards Thrown Onto A Big Stone (SFX)**. |

Roblox puede cambiar permisos o disponibilidad de un asset. Si aparece un error de permisos, busca un reemplazo en **Toolbox > Creator Store > Audio**, copia el Asset ID y cambia sólo la tabla `AUDIO`.

La progresión ahora incluye **Tierra, Piedra, Granito, Carbón, Cobre, Hierro, Plata, Oro, Zafiro, Diamante, Esmeralda, Cristal Lunar, Magma, Obsidiana y Núcleo Estelar**. Las rarezas van desde `COMÚN` hasta `ANCIANA`, con más resistencia, puntos, partículas, luces, anillos de energía y audio reforzado en los materiales especiales.

Los picos adicionales son **Pico de Zafiro, Pico de Cristal, Pico de Magma, Pico de Obsidiana y Pico Estelar**, después del Pico de Esmeralda. La barra de progresión del HUD se actualiza automáticamente con cada nuevo umbral.

## Fuentes

[1] [Audio assets — Roblox Creator Hub](https://create.roblox.com/docs/audio/assets)

[2] [Audio objects — Roblox Creator Hub](https://create.roblox.com/docs/audio/objects)

[3] [Cave Ambience — Creator Store](https://create.roblox.com/store/asset/273398061/Cave-Ambience)

[4] [Level up sound effect — Creator Store](https://create.roblox.com/store/asset/2686079706/level-up-sound-effect)

[5] [Shale Burst Smashing Rock With A Big Stone 1 — Creator Store](https://create.roblox.com/store/asset/9125931990/Shale-Burst-Smashing-Rock-With-A-Big-Stone-1-SFX)

[6] [Shale Burst Rock Shards — Creator Store](https://create.roblox.com/store/asset/9125929705/Shale-Burst-Rock-Shards-Thrown-Onto-A-Big-St-SFX)

## Expansión: campamento, zonas y objetivos

La mina deja de ser una cuadrícula de bloques sin propósito. En la superficie se genera un **campamento minero físico** con cuatro estaciones interactivas que se usan con el prompt de proximidad estándar de Roblox. Ninguna de ellas activa carteles sobre la pantalla del jugador.

| Estación física | Uso | Resultado |
|---|---|---|
| Forja de Profundidad | Interactúa con `E` y paga puntos. | Sube hasta cinco niveles de forja; cada nivel añade potencia permanente al pico. |
| Escáner Geológico | Interactúa con `E`. | Activa 120 segundos de recompensa aumentada al romper minerales no comunes o superiores. |
| Contratos de Minería | Interactúa con `E`. | Entrega un objetivo de bloques; al completarlo concede puntos y escala el siguiente contrato. |
| Baliza de Eventos | Monitor físico, sin menú. | Anuncia la **Veta Estelar**, un evento de 75 segundos que duplica los puntos extraídos. |

El pozo también recibe cinco **hitos físicos de profundidad**: Túneles Antiguos, Galería Industrial, Bóveda Dorada, Cavernas Prismáticas y Fractura de Obsidiana. Funcionan como referencias espaciales reales dentro de la mina y separan visualmente el descenso en zonas.

> Para usar esta expansión, reemplaza `WorldGenerator.server.lua`, `MiningHandler.server.lua` y `MiningAudio.client.lua` por las versiones actuales. Las estaciones se generan automáticamente cuando inicia el mundo.

## Pase de calidad y estabilidad

La versión actual incorpora correcciones que no siempre se ven, pero evitan fallos durante partidas largas. El generador publica las dimensiones de la mina antes de que el servidor active las validaciones, de modo que construcción, límites y profundidad usan siempre el tamaño correcto. Los recursos naturales se regeneran por rareza, pero nunca reaparecen sobre un jugador ni ocupan una celda que ya esté llena.

El guardado usa `UpdateAsync` para reducir el riesgo de sobrescribir progreso durante cierres o guardados cercanos. Las estadísticas en vivo se envían cada tres segundos en vez de cada fotograma, y las sombras se reservan para las primeras capas de la mina para disminuir la carga gráfica sin afectar el aspecto inicial del mundo.
