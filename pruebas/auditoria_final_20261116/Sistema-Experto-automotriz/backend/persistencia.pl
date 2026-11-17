% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz
% Archivo : backend/persistencia.pl
% Modulo  : Persistencia segura de sesiones
% ============================================================================
% API publica:
%   guardar_sesion(+Recurso, +Sesion)
%   recuperar_sesion(+Recurso, -Sesion)
%
% El recurso es un identificador (no una ruta): se guarda en el directorio
% backend/sesiones con extension .ses. Cada archivo contiene un unico termino
% Prolog serializado como datos. Nunca se consulta ni se ejecuta el contenido.
% ============================================================================

:- ensure_loaded('reglas.pl').

:- dynamic persistencia_directorio_backend/1.
:- prolog_load_context(directory, DirectorioBackend),
   retractall(persistencia_directorio_backend(_)),
   assertz(persistencia_directorio_backend(DirectorioBackend)).

% guardar_sesion(+Recurso, +Sesion)
% Valida y serializa la sesion en UTF-8. El recurso solo admite letras ASCII,
% numeros, guion y guion bajo, por lo que nunca puede escapar del almacen.
% Errores de validacion o de E/S se notifican como excepciones Prolog.
guardar_sesion(Recurso, Sesion) :-
    validar_recurso(Recurso, Ruta),
    validar_sesion(Sesion),
    catch(
        (   preparar_directorio_almacenamiento,
            validar_destino(Ruta),
            setup_call_cleanup(
                open(Ruta, write, Flujo, [encoding(utf8), type(text)]),
                (   write_term(Flujo, Sesion,
                               [quoted(true), ignore_ops(true),
                                fullstop(true), nl(true)]),
                    flush_output(Flujo)
                ),
                close(Flujo)
            )
        ),
        Error,
        throw(error(persistencia_escritura(Recurso, Error), _))
    ).

% recuperar_sesion(+Recurso, -Sesion)
% Lee exactamente un termino, comprueba que no haya datos adicionales y
% valida nuevamente su estructura. El termino leido nunca se llama como meta.
recuperar_sesion(Recurso, Sesion) :-
    validar_recurso(Recurso, Ruta),
    catch(
        (   preparar_directorio_almacenamiento,
            validar_destino(Ruta),
            (   exists_file(Ruta)
            ->  true
            ;   throw(error(existence_error(file, Ruta), _))
            ),
            setup_call_cleanup(
                open(Ruta, read, Flujo, [encoding(utf8), type(text),
                                         bom(true)]),
                leer_sesion(Flujo, SesionLeida),
                close(Flujo)
            ),
            validar_sesion(SesionLeida),
            Sesion = SesionLeida
        ),
        Error,
        throw(error(persistencia_lectura(Recurso, Error), _))
    ).

% validar_recurso(+Recurso, -RutaCompleta)
% Rechaza rutas, extensiones, nombres vacios y caracteres fuera del alfabeto
% permitido. La extension se agrega internamente.
validar_recurso(Recurso, RutaCompleta) :-
    (   atom(Recurso),
        atom_length(Recurso, Longitud),
        Longitud >= 1,
        Longitud =< 80,
        atom_codes(Recurso, Codigos),
        codigos_recurso_validos(Codigos)
    ->  true
    ;   throw(error(domain_error(identificador_de_sesion, Recurso), _))
    ),
    persistencia_directorio_backend(DirectorioBackend),
    directory_file_path(DirectorioBackend, sesiones, Directorio),
    atom_concat(Recurso, '.ses', NombreArchivo),
    directory_file_path(Directorio, NombreArchivo, RutaCompleta).

codigos_recurso_validos([]).
codigos_recurso_validos([Codigo|Resto]) :-
    (   (Codigo >= 0'a, Codigo =< 0'z)
    ;   (Codigo >= 0'A, Codigo =< 0'Z)
    ;   (Codigo >= 0'0, Codigo =< 0'9)
    ;   Codigo =:= 0'_
    ;   Codigo =:= 0'-
    ),
    codigos_recurso_validos(Resto).

% preparar_directorio_almacenamiento/0
% Crea el almacen si hace falta y confirma que sea un directorio directo bajo
% backend (no una redireccion/symlink hacia otro directorio).
preparar_directorio_almacenamiento :-
    persistencia_directorio_backend(DirectorioBackend),
    directory_file_path(DirectorioBackend, sesiones, Directorio),
    (   exists_directory(Directorio)
    ->  true
    ;   make_directory(Directorio)
    ),
    absolute_file_name(DirectorioBackend, BackendReal,
                       [file_type(directory), access(read)]),
    absolute_file_name(Directorio, DirectorioReal,
                       [file_type(directory), access(read)]),
    directory_file_path(BackendReal, sesiones, DirectorioEsperado),
    (   DirectorioReal == DirectorioEsperado
    ->  true
    ;   throw(error(permission_error(access, almacen_sesiones, Directorio), _))
    ).

