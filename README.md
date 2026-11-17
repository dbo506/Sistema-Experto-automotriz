# ZYTRON — Sistema Experto de Diagnóstico Automotriz

Proyecto Programado N.º 2 del curso **Paradigmas de Programación**, Universidad Nacional de Costa Rica.

## Descripción general

ZYTRON es una aplicación de consola que analiza los datos de un vehículo y sus síntomas para generar hipótesis de fallas automotrices. Combina una interfaz en C con un motor de razonamiento en Prolog que presenta diagnósticos, explicaciones y recomendaciones de verificación o reparación.

Permite analizar problemas de los subsistemas mecánico, eléctrico y electrónico, como dificultades de arranque, batería y carga, suministro de combustible, encendido, refrigeración, sensores y frenos. Los resultados son hipótesis sustentadas en los síntomas registrados y las características del vehículo; puede haber varias alternativas o ninguna coincidencia.

## Tecnologías utilizadas

| Tecnología | Uso |
|---|---|
| C11 | Interfaz de consola, validación de entradas y administración de la sesión en memoria |
| GCC | Compilación del programa en C |
| SWI-Prolog | Base de conocimientos, inferencia, consultas, persistencia y reportes |
| Python 3 | Ejecución y registro de las 15 pruebas automatizadas |

C invoca SWI-Prolog como un proceso externo. No es necesario enlazar la biblioteca `libswipl`.

## Requisitos de instalación

Para compilar y utilizar el sistema en Windows se necesita:

- PowerShell.
- GCC compatible con C11; la instalación utilizada pertenece a MSYS2 UCRT64.
- SWI-Prolog, con el comando `swipl` disponible en el `PATH`.
- Permisos de escritura en el proyecto para los archivos temporales de integración, las sesiones y los reportes.

Python 3 es necesario únicamente para el ejecutor de pruebas. La auditoría registró GCC 16.2.0 y SWI-Prolog 10.1.16; estas son las versiones verificadas, no versiones mínimas establecidas.

## Compilación y ejecución en PowerShell

Abra PowerShell en la raíz del repositorio. Ajuste las rutas de las herramientas si su instalación utiliza otra ubicación:

```powershell
Set-Location 'C:\Users\joelm\OneDrive\Documentos\2026\Paradigmas\Sistema-Experto-automotriz'
$env:Path = 'C:\msys64\ucrt64\bin;C:\Program Files\swipl\bin;' + $env:Path

gcc --version
swipl --version

gcc -std=c11 -Wall -Wextra -pedantic -Werror frontend/main.c frontend/menu.c frontend/interfaz.c frontend/validaciones.c integracion/conexion.c -o diagnostico.exe
.\diagnostico.exe
```

Cierre una instancia anterior de `diagnostico.exe` antes de compilar sobre ese archivo. Si ya dispone del ejecutable compilado, basta con ejecutar `.\diagnostico.exe` desde la raíz, con SWI-Prolog en el `PATH`.

La aplicación debe iniciarse desde la raíz porque busca `backend/puente.pl` mediante una ruta relativa. La auditoría confirmó que la compilación completa con las opciones anteriores termina sin errores ni advertencias.

## Funcionalidades del sistema

| Opción | Funcionalidad |
|---|---|
| **1. Registrar vehículo** | Registra marca, modelo, año, kilometraje y combustible. Permite elegir entre 14 perfiles catalogados o introducir los datos manualmente. Valida campos obligatorios y entradas numéricas. |
| **2. Seleccionar síntomas** | Muestra un catálogo de 28 síntomas agrupados por subsistema. Permite agregarlos por número o identificador, evita duplicados y permite eliminarlos. |
| **3. Ver información registrada** | Muestra los datos del vehículo y los síntomas de la sesión actual. |
| **4. Realizar diagnóstico** | Requiere un vehículo y al menos un síntoma. Consulta el motor Prolog y presenta las hipótesis compatibles con su explicación y recomendación. Informa cuando no hay resultados. |
| **5. Guardar sesión** | Guarda el vehículo, los síntomas y los resultados actuales en almacenamiento persistente. |
| **6. Recuperar sesión** | Restaura una sesión guardada, incluso después de cerrar y volver a abrir el programa. Reemplaza la sesión en memoria únicamente si la respuesta es válida. |
| **7. Generar reporte** | Crea un archivo de texto con los datos del vehículo, los síntomas y los resultados disponibles. |
| **0. Salir** | Finaliza la aplicación. |

En los formularios se utiliza `0` para cancelar o volver según la indicación de cada pantalla. En el campo **kilometraje**, `0` es un valor válido y se escribe `volver` para cancelar. Cancelar el registro de un vehículo conserva los datos anteriores.

La sesión admite hasta **20 síntomas y 20 resultados**. Cambiar el vehículo o agregar o eliminar síntomas invalida los resultados anteriores; se debe volver a diagnosticar.

**Observación conocida:** la selección rechaza formatos incorrectos y duplicados, pero permite agregar un identificador inexistente si tiene formato válido. Prolog lo rechaza al procesar la operación. Utilice los síntomas del catálogo mostrado.

