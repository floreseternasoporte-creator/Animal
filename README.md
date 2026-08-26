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
