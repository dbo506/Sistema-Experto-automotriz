% ============================================================================
% Proyecto: ZYTRON - Sistema Experto de Diagnostico Automotriz
% Archivo : backend/puente.pl
% Modulo  : Adaptador del protocolo de archivos C / SWI-Prolog
% ============================================================================
% Entrada:  solicitud(1, Operacion, Recurso, sesion(Vehiculo,Sintomas,Resultados)).
% Salida:   registros tabulados UTF-8 terminados en FIN.
%
% Este archivo solo valida, despacha y serializa. El razonamiento, persistencia
% y reportes se delegan a los modulos existentes.
% ============================================================================

:- use_module(library(time), [call_with_time_limit/2]).
:- ensure_loaded('explicaciones.pl').
:- ensure_loaded('reportes.pl').

% main/0
% Consume los dos argumentos entregados por C despues de --. Los errores de
% solicitud se convierten en ERROR/FIN; los errores al escribir la respuesta
% se informan por stderr y terminan el proceso con codigo distinto de cero.
main :-
    current_prolog_flag(argv, Argumentos),
    (   Argumentos = [RutaEntrada, RutaSalida]
    ->  true
    ;   format(user_error, 'ZYTRON: se requieren archivo de entrada y salida.~n', []),
        halt(2)
    ),
    catch(
        (   procesar_solicitud(RutaEntrada, Respuesta),
            validar_respuesta_c(Respuesta)
        ),
        Error,
        (   traducir_error(Error, Respuesta),
            validar_respuesta_c(Respuesta)
        )
    ),
    catch(
        escribir_respuesta(RutaSalida, Respuesta),
        ErrorEscritura,
        (   print_message(error, ErrorEscritura),
            halt(2)
        )
    ).

% procesar_solicitud(+RutaEntrada, -Respuesta)
% Limita el tiempo de lectura, validacion y ejecucion de una operacion.
procesar_solicitud(RutaEntrada, Respuesta) :-
    call_with_time_limit(
        15,
        (   leer_solicitud(RutaEntrada, Solicitud),
            validar_solicitud(Solicitud),
            despachar_solicitud(Solicitud, Respuesta)
        )
    ).

% leer_solicitud(+RutaEntrada, -Solicitud)
% Lee exactamente un termino como dato; no evalua el termino ni permite
% terminos adicionales en el archivo.
leer_solicitud(RutaEntrada, Solicitud) :-
    setup_call_cleanup(
        open(RutaEntrada, read, Flujo, [encoding(utf8), type(text), bom(true)]),
        (   read_term(Flujo, Termino, [syntax_errors(error)]),
            (   Termino == end_of_file
            ->  throw(error(domain_error(solicitud_vacia, archivo_entrada), _))
            ;   true
            ),
            read_term(Flujo, TerminoFinal, [syntax_errors(error)]),
            (   TerminoFinal == end_of_file
            ->  Solicitud = Termino
            ;   throw(error(domain_error(un_solo_termino, archivo_entrada), _))
            )
        ),
        close(Flujo)
    ).

% validar_solicitud(+Solicitud)
% Acepta solo la version, las cuatro operaciones y la estructura de sesion del
% protocolo C. Exige datos ground para evitar solicitudes parcialmente libres.
validar_solicitud(Solicitud) :-
    (   ground(Solicitud),
        Solicitud = solicitud(Version, Operacion, Recurso, sesion(_, _, _))
    ->  true
    ;   throw(error(domain_error(solicitud_zytron, Solicitud), _))
    ),
    (   Version =:= 1
    ->  true
    ;   throw(error(domain_error(version_protocolo, Version), _))
    ),
    (   memberchk(Operacion, [consultar, guardar, recuperar, reportar])
    ->  true
    ;   throw(error(domain_error(operacion_zytron, Operacion), _))
    ),
    (   atom(Recurso)
    ->  true
    ;   throw(error(type_error(atom, Recurso), _))
    ).

% despachar_solicitud(+Solicitud, -Registros)
% Vincula cada operacion del protocolo con la interfaz existente.
despachar_solicitud(solicitud(1, consultar, Recurso, Sesion), Registros) :-
    (   Recurso == ''
    ->  true
    ;   throw(error(domain_error(recurso_vacio_para_consulta, Recurso), _))
    ),
    validar_sesion_con_vehiculo(Sesion),
    Sesion = sesion(Vehiculo, Sintomas, _),
    diagnosticar(Vehiculo, Sintomas, Resultados),
    validar_sesion(sesion(Vehiculo, Sintomas, Resultados)),
    registros_resultados(Resultados, Registros).

despachar_solicitud(solicitud(1, guardar, Recurso, Sesion), [ok]) :-
    validar_recurso(Recurso, _),
    validar_sesion_con_vehiculo(Sesion),
    guardar_sesion(Recurso, Sesion).