## Arquitectura

| Componente | Responsabilidad | Archivos principales |
|---|---|---|
| Front-end C | Menú, formularios, catálogo visible, validaciones, visualización y sesión en memoria | `frontend/main.c`, `menu.c`, `interfaz.c`, `validaciones.c`, `tipos.h` |
| Integración | Serializa solicitudes, ejecuta SWI-Prolog y valida las respuestas antes de actualizar la sesión | `integracion/conexion.c`, `conexion.h` |
| Puente Prolog | Valida y distribuye las operaciones `consultar`, `guardar`, `recuperar` y `reportar` | `backend/puente.pl` |
| Motor lógico | Hechos, reglas, inferencias, consultas y explicaciones | `backend/hechos.pl`, `reglas.pl`, `inferencia.pl`, `consultas.pl`, `explicaciones.pl` |
| Almacenamiento y reportes | Guarda y recupera sesiones; escribe reportes de texto | `backend/persistencia.pl`, `reportes.pl` |

El flujo de una operación es: **menú C → integración → puente Prolog → motor o almacenamiento → respuesta al programa C**.

La comunicación utiliza archivos temporales `ipc_*.req` y sus respuestas `.res` en la raíz. C invoca el puente con `swipl` y elimina esos archivos al terminar normalmente la operación. El razonamiento automotriz está implementado en Prolog; C se encarga de la interacción y el transporte de datos.

## Base de conocimientos

- **Hechos:** describen subsistemas, combustibles, perfiles de vehículos, componentes, síntomas, fallas, pruebas de verificación y acciones correctivas. La auditoría contó **206 hechos de conocimiento distintos** en `hechos.pl`.
- **Reglas:** relacionan síntomas y características del vehículo para obtener diagnósticos preliminares y descartar hipótesis incompatibles. Se verificaron **51 cláusulas con cuerpo** en `reglas.pl`.
- **Inferencias compuestas:** encadenan condiciones para deducir estados intermedios. Existen **11 reglas de estados inferidos**, entre ellas la interrupción del circuito de arranque con batería sana.
- **Recursividad:** `contar_elementos/2`, `eliminar_duplicados_aux/3` y los filtros de síntomas recorren listas mediante casos base y pasos recursivos.
- **Listas:** se utilizan para gestionar síntomas y resultados, filtrar identificadores, eliminar repeticiones y recopilar alternativas.
- **Backtracking:** consultas como `fallas_por_sintoma/2`, `sintomas_por_falla/2` y `componentes_por_subsistema/2` permiten obtener varias soluciones.

Para explorar las consultas desde la raíz:

```powershell
swipl -q -s backend/consultas.pl
```

Ejemplos en la consola de Prolog:

```prolog
?- sintomas_por_subsistema(electrico, Sintomas).
?- fallas_por_sintoma(no_arranca, Falla).
?- contar_elementos([no_arranca, luces_tenues], Cantidad).
```

Cuando haya soluciones alternativas, `;` solicita la siguiente. `halt.` cierra SWI-Prolog.

## Persistencia y reportes

### Guardar y recuperar sesiones

En las opciones 5 y 6 se introduce un **identificador de sesión**, por ejemplo `revision_corolla`, sin ruta ni extensión. Aunque el menú menciona “nombre o ruta”, el backend admite únicamente letras ASCII, números, guion y guion bajo.

La sesión se guarda como `backend/sesiones/revision_corolla.ses`. El directorio se crea cuando es necesario. El archivo contiene un término Prolog con el vehículo, los síntomas y los resultados; al recuperarlo se lee como datos y se valida, sin ejecutarlo como código.

Guardar con un identificador existente puede reemplazar esa sesión. Para conservar registros anteriores, utilice identificadores distintos. Si la recuperación falla, la aplicación conserva la sesión actual y muestra un mensaje de error.

### Generar reportes

La opción 7 solicita una ruta de destino con el nombre y la extensión deseados, por ejemplo `reporte_corolla.txt`. El directorio de destino debe existir.

El reporte se escribe en UTF-8 e incluye vehículo, síntomas, diagnósticos, explicaciones y recomendaciones disponibles. Si todavía no se ha realizado un diagnóstico, indica que no hay resultados. Para incluir conclusiones, ejecute primero la opción 4.

El generador **rechaza sobrescribir un reporte existente**. Seleccione otro nombre para crear un nuevo archivo.

## Pruebas realizadas

Los casos se documentan en [pruebas/casos_prueba.txt](pruebas/casos_prueba.txt), con entradas, resultados esperados, resultados obtenidos, estado y evidencia.

| Caso | Comprobación |
|---|---|
| CP01 | Registro correcto de vehículo |
| CP02 | Rechazo y corrección de datos incorrectos |
| CP03 | Cancelación sin perder la sesión anterior |
| CP04 | Registro de un síntoma |
| CP05 | Control de síntomas duplicados |
| CP06 | Eliminación de un síntoma |
| CP07 | Visualización de la información registrada |
| CP08 | Diagnóstico con síntomas válidos |
| CP09 | Diagnósticos alternativos |
| CP10 | Inferencia compuesta |
| CP11 | Consultas con listas |
| CP12 | Reglas recursivas |
| CP13 | Soluciones mediante backtracking |
| CP14 | Guardar y recuperar una sesión entre procesos |
| CP15 | Generación y verificación del archivo de reporte |

