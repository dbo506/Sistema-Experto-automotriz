from pathlib import Path
import subprocess,os,json,re,hashlib
R=Path.cwd();A=R/'pruebas/auditoria_final_20261116';W=A/'Sistema-Experto-automotriz';env=os.environ.copy();env['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\swipl\bin;'+env['PATH']
def run(name,cmd,inp=None):
 p=subprocess.run(cmd,cwd=W,env=env,input=inp,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=40)
 (A/(name+'.txt')).write_text('COMANDO: '+subprocess.list2cmdline(cmd)+'\nENTRADA:\n'+str(inp)+'\nCODIGO: '+str(p.returncode)+'\n'+p.stdout+p.stderr,encoding='utf-8');return p
# Aisla el defecto de validacion: identificador con formato valido pero ajeno al catalogo.
p=run('sintoma_desconocido_aceptado',[str(W/'auditoria.exe')],'2\n1\ninventado\n0\n3\n0\n0\n')
assert 'Sintoma agregado.' in p.stdout and 'inventado' in p.stdout
# Cuatro comprobaciones adicionales de cancelacion en campos de registro, preservando datos.
reg='1\nToyota\nCorolla\n2015\n100000\ngasolina\n0\n'
for i,partial in enumerate(['1\n0\n','1\nHonda\n0\n','1\nHonda\nCivic\n0\n','1\nHonda\nCivic\n2018\n12\n0\n'],1):
 p=run(f'cancelacion_campo_{i}',[str(W/'auditoria.exe')],reg+partial+'3\n0\n0\n');assert p.returncode==0 and 'Marca        : Toyota' in p.stdout and 'Modelo       : Corolla' in p.stdout
# Prueba de campos largos y kilometraje cero valido.
p=run('validacion_longitud_km_cero',[str(W/'auditoria.exe')],'1\n'+'A'*100+'\nToyota\nCorolla\n2015\n0\ngasolina\n0\n3\n0\n0\n');assert 'Entrada demasiado larga.' in p.stdout and 'Kilometraje  : 0 km' in p.stdout
# Tres escenarios relacionales de backtracking con mas de una solucion, no comentarios.
goal="findall(F,fallas_por_sintoma(no_arranca,F),A),sort(A,UA),length(UA,NA),NA>1,findall(S,sintomas_por_falla(bateria_descargada,S),B),sort(B,UB),length(UB,NB),NB>1,findall(C,componentes_por_subsistema(electrico,C),D),sort(D,UD),length(UD,ND),ND>1,writeln(fallas(NA,UA)),writeln(sintomas(NB,UB)),writeln(componentes(ND,UD))"
p=run('tres_backtracking',[r'C:\Program Files\swipl\bin\swipl.exe','-q','-s','backend/consultas.pl','-g',f'({goal}->halt(0);halt(1))']);assert p.returncode==0
originals=json.loads((A/'hashes_antes.json').read_text());changed=[p for p,h in originals.items() if hashlib.sha256((R/p).read_bytes()).hexdigest()!=h]
assert not changed
(A/'integridad_originales.json').write_text(json.dumps({'archivos_verificados':len(originals),'modificados':changed},indent=2),encoding='utf-8')
report='''# Auditoría final de ZYTRON — 16 de noviembre de 2026

**Estado general: APTO CON OBSERVACIONES.** Los flujos principales funcionan de extremo a extremo. Hay una validación incompleta en la selección de síntomas y documentación desactualizada. La limpieza visual de la terminal queda NO VERIFICADA.

Repositorio original: `C:\\Users\\joelm\\OneDrive\\Documentos\\2026\\Paradigmas\\Sistema-Experto-automotriz`, rama `main`. Solo se crearon archivos nuevos de auditoría bajo `pruebas/auditoria_final_20261116/`. Se compiló y ejecutó una copia idéntica del código en `Sistema-Experto-automotriz/` dentro de esa carpeta. No se modificó el código para aislarlo: las rutas relativas del propio programa apuntaron a la copia. No se sobrescribieron sesiones ni reportes originales.

## Siete opciones del menú

| Opción | Resultado | Evidencia |
|---|---|---|
| 1. Registrar vehículo | APROBADO: Toyota Corolla 2015 gasolina, 100000 km; rechazo de vacío, texto y año 1800, km negativos y campo demasiado largo; km cero válido; cancelar marca, modelo, año, km y combustible conserva registro | `menu_01_02_03_validaciones.txt`, `cancelacion_campo_1.txt` a `cancelacion_campo_4.txt`, `validacion_longitud_km_cero.txt` |
| 2. Seleccionar síntomas | CON OBSERVACIÓN: agrega los del catálogo, evita duplicados, elimina y rechaza formato/número inválidos. Acepta un identificador inexistente si su formato es válido | `menu_01_02_03_validaciones.txt`, `sintoma_desconocido_aceptado.txt` |
| 3. Información registrada | APROBADO: muestra vehículo y síntomas, conserva la sesión entre operaciones y cancelaciones | `menu_01_02_03_validaciones.txt`, `menu_cancelaciones.txt` |
| 4. Diagnóstico | APROBADO: diagnóstico real C–SWI, varias hipótesis con explicación y recomendación; sin resultados; contradicciones y motor ausente manejados sin bloqueo | `menu_04_05_07_extremo_a_extremo.txt`, `menu_sin_resultados.txt`, `menu_contradiccion.txt`, `menu_motor_no_disponible.txt` |
| 5. Guardar | APROBADO: sesión real con vehículo, cuatro síntomas y resultados serializados | `menu_04_05_07_extremo_a_extremo.txt`; copia: `backend/sesiones/auditoria_e2e.ses` |
| 6. Recuperar | APROBADO: otro proceso C restaura sesión y genera reporte idéntico byte a byte al previo; sesión ausente no cierra el programa | `menu_06_recuperacion_otro_proceso.txt`, `menu_errores_backend.txt` |
| 7. Reporte | APROBADO: archivo con datos, síntomas, varios diagnósticos, explicaciones, recomendaciones y cierre; rechaza sobrescritura y mantiene el hash | `menu_04_05_07_extremo_a_extremo.txt`, `menu_reporte_no_sobrescribe.txt`; copia: `reporte_auditoria_e2e.txt`, `reporte_recuperado.txt` |

Se recorrieron las siete opciones mediante stdin del ejecutable completo, no mediante un arnés. `0` permite volver en los flujos probados. En kilometraje, `0` registra un valor válido; se cancela con `volver`, como indica la pantalla. EOF en formulario termina sin bloqueo; no se observó un cierre inesperado en entradas completas. La pantalla llama a `system("cls")` en Windows y los registros contienen su efecto de control; su apariencia y limpieza en una consola interactiva NO se verificaron visualmente.

## Integración C–Prolog

APROBADA en ejecución real. `integracion/conexion.c` serializa la solicitud, invoca `swipl -q -s backend/puente.pl -g main -t halt -- entrada salida` y lee registros de respuesta. El puente valida y llama `diagnosticar/3`, `guardar_sesion/2`, `recuperar_sesion/2` y `generar_reporte/2`. Los archivos IPC se crearon y eliminaron en la copia. La sesión recuperada contiene Toyota/Corolla/2015/100000/gasolina y los cuatro síntomas enviados desde C. Los reportes anterior y posterior al reinicio resultaron idénticos. No se introdujeron motores simulados ni cambios en predicados.

El razonamiento está en Prolog (`reglas.pl`, `inferencia.pl`, `explicaciones.pl`). C contiene interfaz, validaciones, catálogo y transporte; no implementa reglas diagnósticas. Los 28 identificadores del catálogo C coinciden con Prolog (`comparacion_catalogo.txt`).

## Requisitos mínimos

Conteo mediante `read_term/3`: se excluyeron comentarios y directivas; los hechos ground y cláusulas se deduplicaron por término. Las cifras conservadoras siguientes bastan sin sumar funciones de infraestructura.

| Requisito | Mínimo | Comprobado | Ubicación | Cumple |
|---|---:|---:|---|---|
| Hechos de conocimiento | 40 | 206 hechos ground distintos | `backend/hechos.pl` | Sí |
| Reglas lógicas | 20 | 51 cláusulas con cuerpo en reglas; otras 59 en inferencia | `backend/reglas.pl`, `backend/inferencia.pl` | Sí |
| Predicados propios | 15 | 19 indicadores distintos solo en consultas | `backend/consultas.pl` | Sí |
| Consultas distintas | 10 | 10 ejecutadas con código 0 | `consulta_01.txt` a `consulta_10.txt`; `backend/consultas.pl` | Sí |
| Reglas recursivas | 2 | 4 predicados recursivos directos en consultas | `contar_elementos/2`, `eliminar_duplicados_aux/3`, `filtrar_sintomas_validos/2`, `filtrar_sintomas_desconocidos/2` | Sí |
| Operaciones con listas | 3 | Al menos 4: deduplicar, contar, filtrar válidos, filtrar desconocidos | `backend/consultas.pl`; CP11 y CP12 repetidos | Sí |
| Escenarios de backtracking | 3 | 3 ejecutados, cada uno con varias soluciones | `fallas_por_sintoma/2`, `sintomas_por_falla/2`, `componentes_por_subsistema/2`; `tres_backtracking.txt` | Sí |
| Inferencias compuestas | 5 | 11 cláusulas distintas de estados inferidos | `backend/inferencia.pl:estado_subsistema_inferido/4` | Sí |
| Casos documentados | 15 | 15 documentos de caso y 15 repetidos con éxito | `pruebas/casos_prueba.txt`, ejecución aislada | Sí |
| Explicaciones de conclusiones | 5 | 5 escenarios ejecutados con resultados, explicación y recomendación no vacíos; 7 cláusulas constructoras en fuente | `backend/explicaciones.pl`, `explicacion_01.txt` a `explicacion_05.txt` | Sí |

Las inferencias compuestas incluyen circuito de arranque con batería sana, bloqueo electromecánico, déficit de energía, falla de carga, suministro de combustible, mezcla rica, ignición, compromiso térmico, compresión, ECU y frenos. `conteos.json` registra los conteos por archivo. Esta evaluación aplica a los mínimos proporcionados en la solicitud; no se encontró el enunciado original completo para contrastar requisitos adicionales o su rúbrica exacta.

## Pruebas existentes y estabilidad

Se ejecutó el archivo original `python pruebas/ejecutar_pruebas.py` en la copia aislada: **15 preparadas, 15 ejecutadas, 15 aprobadas, 0 fallidas, 0 sin ejecutar**. Evidencia: `15_pruebas.txt` y la carpeta `Sistema-Experto-automotriz/pruebas/`. El ejecutor original reescribe sus evidencias y por eso no se ejecutó sobre los originales.

Los documentos originales `casos_prueba.txt` y `evidencias_pruebas.txt` contienen entradas, resultados, estados y salidas; los esperados están en `casos_prueba.txt`. Conservan su declaración correcta de alcance parcial del menú. Las nuevas comprobaciones de esta auditoría agregan el recorrido completo C–Prolog.

La compilación completa con GCC C11 y `-Wall -Wextra -pedantic -Werror` terminó con código 0 y sin advertencias. La carga de módulos de producción también terminó con código 0 y sin errores. Las diez consultas y cinco escenarios de explicaciones devolvieron código 0.

En el conjunto inicial de diez recorridos de menú hubo nueve aprobados y una comprobación fallida: `menu_errores_backend` esperaba literalmente “No se encontro la sesion solicitada.”, pero recibió “No se pudo leer o validar la sesion almacenada.”. La aplicación sí rechazó la sesión inexistente, conservó la información y continuó. Se conserva FALLIDO en el registro automático original; la revisión identifica una expectativa textual demasiado específica, no una falla de recuperación ni un bloqueo. Se reprodujo además la aceptación de un síntoma inexistente como hallazgo funcional independiente.

## Problemas detectados

1. **Media — validación de pertenencia incompleta en la opción 2.** Introducir `inventado` muestra `[OK] Sintoma agregado.` y queda visible en la sesión. `seleccionarSintomas()` valida formato y duplicados, pero no pertenencia al catálogo. El backend lo rechaza al diagnosticar; por tanto no produce un diagnóstico falso, pero la interfaz permite registrar una entrada que después impide operar. Evidencia: `sintoma_desconocido_aceptado.txt` y `menu_errores_backend.txt`.
2. **Baja — mensaje genérico para sesión inexistente.** `recuperar_sesion/2` envuelve `existence_error` en `persistencia_lectura`; el puente muestra un error genérico de lectura/validación. El flujo se recupera correctamente. No se corrigió ni se ocultó la comprobación fallida.
3. **Baja — README desactualizado.** Describe el puente como pendiente de implementación/validación y el catálogo como pendiente de proporcionar, aunque ambos existen y la integración funcionó. Archivo original conservado.
4. **Límite de verificación — limpieza visual NO VERIFICADA** en terminal interactiva. La prueba automatizada demuestra navegación, retornos y ausencia de bloqueo, no calidad visual.

No se detectaron errores bloqueantes en los flujos principales ensayados. No se aplicaron correcciones.

## Entregables encontrados y pendientes

Existen `README.md`, los 15 casos documentados, `pruebas/pruebas_prolog.pl`, `pruebas/evidencias_pruebas.txt`, registros individuales CP01–CP15 y fuentes completas: 4 archivos `.c` y 4 `.h` en frontend, `conexion.c/.h` en integración y 8 archivos `.pl` en backend. `documentacion/` y `datos/` no contienen archivos en esta revisión. No se encontró el enunciado original completo. No se generaron documentos faltantes del profesor; este informe es únicamente la evidencia de auditoría solicitada.

## Comandos y evidencias

Los comandos concretos, directorio de trabajo, stdin, stdout/stderr y códigos están en cada `.txt` de esta carpeta. Se usó un PATH de proceso con `C:\\msys64\\ucrt64\\bin` y `C:\\Program Files\\swipl\\bin`.

```powershell
gcc -std=c11 -Wall -Wextra -pedantic -Werror frontend/main.c frontend/menu.c frontend/interfaz.c frontend/validaciones.c integracion/conexion.c -o auditoria.exe
python pruebas/ejecutar_pruebas.py
.\\auditoria.exe
& 'C:\\Program Files\\swipl\\bin\\swipl.exe' -q -g "consult('backend/puente.pl'),consult('backend/consultas.pl'),halt"
& 'C:\\Program Files\\swipl\\bin\\swipl.exe' -q -s conteo_auditoria.pl -g main -t halt
```

Los comandos anteriores se ejecutaron desde la copia aislada, no sobre la raíz original. `auditar.py` preserva el procedimiento inicial; sus archivos existentes no deben sobrescribirse para repetirlo: debe elegirse otra carpeta aislada.

## Integridad

Se verificaron SHA-256 de 54 archivos originales antes y después: **0 modificados** (`integridad_originales.json`, `hashes_antes.json`). Incluyen fuentes, pruebas, ejecutables, evidencias, reportes y sesiones existentes bajo las carpetas inspeccionadas, además del README. No se sobrescribió `diagnostico.exe`. No se realizaron commits, pushes, merges, cambios de rama ni acciones sobre otros proyectos. Git permanece en `main` con `pruebas/` sin seguimiento, como al inicio.
'''
(A/'informe_auditoria.md').write_text(report,encoding='utf-8')
print('Informe guardado. Integridad:',len(originals),'archivos,',len(changed),'modificados.')
