# Crónicas de Lumenfall

**Crónicas de Lumenfall** es un juego original de supervivencia voxel para Roblox. El jugador explora un archipiélago compacto de biomas cúbicos, recolecta recursos, fabrica energía de construcción, restaura balizas antiguas y deja su propio refugio dentro del mundo.

> El proyecto no reproduce directamente Minecraft. Usa una identidad propia, con biomas, balizas, nombres, recursos, objetivos, estética y progresión originales.

## Instalación en Roblox Studio

Reemplaza los scripts anteriores por los cinco archivos actuales y conserva estos nombres y ubicaciones.

| Archivo | Ubicación |
|---|---|
| `WorldGenerator.server.lua` | `ServerScriptService` |
| `MiningHandler.server.lua` | `ServerScriptService` |
| `MiningController.client.lua` | `StarterPlayer > StarterPlayerScripts` |
| `MiningUI.client.lua` | `StarterPlayer > StarterPlayerScripts` |
| `MiningAudio.client.lua` | `StarterPlayer > StarterPlayerScripts` |

Antes de probar, elimina scripts viejos duplicados del sistema de mina, especialmente cualquier script llamado simplemente `Script`, y elimina LocalScripts antiguos que esperen una carpeta `MiningRemotes`. El nuevo juego crea `LumenfallWorld` en `Workspace` y `LumenRemotes` en `ReplicatedStorage` automáticamente.

Para conservar progreso entre sesiones publicadas, activa **Game Settings > Security > Enable Studio Access to API Services** al probar DataStores desde Studio.

## Bucle de juego

El jugador aparece en las **Praderas de Lumen**, un espacio central que conecta tres regiones: el Bosque de Aurora, las Llanuras de Ceniza y la Grieta de Cristal. Los árboles proporcionan madera, las rocas dan piedra y los cristales de la grieta permiten restaurar balizas. Las balizas son los objetivos de progreso: al restaurarlas, aumentan el registro del explorador y devuelven la energía.

| Sistema | Cómo funciona |
|---|---|
| Recolección | Haz click o toca un árbol, roca o cristal cercano. Los nodos reaparecen de forma segura. |
| Construcción | Presiona `B`, apunta a un bloque del mundo y haz click o toca una cara. Elige madera, piedra, cristal o lumen con `1` a `4`. |
| Taller Lumen | Usa el prompt físico de la estación. Convierte `4 Madera + 2 Piedra` en `3 Lumen`. |
| Santuario Vivo | Usa el prompt físico para restaurar energía y guardar el viaje. |
| Balizas | Cada baliza exige `6 Cristales Lumen`. Restaurarlas constituye el objetivo de exploración principal. |
| Registro de Exploradores | Tablero físico dentro del mundo que ordena por balizas restauradas y recursos recolectados. |

## Controles

| Acción | Control |
|---|---|
| Recolectar | Click izquierdo o toque |
| Entrar/salir de construcción | `B` |
| Seleccionar bloque de construcción | `1` Madera, `2` Piedra, `3` Cristal, `4` Lumen |
| Usar estaciones | Prompt de proximidad `E`, botón o gamepad según el dispositivo |

El HUD se limita a un panel compacto de recursos y energía. El contenido principal, las estaciones, las balizas y el tablero de exploradores están físicamente dentro del mundo.

## Rendimiento

El mapa tiene un tamaño intencionalmente compacto para que la construcción y los recursos sean editables. Para publicar una versión más grande, activa **Instance Streaming** desde las propiedades de `Workspace`: Roblox indica que se configura allí, no mediante script, y puede mejorar tiempo de entrada, memoria y rendimiento.

## Fuentes de diseño técnico

[1] [Proximity prompts — Roblox Creator Hub](https://create.roblox.com/docs/ui/proximity-prompts)

[2] [Instance streaming — Roblox Creator Hub](https://create.roblox.com/docs/workspace/streaming)