% validar_destino(+Ruta)
% Si el archivo ya existe, exige que sea un archivo regular ubicado en el
% almacen y no un enlace a otro archivo.
validar_destino(Ruta) :-
    (   exists_file(Ruta)
    ->  absolute_file_name(Ruta, RutaReal, [file_type(regular), access(read)]),
        file_directory_name(RutaReal, DirectorioReal),
        persistencia_directorio_backend(DirectorioBackend),
        directory_file_path(DirectorioBackend, sesiones, Directorio),
        absolute_file_name(Directorio, DirectorioCanonico,
                           [file_type(directory), access(read)]),
        (   DirectorioReal == DirectorioCanonico
        ->  true
        ;   throw(error(permission_error(access, archivo_sesion, Ruta), _))
        )
    ;   true
    ).

% leer_sesion(+Flujo, -Sesion)
% Un archivo vacio, malformado o con mas de un termino se rechaza.
leer_sesion(Flujo, Sesion) :-
    read_term(Flujo, Termino, [syntax_errors(error)]),
    (   Termino == end_of_file
    ->  throw(error(existence_error(termino_sesion, Flujo), _))
    ;   true
    ),
    read_term(Flujo, Final, [syntax_errors(error)]),
    (   Final == end_of_file
    ->  Sesion = Termino
    ;   throw(error(domain_error(un_solo_termino, archivo_sesion), _))
    ).

% validar_sesion(+Sesion)
% Comprueba estructura, tipos, limites del contrato C y pertenencia de cada
% sintoma al catalogo cargado desde reglas.pl/hechos.pl.
validar_sesion(Sesion) :-
    (   ground(Sesion),
        Sesion = sesion(Vehiculo, Sintomas, Resultados),
        vehiculo_valido(Vehiculo),
        lista_sintomas_valida(Sintomas),
        lista_resultados_valida(Resultados)
    ->  true
    ;   throw(error(domain_error(sesion_valida, Sesion), _))
    ).

vehiculo_valido(sin_vehiculo).
vehiculo_valido(vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)) :-
    atom(Marca), texto_atomico_valido(Marca, 63),
    atom(Modelo), texto_atomico_valido(Modelo, 63),
    integer(Anio), Anio >= 1886, Anio =< 9999,
    integer(Kilometraje), Kilometraje >= 0, Kilometraje =< 2147483647,
    atom(Combustible), texto_atomico_valido(Combustible, 31).

lista_sintomas_valida(Sintomas) :-
    is_list(Sintomas),
    length(Sintomas, Cantidad),
    Cantidad =< 20,
    sintomas_sin_duplicados(Sintomas),
    forall(member(Sintoma, Sintomas),
           (atom(Sintoma), atom_length(Sintoma, Longitud),
            Longitud =< 63, sintoma_valido(Sintoma))).

sintomas_sin_duplicados([]).
sintomas_sin_duplicados([Sintoma|Resto]) :-
    \+ memberchk(Sintoma, Resto),
    sintomas_sin_duplicados(Resto).

lista_resultados_valida(Resultados) :-
    is_list(Resultados),
    length(Resultados, Cantidad),
    Cantidad =< 20,
    forall(member(Resultado, Resultados), resultado_valido(Resultado)).

resultado_valido(resultado(Diagnostico, Explicacion, Recomendacion)) :-
    atom(Diagnostico), texto_atomico_valido(Diagnostico, 159),
    atom(Explicacion), texto_atomico_valido(Explicacion, 511),
    atom(Recomendacion), texto_atomico_valido(Recomendacion, 511).

% texto_atomico_valido(+Atomo, +MaximoBytes)
% Exige texto no vacio, sin caracteres de control y dentro del buffer C
% (capacidad menos el byte NUL). Se mide UTF-8, como en el protocolo IPC.
texto_atomico_valido(Atomo, MaximoBytes) :-
    atom(Atomo),
    atom_codes(Atomo, Codigos),
    Codigos = [_|_],
    bytes_utf8(Codigos, Bytes),
    Bytes =< MaximoBytes,
    forall(member(Codigo, Codigos),
           (Codigo >= 32, Codigo =\= 127)).

bytes_utf8([], 0).
bytes_utf8([Codigo|Resto], Bytes) :-
    bytes_utf8(Resto, BytesResto),
    (   Codigo =< 0x7f -> Ancho = 1
    ;   Codigo =< 0x7ff -> Ancho = 2
    ;   Codigo =< 0xffff -> Ancho = 3
    ;   Ancho = 4
    ),
    Bytes is BytesResto + Ancho.
