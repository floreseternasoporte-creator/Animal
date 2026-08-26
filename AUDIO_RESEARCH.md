# Investigación de audio para Roblox

## Fuentes oficiales revisadas

1. [Audio assets — Roblox Creator Hub](https://create.roblox.com/docs/audio/assets)
2. [Audio objects — Roblox Creator Hub](https://create.roblox.com/docs/audio/objects)

## Hallazgos aplicables

Roblox indica que se pueden buscar audios gratuitos en la pestaña **Creator Store** del **Toolbox**, filtrando por categoría Audio, y copiar el Asset ID desde Studio. La misma documentación recomienda usar únicamente audio propio o audio para el que se tengan permisos. Los audios importados pasan por moderación y el sistema de privacidad puede limitar el acceso a experiencias concretas.

La documentación oficial también señala que los objetos clásicos `Sound`, `SoundGroup` y `SoundEffect` están desaconsejados frente al sistema modular moderno (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `Wire` y `AudioDeviceOutput`). Para mantener compatibilidad con el proyecto actual y con experiencias Roblox existentes, la implementación usará `Sound` de forma controlada, dejando los IDs concentrados en una configuración reemplazable. Si el proyecto migra al sistema modular, los mismos IDs pueden conectarse a `AudioPlayer` y `AudioEmitter`.

El audio 2D debe estar parentado a `SoundService` o a un contenedor no espacial para música y UI. Los sonidos 3D deben estar parentados a una pieza o attachment cercano al evento: golpes, roturas, descubrimientos y construcciones. En ambos casos se deben controlar `Volume`, `PlaybackSpeed`, `RollOffMaxDistance`, `Looped` y `SoundGroup`.

## Política de IDs

No se deben copiar IDs de listas no oficiales sin comprobarlos dentro de Roblox Studio, porque pueden quedar privados, moderados, eliminados o no autorizados para la experiencia. El código incluirá una tabla de IDs con valores públicos de Creator Store que puedan sustituirse fácilmente desde un solo archivo. Si Studio muestra `Experience doesn't have permission`, hay que abrir el asset en Creator Store y conceder el permiso a la experiencia, o elegir otro audio público.

## Plan de audio del juego

| Evento | Tipo | Configuración |
|---|---|---|
| Música de mina | 2D | Loop, volumen bajo, transición por profundidad |
| Ambiente subterráneo | 2D/ambiental | Loop, cambia entre superficie, túnel y abismo |
| Golpe de pico | 3D | Variación aleatoria de pitch y volumen |
| Rotura de bloque | 3D | Variante por material y partículas sincronizadas |
| Colocación de bloque | 3D | Sonido metálico/constructivo y pulso visual |
| Descubrimiento raro | 2D + 3D | Jingle, luz, partículas y notificación |
| Subida de nivel | 2D | Fanfarria corta y animación del HUD |
| Límite de seguridad | 3D/2D | Alerta sutil, sin sonido repetitivo |

## IDs encontrados para verificación

| Uso previsto | Asset ID | Estado |
|---|---:|---|
| Ambiente de cueva | `273398061` | Referenciado por una página del Creator Store titulada **Cave Ambience**; la página dinámica no cargó todos sus metadatos en la sesión, por lo que debe probarse en Studio antes de publicar. |
| Subida de nivel | `2686079706` | Página del Creator Store titulada **level up sound effect**; debe probarse en Studio y autorizarse para la experiencia si Roblox lo solicita. |
| Otros efectos | Pendientes de seleccionar en el Toolbox de Studio | Se recomienda buscar `pickaxe`, `stone`, `metal`, `ore`, `build` y `cave` en Creator Store y usar **Copy Asset ID** sobre resultados que aparezcan como públicos y utilizables. |

No usaré listas externas como fuente definitiva para IDs de audio. Los IDs se dejarán centralizados en un módulo configurable y el README explicará cómo reemplazarlos si un asset cambia de permisos o disponibilidad.

## Candidato de música adicional

La página [Obby Music! Background Song Track Vibe](https://create.roblox.com/store/asset/127298405859408/Obby-Music-Background-Song-Track-Vibe) muestra un asset con tags de música de fondo, soundtrack y loopable, pero Roblox lo presenta como **Model** y no como audio directo. Por eso no se debe colocar ese número a ciegas en `SoundId`: primero hay que insertar el modelo en Studio y copiar el ID del objeto `Sound` que contiene, o elegir un resultado que aparezca directamente dentro de la categoría Audio. El código usará un fallback ambiental y documentará este paso para evitar sonidos rotos o sin permisos.