Desde la raíz del proyecto, con GCC, SWI-Prolog y Python disponibles:

```powershell
python pruebas/ejecutar_pruebas.py
```

El ejecutor combina un arnés para las funciones reales del front-end y pruebas Prolog con `plunit`. Compila sus ejecutables y regenera las evidencias bajo `pruebas/`; conserva un reporte anterior con nombre fechado. La ruta de SWI-Prolog está configurada en el ejecutor como `C:\Program Files\swipl\bin\swipl.exe`, por lo que esa instalación debe estar disponible para utilizarlo sin cambios.

**Resultado respaldado por la auditoría del 16 de noviembre de 2026:** 15 casos preparados, 15 ejecutados, **15 aprobados**, 0 fallidos y 0 pendientes. La repetición se realizó en una copia aislada para conservar las evidencias originales.

La auditoría agregó recorridos del menú completo que comprobaron la comunicación real C–Prolog, diagnósticos con varias hipótesis y sin coincidencias, manejo de errores, persistencia entre ejecuciones y reportes. También verificó los mínimos del motor lógico: hechos, reglas, predicados, consultas, recursividad, listas, backtracking e inferencias compuestas.

Su estado general fue **APTO CON OBSERVACIONES**: además de la validación de síntomas descrita arriba, detectó un mensaje genérico para sesiones inexistentes y referencias desactualizadas en el README de ese momento. Una comprobación adicional esperaba un mensaje literal diferente y quedó registrada como fallida; esto es independiente de los 15 casos aprobados. La limpieza visual en una terminal interactiva quedó sin verificar. El informe conserva estos hallazgos históricos; este README actualiza la documentación.

## Estructura del proyecto

```text
Sistema-Experto-automotriz/
├── README.md
├── frontend/
│   ├── main.c
│   ├── menu.c / menu.h
│   ├── interfaz.c / interfaz.h
│   ├── validaciones.c / validaciones.h
│   └── tipos.h
├── integracion/
│   └── conexion.c / conexion.h
├── backend/
│   ├── hechos.pl
│   ├── reglas.pl
│   ├── inferencia.pl
│   ├── explicaciones.pl
│   ├── consultas.pl
│   ├── puente.pl
│   ├── persistencia.pl
│   └── reportes.pl
├── pruebas/
│   ├── ejecutar_pruebas.py
│   ├── pruebas_frontend.c
│   ├── pruebas_prolog.pl
│   ├── casos_prueba.txt
│   ├── evidencias_pruebas.txt
│   ├── resultados.json
│   ├── cp01_salida.txt ... cp15_salida.txt
│   ├── reporte_cp15.txt
│   └── auditoria_final_20261116/
│       ├── informe_auditoria.md
│       └── registros de ejecución y copia aislada de auditoría
├── documentacion/
└── datos/
```

`diagnostico.exe` es el ejecutable de la aplicación. `backend/sesiones/` se crea al guardar sesiones en el uso normal; la copia aislada de auditoría y el almacén de pruebas tienen sus propios archivos de evidencia.

## Documentación

| Documento o evidencia | Ubicación |
|---|---|
| Instrucciones de instalación y uso | Este README |
| Detalle de los 15 casos | [pruebas/casos_prueba.txt](pruebas/casos_prueba.txt) |
| Registro consolidado de pruebas | [pruebas/evidencias_pruebas.txt](pruebas/evidencias_pruebas.txt) |
| Pruebas Prolog automatizadas | [pruebas/pruebas_prolog.pl](pruebas/pruebas_prolog.pl) |
| Entradas y salidas por caso | Archivos `cp*_entrada.txt` y `cp*_salida.txt` en `pruebas/` |
| Ejemplo de reporte generado | [pruebas/reporte_cp15.txt](pruebas/reporte_cp15.txt) |
| Auditoría final y observaciones | [informe_auditoria.md](pruebas/auditoria_final_20261116/informe_auditoria.md) |
| Repetición auditada de las 15 pruebas | [15_pruebas.txt](pruebas/auditoria_final_20261116/15_pruebas.txt) |
| Integración completa desde el menú | [menu_04_05_07_extremo_a_extremo.txt](pruebas/auditoria_final_20261116/menu_04_05_07_extremo_a_extremo.txt) |

Actualmente no hay manuales separados en `documentacion/` ni archivos en `datos/`. La persistencia del sistema utiliza `backend/sesiones/`, no `datos/`.

## Equipo de desarrollo

| Integrante | Responsabilidades |
|---|---|
| **Joel** | Front-end en C: menú, formularios, validaciones y visualización; módulo de conexión con Prolog. |
| **Daniel** | Base de conocimientos y motor lógico en Prolog: hechos, reglas, inferencias, consultas y explicaciones diagnósticas. |
| **José** | Persistencia de sesiones y generación de reportes en Prolog. |
