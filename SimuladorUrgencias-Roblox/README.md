# SimUrgencias: simulador de pacientes virtuales para Roblox Studio

Simulador educativo de urgencias con pacientes virtuales. El estudiante:

1. **Dialoga** con el paciente escribiendo preguntas libres (anamnesis).
2. **Explora** con hallazgos semiológicos (inspección, palpación, percusión, auscultación).
3. **Solicita pruebas**, que tardan un tiempo clínico realista en llegar.
4. **Indica tratamientos**, que modifican los signos vitales en tiempo real.
5. Registra su **diagnóstico** y recibe un **debriefing** con puntuación, acciones críticas
   cumplidas o no, tiempos, errores de prescripción, puntos docentes y referencias.

La pantalla tiene barra superior con reloj clínico (T+), barra lateral de acciones,
monitor de signos vitales con alarmas, ventana de **Diálogo** con preguntas sugeridas
y un paciente 3D acostado en un box de urgencias.

## Casos incluidos

| Caso | Dificultad | Fuentes principales |
|---|---|---|
| Dolor torácico: SCACEST inferior con infarto de VD | Intermedio | ACC/AHA 2025 SCA · ESC 2023 SCA |
| Fiebre y confusión: choque séptico de origen urinario | Avanzado | Surviving Sepsis Campaign 2021 · Sepsis-3 |
| Dificultad respiratoria: crisis asmática grave | Básico | GINA 2024 |

La semiología (signo de Levine, Kussmaul, Giordano, pulso paradójico, etc.) sigue el
enfoque de *Argente-Álvarez, Semiología Médica*. El simulador no reproduce texto del libro.

## Instalación en Roblox Studio (copiar y pegar)

Crea un **Baseplate** nuevo y borra la pieza `Baseplate`. Luego crea estos objetos con
los nombres exactos y pega el contenido de cada archivo:

| Archivo | Dónde | Tipo de objeto |
|---|---|---|
| `src/ServerStorage/SimUrgencias/CasosClinicos.lua` | `ServerStorage` › carpeta **SimUrgencias** › **CasosClinicos** | ModuleScript |
| `src/ServerScriptService/ConstructorEscena.server.lua` | `ServerScriptService` › **ConstructorEscena** | Script |
| `src/ServerScriptService/SimuladorServidor.server.lua` | `ServerScriptService` › **SimuladorServidor** | Script |
| `src/StarterPlayerScripts/InterfazSimulador.client.lua` | `StarterPlayer` › `StarterPlayerScripts` › **InterfazSimulador** | LocalScript |

Pulsa **Play**. Aparece el menú de casos.

En *Game Settings › Avatar* no hace falta cambiar nada: el script desactiva el personaje
del jugador (`CharacterAutoLoads = false`) y usa una cámara fija sobre la cama.
Para publicarlo como experiencia de un solo jugador, pon *Max Players = 1*.

### Con Rojo (opcional)

```sh
rojo serve SimuladorUrgencias-Roblox/default.project.json
```

## Cómo se juega

- **💬 Diálogo**: escribe preguntas como «¿Cuándo empezó el dolor?» o toca una pregunta sugerida.
  El paciente responde en la ventana y con una burbuja sobre su cabeza.
- **🩺 Exploración**: cada maniobra devuelve su hallazgo.
- **🧪 Pruebas**: el resultado llega cuando pasa el tiempo clínico de la prueba (ver **📄 Resultados**).
- **💊 Tratamiento**: pide confirmación. Los fármacos contraindicados restan puntos y pueden
  descompensar al paciente; los innecesarios dejan una nota.
- **▶ x1 / x3 / x6**: acelera el reloj clínico. Por defecto 1 s real = 10 s clínicos.
- Si los signos cruzan los umbrales de paro, o el caso evoluciona sin el tratamiento clave,
  el escenario termina en paro y el debriefing lo explica.

## Ajustar el contenido clínico

Todo el contenido está en `CasosClinicos.lua`, separado de la lógica. Un docente puede:

- Cambiar dosis, textos y resultados de laboratorio.
- Cambiar los **objetivos** (`evento`, `limite` en segundos clínicos, `puntos`, `fuente`).
- Añadir palabras clave al diálogo (en minúsculas y **sin acentos**).
- Crear un caso nuevo copiando uno existente y añadiendo su `id` a `Casos.ORDEN`.

Parámetros globales (velocidad del reloj, penalizaciones, umbrales de paro) en el bloque
`CONFIG` de `SimuladorServidor`.

## Aviso importante

Es una herramienta de estudio. La fisiología está simplificada y los escenarios son
modelos docentes: no sustituyen la supervisión clínica ni los protocolos de tu institución.
Antes de usarlo en un curso, conviene que un profesor de urgencias revise
`CasosClinicos.lua` contra la guía que usa tu programa (por ejemplo, la versión 2026
de la guía de manejo de urgencias de tu hospital), porque las dosis y los tiempos
meta pueden variar entre guías y países.