despachar_solicitud(solicitud(1, recuperar, Recurso, _SesionEntrada), Registros) :-
    validar_recurso(Recurso, _),
    recuperar_sesion(Recurso, Sesion),
    validar_sesion_con_vehiculo(Sesion),
    Sesion = sesion(vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible),
                    Sintomas, Resultados),
    Registros = [vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)|Resto],
    registros_sintomas(Sintomas, RegistrosSintomas),
    append(RegistrosSintomas, RegistrosResultados, Resto),
    registros_resultados(Resultados, RegistrosResultados).

despachar_solicitud(solicitud(1, reportar, Ruta, Sesion), [ok]) :-
    validar_ruta_reporte(Ruta),
    validar_sesion_con_vehiculo(Sesion),
    generar_reporte(Ruta, Sesion).

% validar_sesion_con_vehiculo(+Sesion)
% Reutiliza la validacion completa de persistencia y exige un vehiculo porque
% el contrato de C no puede representar una operacion exitosa sin VEHICULO.
validar_sesion_con_vehiculo(Sesion) :-
    (   Sesion = sesion(Vehiculo, Sintomas, _)
    ->  true
    ;   throw(error(domain_error(sesion_zytron, Sesion), _))
    ),
    validar_sintomas_oficiales(Sintomas),
    validar_sesion(Sesion),
    (   Vehiculo = vehiculo(_, _, _, _, _)
    ->  true
    ;   throw(error(domain_error(sesion_con_vehiculo, Sesion), _))
    ).

% validar_sintomas_oficiales(+Sintomas)
% Comprueba primero la forma y el limite para obtener un error descriptivo con
% sintomas_desconocidos/2, y despues rechaza cualquier identificador ajeno al
% catalogo. No filtra elementos silenciosamente.
validar_sintomas_oficiales(Sintomas) :-
    (   is_list(Sintomas)
    ->  true
    ;   throw(error(type_error(list, Sintomas), _))
    ),
    length(Sintomas, Cantidad),
    (   Cantidad =< 20
    ->  true
    ;   throw(error(domain_error(maximo_sintomas, Cantidad), _))
    ),
    forall(
        member(Sintoma, Sintomas),
        (   sintoma_id_formato(Sintoma)
        )
    ),
    sintomas_desconocidos(Sintomas, Desconocidos),
    (   Desconocidos == []
    ->  true
    ;   throw(error(sintomas_desconocidos(Desconocidos), _))
    ).

% sintoma_id_formato(+Sintoma)
% Limita el diagnostico de identificadores desconocidos al alfabeto aceptado
% por el frontend C: minuscula inicial, seguida de minusculas, digitos o _.
sintoma_id_formato(Sintoma) :-
    (   atom(Sintoma), texto_atomico_valido(Sintoma, 63),
        atom_codes(Sintoma, [Primero|Resto]),
        Primero >= 0'a, Primero =< 0'z,
        codigos_sintoma_validos(Resto)
    ->  true
    ;   throw(error(domain_error(identificador_sintoma, Sintoma), _))
    ).

codigos_sintoma_validos([]).
codigos_sintoma_validos([Codigo|Resto]) :-
    (   (Codigo >= 0'a, Codigo =< 0'z)
    ;   (Codigo >= 0'0, Codigo =< 0'9)
    ;   Codigo =:= 0'_
    ),
    codigos_sintoma_validos(Resto).

% registros_sintomas(+Sintomas, -Registros)
% Convierte cada identificador validado al registro que espera C.
registros_sintomas([], []).
registros_sintomas([Sintoma|Resto], [sintoma(Sintoma)|Registros]) :-
    registros_sintomas(Resto, Registros).

% registros_resultados(+Resultados, -Registros)
% Conserva los resultados producidos o recuperados sin alterar sus campos.
registros_resultados([], []).
registros_resultados(
    [resultado(Diagnostico, Explicacion, Recomendacion)|Resto],
    [resultado(Diagnostico, Explicacion, Recomendacion)|Registros]
) :-
    registros_resultados(Resto, Registros).

% traducir_error(+Excepcion, -Registros)
% Genera una descripcion breve y segura para el protocolo, sin traza interna.
traducir_error(error(sintomas_desconocidos(Ids), _), [error(Mensaje)]) :-
    with_output_to(atom(IdsTexto), write_term(Ids, [quoted(true)])),
    format(atom(Mensaje), 'Sintomas desconocidos: ~a', [IdsTexto]),
    !.
traducir_error(error(domain_error(sintomas_contradictorios, Pares), _), [error(Mensaje)]) :-
    with_output_to(atom(ParesTexto), write_term(Pares, [quoted(true)])),
    format(atom(Mensaje), 'Sintomas incompatibles: ~a', [ParesTexto]),
    !.
