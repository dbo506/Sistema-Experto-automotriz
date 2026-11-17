% ============================================================================
% Proyecto: ZYTRON - Sistema Experto de Diagnostico Automotriz
% Archivo : backend/reportes.pl
% Modulo  : Generacion de reportes textuales de diagnostico
% ============================================================================
% API:
%   generar_reporte(+Ruta, +Sesion)
%
% La ruta se usa unicamente como destino de escritura. Se admiten rutas
% relativas y absolutas (incluidas las rutas de Windows). El archivo debe
% tener ya el nombre y la extension deseados. Si ya existe, el modulo lo
% detecta antes de abrirlo y lanza permission_error(overwrite, file, Ruta).
% ============================================================================

:- ensure_loaded('persistencia.pl').

% generar_reporte(+Ruta, +Sesion)
% Valida la sesion reutilizando validar_sesion/1, exige un vehiculo y crea un
% reporte UTF-8. Si ocurre un error tras crear el destino, intenta cerrar y
% eliminar el archivo incompleto antes de propagar la excepcion.
generar_reporte(Ruta, Sesion) :-
    validar_ruta_reporte(Ruta),
    validar_sesion(Sesion),
    (   Sesion = sesion(vehiculo(_, _, _, _, _), _, _)
    ->  true
    ;   throw(error(domain_error(sesion_con_vehiculo, Sesion), _))
    ),
    catch(
        escribir_reporte(Ruta, Sesion),
        Error,
        throw(error(generacion_reporte(Ruta, Error), _))
    ).

% validar_ruta_reporte(+Ruta)
% Exige un atomo no vacio, sin controles y de hasta 159 bytes UTF-8, el
% maximo que puede transportar el buffer recurso[160] del frontend.
validar_ruta_reporte(Ruta) :-
    (   atom(Ruta), texto_atomico_valido(Ruta, 159)
    ->  true
    ;   throw(error(domain_error(ruta_de_reporte, Ruta), _))
    ),
    file_directory_name(Ruta, Directorio),
    (   exists_directory(Directorio)
    ->  true
    ;   throw(error(existence_error(directory, Directorio), _))
    ).

% escribir_reporte(+Ruta, +Sesion)
% Se usa un directorio de bloqueo creado con make_directory/1 para serializar
% las llamadas cooperantes que apuntan a la misma ruta. Luego se comprueba
% explícitamente exists_file/1 antes de abrir el destino. La comprobación del
% destino y open/4 no son una creación exclusiva atómica frente a programas
% externos que no respeten este bloqueo.
escribir_reporte(Ruta, sesion(vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible), Sintomas, Resultados)) :-
    atom_concat(Ruta, '.zytron.lock', RutaBloqueo),
    make_directory(RutaBloqueo),
    setup_call_cleanup(
        true,
        escribir_reporte_bajo_bloqueo(
            Ruta, Marca, Modelo, Anio, Kilometraje, Combustible,
            Sintomas, Resultados
        ),
        delete_directory(RutaBloqueo)
    ).

% escribir_reporte_bajo_bloqueo(+Ruta, +Marca, +Modelo, +Anio, +Km,
%                               +Combustible, +Sintomas, +Resultados)
% El candado impide que otra llamada de este modulo pase simultaneamente la
% comprobacion de existencia. Si ya existe, el destino no se abre.
escribir_reporte_bajo_bloqueo(Ruta, Marca, Modelo, Anio, Kilometraje,
                              Combustible, Sintomas, Resultados) :-
    (   exists_file(Ruta)
    ->  throw(error(permission_error(overwrite, file, Ruta), _))
    ;   true
    ),
    open(Ruta, write, Flujo, [encoding(utf8), type(text)]),
    catch(
        setup_call_cleanup(
            true,
            (   escribir_contenido_reporte(
                    Flujo, Marca, Modelo, Anio, Kilometraje, Combustible,
                    Sintomas, Resultados
                ),
                flush_output(Flujo)
            ),
            close(Flujo)
        ),
        Error,
        (   catch(delete_file(Ruta), _, true),
            throw(Error)
        )
    ).

