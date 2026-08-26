# Mina Profunda — actualización del juego

Esta versión convierte la mina en un espacio grande, seguro y realmente excavable. La superficie ya no tapa la primera capa: ahora sólo hay una base perimetral y el centro queda abierto para que el jugador pueda entrar, excavar y construir dentro del subsuelo.

## Instalación en Roblox Studio

Coloca `WorldGenerator.server.lua` y `MiningHandler.server.lua` dentro de `ServerScriptService`. Coloca `MiningController.client.lua` y `MiningUI.client.lua` dentro de `StarterPlayer > StarterPlayerScripts`. No hace falta crear manualmente carpetas ni RemoteEvents: los scripts los crean y sincronizan al iniciar la partida.

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

En la pared opuesta al campamento se crea una pantalla 3D con tres columnas: **más profundo**, **más rápido** y **más puntos**. Cada fila muestra el avatar, nombre, valor principal, bloques excavados, puntos, tiempo jugado y récord de profundidad cuando existe.

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