traducir_error(error(domain_error(perfil_vehiculo_incompatible, _), _),
               [error('El combustible no coincide con el perfil catalogado del vehiculo.')]) :-
    !.
traducir_error(error(domain_error(arquitectura_vehiculo_no_confirmada, _), _),
               [error('Perfil de vehiculo no catalogado; no se confirma su arquitectura para estos sintomas.')]) :-
    !.
traducir_error(time_limit_exceeded, [error('Tiempo limite excedido al procesar la solicitud.')]) :-
    !.
traducir_error(error(existence_error(file, _), _), [error('No se encontro la sesion solicitada.')]) :-
    !.
traducir_error(error(permission_error(overwrite, file, _), _), [error('El archivo de reporte ya existe; no se sobrescribio.')]) :-
    !.
traducir_error(error(generacion_reporte(_, error(permission_error(overwrite, file, _), _)), _),
               [error('El archivo de reporte ya existe; no se sobrescribio.')]) :-
    !.
traducir_error(error(persistencia_lectura(_, _), _), [error('No se pudo leer o validar la sesion almacenada.')]) :-
    !.
traducir_error(error(persistencia_escritura(_, _), _), [error('No se pudo guardar la sesion.')]) :-
    !.
traducir_error(error(generacion_reporte(_, _), _), [error('No se pudo generar el reporte.')]) :-
    !.
traducir_error(error(domain_error(identificador_de_sesion, _), _), [error('Identificador de sesion invalido.')]) :-
    !.
traducir_error(error(domain_error(ruta_de_reporte, _), _), [error('Ruta de reporte invalida.')]) :-
    !.
traducir_error(error(existence_error(directory, _), _), [error('El directorio de destino no existe.')]) :-
    !.
traducir_error(error(domain_error(sesion_con_vehiculo, _), _), [error('La operacion requiere una sesion con vehiculo valido.')]) :-
    !.
traducir_error(error(domain_error(sesion_valida, _), _), [error('La estructura o los datos de la sesion son invalidos.')]) :-
    !.
traducir_error(_, [error('Solicitud invalida o la operacion no pudo completarse.')]).

% validar_respuesta_c(+Registros)
% Valida de forma explicita el contenido que se serializara en los buffers C.
% Tambien garantiza que la forma y el orden de los registros sea admitido por
% recibir() en conexion.c.
validar_respuesta_c([]).
validar_respuesta_c([ok]).
validar_respuesta_c([error(Mensaje)]) :-
    validar_texto_c(Mensaje, 1800).
validar_respuesta_c([resultado(Diagnostico, Explicacion, Recomendacion)|Resto]) :-
    validar_resultado_c(resultado(Diagnostico, Explicacion, Recomendacion)),
    validar_resultados_c(Resto, 1).
validar_respuesta_c(
    [vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)|Resto]
) :-
    validar_vehiculo_c(vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)),
    validar_registros_recuperacion(Resto, Sintomas, Resultados),
    length(Sintomas, CantidadSintomas),
    CantidadSintomas =< 20,
    sort(Sintomas, SintomasUnicos),
    length(SintomasUnicos, CantidadSintomas),
    length(Resultados, CantidadResultados),
    CantidadResultados =< 20.
validar_respuesta_c(Registros) :-
    throw(error(domain_error(respuesta_c, Registros), _)).

% validar_registros_recuperacion(+Registros, -Sintomas, -Resultados)
% Exige VEHICULO primero (validado por el llamador), luego todos los sintomas
% y, al final, todos los resultados, tal como exige recibir() en C.
validar_registros_recuperacion(Registros, Sintomas, Resultados) :-
    tomar_registros_sintoma(Registros, Sintomas, Resto),
    validar_registros_resultado(Resto, Resultados).

tomar_registros_sintoma([sintoma(Id)|Resto], [Id|Ids], Final) :-
    !,
    validar_texto_c(Id, 63),
    sintoma_id_formato(Id),
    tomar_registros_sintoma(Resto, Ids, Final).
tomar_registros_sintoma(Registros, [], Registros).

validar_registros_resultado([], []).
validar_registros_resultado(
    [resultado(Diagnostico, Explicacion, Recomendacion)|Resto],
    [resultado(Diagnostico, Explicacion, Recomendacion)|Resultados]
) :-
    validar_resultado_c(resultado(Diagnostico, Explicacion, Recomendacion)),
    validar_registros_resultado(Resto, Resultados).

validar_resultados_c([], Cantidad) :-
    Cantidad =< 20,
    !.
validar_resultados_c([resultado(Diagnostico, Explicacion, Recomendacion)|Resto], N) :-
    N < 20,
    validar_resultado_c(resultado(Diagnostico, Explicacion, Recomendacion)),
    Siguiente is N + 1,
    validar_resultados_c(Resto, Siguiente).