% escribir_contenido_reporte(+Flujo, +Marca, +Modelo, +Anio, +Km,
%                            +Combustible, +Sintomas, +Resultados)
% Escribe secciones legibles sin crear ni inferir datos diagnosticos.
escribir_contenido_reporte(Flujo, Marca, Modelo, Anio, Kilometraje,
                           Combustible, Sintomas, Resultados) :-
    format(Flujo, '============================================================~n', []),
    format(Flujo, '                         ZYTRON~n', []),
    format(Flujo, '          REPORTE DE DIAGNÓSTICO AUTOMOTRIZ~n', []),
    format(Flujo, '============================================================~n~n', []),
    format(Flujo, 'DATOS DEL VEHÍCULO~n', []),
    format(Flujo, '------------------------------------------------------------~n', []),
    format(Flujo, 'Marca:       ~a~n', [Marca]),
    format(Flujo, 'Modelo:      ~a~n', [Modelo]),
    format(Flujo, 'Año:         ~d~n', [Anio]),
    format(Flujo, 'Kilometraje: ~d km~n', [Kilometraje]),
    format(Flujo, 'Combustible: ~a~n~n', [Combustible]),
    format(Flujo, 'SÍNTOMAS REGISTRADOS~n', []),
    format(Flujo, '------------------------------------------------------------~n', []),
    escribir_sintomas(Flujo, Sintomas),
    format(Flujo, '~nRESULTADOS DEL DIAGNÓSTICO~n', []),
    format(Flujo, '------------------------------------------------------------~n', []),
    escribir_resultados(Flujo, Resultados),
    format(Flujo, '~n============================================================~n', []),
    format(Flujo, 'Reporte generado por ZYTRON.~n', []),
    format(Flujo, 'Fin del reporte.~n', []).

% escribir_sintomas(+Flujo, +Sintomas)
% Enumera los identificadores conservando su orden. Los guiones bajos se
% muestran como espacios para facilitar la lectura; el identificador original
% tambien queda visible sin cambios.
escribir_sintomas(Flujo, []) :-
    !,
    format(Flujo, 'No se registraron síntomas.~n', []).
escribir_sintomas(Flujo, Sintomas) :-
    escribir_sintomas(Sintomas, Flujo, 1).

escribir_sintomas([], _, _).
escribir_sintomas([Sintoma|Resto], Flujo, Numero) :-
    atom_chars(Sintoma, Caracteres),
    guiones_a_espacios(Caracteres, CaracteresLegibles),
    atom_chars(Legible, CaracteresLegibles),
    format(Flujo, '  ~d. ~a (~a)~n', [Numero, Legible, Sintoma]),
    Siguiente is Numero + 1,
    escribir_sintomas(Resto, Flujo, Siguiente).

guiones_a_espacios([], []).
guiones_a_espacios(['_'|Resto], [' '|Legibles]) :-
    !,
    guiones_a_espacios(Resto, Legibles).
guiones_a_espacios([Caracter|Resto], [Caracter|Legibles]) :-
    guiones_a_espacios(Resto, Legibles).

% escribir_resultados(+Flujo, +Resultados)
% Presenta todos los resultados validados o informa expresamente que aun no
% hay diagnosticos disponibles.
escribir_resultados(Flujo, []) :-
    !,
    format(Flujo, 'Aún no hay resultados de diagnóstico.~n', []).
escribir_resultados(Flujo, Resultados) :-
    escribir_resultados(Resultados, Flujo, 1).

escribir_resultados([], _, _).
escribir_resultados([resultado(Diagnostico, Explicacion, Recomendacion)|Resto],
                    Flujo, Numero) :-
    format(Flujo, '~nResultado ~d~n', [Numero]),
    format(Flujo, '  Diagnóstico:   ~a~n', [Diagnostico]),
    format(Flujo, '  Explicación:   ~a~n', [Explicacion]),
    format(Flujo, '  Recomendación: ~a~n', [Recomendacion]),
    Siguiente is Numero + 1,
    escribir_resultados(Resto, Flujo, Siguiente).
