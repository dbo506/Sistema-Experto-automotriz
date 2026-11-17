# Sistema Experto de Diagnostico Automotriz

Front-end C11 de Joel. No contiene inferencia automotriz ni implementa la persistencia o generacion de reportes de Jose. main.c conserva su llamada original a ejecutarMenu().

## Compilar y ejecutar en PowerShell

Desde la raiz del repositorio:

~~~powershell
$env:Path = "C:\msys64\ucrt64\bin;C:\Program Files\swipl\bin;" + $env:Path
gcc -std=c11 -Wall -Wextra -pedantic frontend\main.c frontend\menu.c frontend\interfaz.c frontend\validaciones.c integracion\conexion.c -o diagnostico.exe
.\diagnostico.exe
~~~

Adapte las rutas si las instalaciones estan en otra ubicacion. Ejecute siempre desde la raiz; se busca backend/puente.pl relativo al directorio actual. No se requiere enlazar libswipl: se usa un proceso swipl.

## Uso

La sesion vive en memoria. Registro y actualizacion se confirman solo al completar todos los campos. EOF cancela la entrada y termina sin bucles infinitos. Cambiar vehiculo o sintomas invalida los resultados. Se admiten 20 sintomas y 20 resultados. Los textos tienen limites por bytes definidos en tipos.h; se rechazan entradas demasiado largas.

Los sintomas se introducen por identificador del catalogo que Daniel debe proporcionar: letra minuscula inicial y luego a-z, 0-9 o _. No hay un catalogo automotriz inventado en C. El combustible es un texto obligatorio; el dominio de valores debe acordarse con el back-end.

Las opciones 5 y 6 solicitan persistencia a Prolog; la opcion 7 muestra los datos actuales y solicita a Prolog generar un reporte en la ruta indicada (0 vuelve sin generar). La recuperacion reemplaza la sesion solo si toda la respuesta es valida.

## Contrato propuesto C / SWI-Prolog (version 1)

Este contrato esta preparado en C, pendiente de implementacion y acuerdo con Daniel y Jose. No se ha validado contra su motor real.

El archivo backend/puente.pl debe definir main/0, sin initialization(main) adicional, pues C lo invoca asi:

~~~text
swipl -q -s backend/puente.pl -g main -t halt -- ARCHIVO_ENTRADA ARCHIVO_SALIDA
~~~

main/0 obtiene ambas rutas con current_prolog_flag(argv, [Entrada,Salida]), abre Entrada con encoding(utf8), lee un termino mediante read_term/3 y escribe Salida como UTF-8 sin BOM, cerrandola antes de finalizar. La salida ya existe como archivo vacio: abrir con write, no append. Salida estandar queda disponible para mensajes del motor. El proceso debe finalizar con codigo 0 solo cuando haya escrito una respuesta completa; errores deben producir ERROR o codigo distinto de cero. El puente debe capturar excepciones y limitar el tiempo de inferencia, por ejemplo con call_with_time_limit/2. La llamada C es sincrona y no impone un timeout externo.

Entrada:

~~~prolog
solicitud(1, Operacion, Recurso,
          sesion(Vehiculo, Sintomas, Resultados)).
~~~

- Operacion: consultar, guardar, recuperar o reportar.
- Recurso: atomo vacio para consultar; nombre/ruta para las otras operaciones. Es un dato, nunca codigo para ejecutar.
- Vehiculo: vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible), o sin_vehiculo si aun no se registro.
- Sintomas: lista de atomos identificadores, sin duplicados.
- Resultados: lista de resultado(Diagnostico, Explicacion, Recomendacion), conservados para guardar o reportar.
- Los textos son atomos entre comillas simples en UTF-8. Las comillas y barras inversas se escapan como \xHH\ para read_term/3. Abrir entrada y salida explicitamente con encoding(utf8). La consola debe proporcionar texto UTF-8 para conservar acentos (en Windows puede usar chcp 65001 antes de ejecutar). No evaluar los atomos como codigo.
- Anio y kilometraje son enteros. Los limites y longitudes de la respuesta deben respetar tipos.h.

Respuesta: registros separados por salto de linea, campos separados por UN tabulador real. Cada registro, incluido FIN, termina en salto de linea. No incluir tabuladores, saltos de linea ni controles dentro de un campo; reemplazarlos por espacios. Todos los textos son obligatorios y deben caber en sus buffers (capacidad menos uno). No se admiten columnas adicionales ni registros desconocidos.

Consultar: cero o mas registros RESULTADO y luego FIN. Una respuesta FIN sola significa consulta valida sin diagnosticos.

~~~text
RESULTADO<TAB>Diagnostico<TAB>Explicacion<TAB>Recomendacion
FIN
~~~

Guardar o reportar: confirmar OK solo despues de que la operacion real haya terminado:

~~~text
OK
FIN
~~~

Recuperar: exactamente un VEHICULO, cero a veinte SINTOMA sin duplicados, cero a veinte RESULTADO, y FIN:

~~~text
VEHICULO<TAB>Marca<TAB>Modelo<TAB>Anio<TAB>Kilometraje<TAB>Combustible
SINTOMA<TAB>identificador
RESULTADO<TAB>Diagnostico<TAB>Explicacion<TAB>Recomendacion
FIN
~~~

Error para cualquier operacion:

~~~text
ERROR<TAB>Descripcion del error
FIN
~~~

Los rotulos <TAB> anteriores representan el caracter de tabulacion, no texto literal. Los mensajes de depuracion deben ir a stdout/stderr, nunca al archivo de respuesta. El parser rechaza respuestas incompletas y conserva la sesion previa.

## Responsabilidades pendientes

Se propone que el puente main/0 delegue en estos predicados, que deben implementar o adaptar los companeros:

- Daniel: diagnosticar(+Vehiculo, +Sintomas, -Resultados), con los terminos definidos arriba, y el catalogo oficial de sintomas. Sin coincidencias devuelve [].
- Jose: guardar_sesion(+Recurso, +Sesion), recuperar_sesion(+Recurso, -Sesion), generar_reporte(+Recurso, +Sesion). Deben realizar la persistencia y escribir el reporte, no solo confirmar.
- Daniel y Jose: main/0 como adaptador del contrato; validar datos, manejar sintomas desconocidos, serializar las respuestas y propagar errores. Los nombres internos pueden cambiar si el puente mantiene el protocolo.

C no crea ni modifica backend/. Los archivos ipc_*.req y sus .res son temporales locales abiertos con modo exclusivo C11; se eliminan al finalizar una llamada normal. Una interrupcion forzada puede dejarlos en la raiz. No se interpolan textos del usuario en comandos del shell.

## Verificacion realizada

Compilacion con GCC 16.2.0, C11, -Wall -Wextra -pedantic sin advertencias. Pruebas de consola automatizadas: registro/resumen, campos vacios, numeros y opciones invalidas, duplicados, identificadores invalidos, agregar/quitar sintomas, entrada demasiado larga, EOF, prerrequisitos y ausencia de backend/puente.pl. SWI-Prolog esta instalado; no existe back-end en este repositorio al implementar este modulo.

Pendiente: probar el protocolo completo con el puente y motor de los companeros. Cuando esten disponibles, registrar un vehiculo y sintomas oficiales, consultar con y sin coincidencias, guardar, modificar, recuperar y verificar todos los campos; generar un reporte y verificar su archivo. Probar tambien excepciones, respuesta incompleta/malformada y ejecutar sin swipl en PATH. Ninguna de estas verificaciones pendientes se afirma como ejecutada.