validar_resultados_c(Resultados, _) :-
    throw(error(domain_error(lista_resultados_c, Resultados), _)).

validar_resultado_c(resultado(Diagnostico, Explicacion, Recomendacion)) :-
    validar_texto_c(Diagnostico, 159),
    validar_texto_c(Explicacion, 511),
    validar_texto_c(Recomendacion, 511).
validar_resultado_c(Resultado) :-
    throw(error(domain_error(resultado_c, Resultado), _)).

validar_vehiculo_c(vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)) :-
    validar_texto_c(Marca, 63),
    validar_texto_c(Modelo, 63),
    integer(Anio), Anio >= 1886, Anio =< 9999,
    integer(Kilometraje), Kilometraje >= 0, Kilometraje =< 2147483647,
    validar_texto_c(Combustible, 31).
validar_vehiculo_c(Vehiculo) :-
    throw(error(domain_error(vehiculo_c, Vehiculo), _)).

% validar_texto_c(+Atomo, +MaximoBytes)
% Comprueba tipos, campo no vacio, longitud UTF-8 en bytes y ausencia de todo
% control ASCII (incluidos tabuladores y CR/LF) antes de escribirlo para C.
validar_texto_c(Atomo, MaximoBytes) :-
    (   atom(Atomo)
    ->  true
    ;   throw(error(type_error(atom, Atomo), _))
    ),
    atom_codes(Atomo, Codigos),
    (   Codigos = [_|_]
    ->  true
    ;   throw(error(domain_error(campo_no_vacio, Atomo), _))
    ),
    longitud_utf8_bytes(Atomo, Bytes),
    (   Bytes =< MaximoBytes
    ->  true
    ;   throw(error(representation_error(campo_utf8_demasiado_largo), _))
    ),
    forall(member(Codigo, Codigos), codigo_no_control(Codigo)).

codigo_no_control(Codigo) :-
    (   integer(Codigo), Codigo >= 32, Codigo =\= 127
    ->  true
    ;   throw(error(domain_error(caracter_de_control, Codigo), _))
    ).

% longitud_utf8_bytes(+Atomo, -Bytes)
% Cuenta los bytes UTF-8 correspondientes a cada punto de codigo del atomo.
longitud_utf8_bytes(Atomo, Bytes) :-
    atom(Atomo),
    atom_codes(Atomo, Codigos),
    longitud_utf8_bytes_(Codigos, 0, Bytes).

longitud_utf8_bytes_([], Acumulado, Acumulado).
longitud_utf8_bytes_([Codigo|Resto], Acumulado, Bytes) :-
    (   Codigo >= 0, Codigo =< 0x7f -> Ancho = 1
    ;   Codigo >= 0, Codigo =< 0x7ff -> Ancho = 2
    ;   Codigo >= 0, Codigo =< 0xffff -> Ancho = 3
    ;   Codigo >= 0, Codigo =< 0x10ffff -> Ancho = 4
    ;   throw(error(representation_error(punto_codigo_unicode), _))
    ),
    Siguiente is Acumulado + Ancho,
    longitud_utf8_bytes_(Resto, Siguiente, Bytes).

% escribir_respuesta(+RutaSalida, +Registros)
% C reserva previamente un archivo vacio. Se abre en escritura (nunca append),
% se escribe UTF-8 sin registros de diagnostico y se cierra antes de retornar.
escribir_respuesta(RutaSalida, Registros) :-
    setup_call_cleanup(
        open(RutaSalida, write, Flujo, [encoding(utf8), type(text)]),
        (   escribir_registros(Registros, Flujo),
            format(Flujo, 'FIN~n', []),
            flush_output(Flujo)
        ),
        close(Flujo)
    ).

escribir_registros([], _).
escribir_registros([ok|Resto], Flujo) :-
    format(Flujo, 'OK~n', []),
    escribir_registros(Resto, Flujo).
escribir_registros([error(Mensaje)|Resto], Flujo) :-
    format(Flujo, 'ERROR\t~a~n', [Mensaje]),
    escribir_registros(Resto, Flujo).
escribir_registros([resultado(Diagnostico, Explicacion, Recomendacion)|Resto], Flujo) :-
    format(Flujo, 'RESULTADO\t~a\t~a\t~a~n',
           [Diagnostico, Explicacion, Recomendacion]),
    escribir_registros(Resto, Flujo).
escribir_registros([vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)|Resto], Flujo) :-
    format(Flujo, 'VEHICULO\t~a\t~a\t~d\t~d\t~a~n',
           [Marca, Modelo, Anio, Kilometraje, Combustible]),
    escribir_registros(Resto, Flujo).
escribir_registros([sintoma(Sintoma)|Resto], Flujo) :-
    format(Flujo, 'SINTOMA\t~a~n', [Sintoma]),
    escribir_registros(Resto, Flujo).
