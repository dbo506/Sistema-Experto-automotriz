% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz
% Archivo : backend/consultas.pl
% Modulo  : Consultas logicas, operaciones con listas y backtracking
% ============================================================================
% Consultas auxiliares sobre los catalogos y relaciones existentes. Este
% modulo no implementa ni duplica el motor de diagnostico.
%
% Dependencias: explicaciones.pl carga inferencia.pl, reglas.pl y hechos.pl.
% ensure_loaded/1 evita cargar dos veces archivos ya presentes en la sesion.
% Las rutas son relativas a este archivo, por lo que se puede cargar desde la
% raiz con: ?- [backend/consultas].
% ============================================================================

:- ensure_loaded('explicaciones.pl').

% ----------------------------------------------------------------------------
% Consultas de sintomas
% ----------------------------------------------------------------------------

% sintomas_por_subsistema(+Subsistema, -Sintomas)
% Devuelve en orden de catalogo los identificadores de sintomas del subsistema.
% Ejemplo: ?- sintomas_por_subsistema(electrico, Sintomas).
sintomas_por_subsistema(Subsistema, Sintomas) :-
    findall(Id, sintoma_catalogo(Id, Subsistema, _, _), Sintomas).

% cantidad_sintomas_subsistema(+Subsistema, -Cantidad)
% Cuenta recursivamente los sintomas catalogados en un subsistema.
% Ejemplo: ?- cantidad_sintomas_subsistema(electrico, Cantidad).
cantidad_sintomas_subsistema(Subsistema, Cantidad) :-
    sintomas_por_subsistema(Subsistema, Sintomas),
    contar_elementos(Sintomas, Cantidad).

% fallas_por_sintoma(+Sintoma, -Falla)
% Relaciona un sintoma oficial con cada falla que lo tiene como evidencia.
% Devuelve una solucion por falla; use ; para pedir la siguiente.
% Ejemplo: ?- fallas_por_sintoma(no_arranca, Falla).
fallas_por_sintoma(Sintoma, Falla) :-
    sintoma_valido(Sintoma),
    sintoma_asociado_falla(Falla, Sintoma, _),
    falla_catalogo(Falla, _, _, _, _).

% sintomas_por_falla(+Falla, -Sintoma)
% Devuelve, mediante backtracking, cada sintoma oficial asociado a la falla.
% Ejemplo: ?- sintomas_por_falla(bateria_descargada, Sintoma).
sintomas_por_falla(Falla, Sintoma) :-
    falla_catalogo(Falla, _, _, _, _),
    sintoma_asociado_falla(Falla, Sintoma, _),
    sintoma_valido(Sintoma).

% sintomas_validos(+SintomasEntrada, -Validos)
% Filtra una lista y conserva solo identificadores del catalogo, en su orden.
% Requiere una lista propia; [] produce [] y una entrada no lista falla.
% Ejemplo: ?- sintomas_validos([no_arranca, inventado], Validos).
sintomas_validos(SintomasEntrada, Validos) :-
    is_list(SintomasEntrada),
    filtrar_sintomas_validos(SintomasEntrada, Validos).

% sintomas_desconocidos_lista(+SintomasEntrada, -Desconocidos)
% Extrae los identificadores no catalogados y elimina repeticiones conservando
% la primera aparicion. [] produce [].
% Ejemplo: ?- sintomas_desconocidos_lista([no_arranca, raro, raro], X).
sintomas_desconocidos_lista(SintomasEntrada, Desconocidos) :-
    is_list(SintomasEntrada),
    filtrar_sintomas_desconocidos(SintomasEntrada, Brutos),
    eliminar_duplicados(Brutos, Desconocidos).

% ----------------------------------------------------------------------------
% Consultas de fallas
% ----------------------------------------------------------------------------

% fallas_por_severidad(+Severidad, -Falla)
% Devuelve cada falla catalogada con esa severidad, una por solucion.
% Ejemplo: ?- fallas_por_severidad(alta, Falla).
fallas_por_severidad(Severidad, Falla) :-
    falla_catalogo(Falla, _, _, _, Severidad).

% pruebas_por_falla(+Falla, -Prueba)
% Devuelve las pruebas de verificacion existentes para la falla.
% Ejemplo: ?- pruebas_por_falla(bateria_descargada, Prueba).
pruebas_por_falla(Falla, Prueba) :-
    falla_catalogo(Falla, _, _, _, _),
    prueba_verificacion(Falla, Prueba).

% acciones_por_falla(+Falla, -Accion)
% Devuelve las acciones correctivas catalogadas para la falla.
% Ejemplo: ?- acciones_por_falla(bateria_descargada, Accion).
acciones_por_falla(Falla, Accion) :-
    falla_catalogo(Falla, _, _, _, _),
    accion_correctiva(Falla, Accion).

% fallas_por_sintomas(+Sintomas, -Fallas)
% Recopila fallas asociadas al menos a uno de los sintomas recibidos, sin
% duplicados y en orden de primera coincidencia. Una lista vacia da [].
% Ejemplo: ?- fallas_por_sintomas([no_arranca, luces_tenues], Fallas).
fallas_por_sintomas(Sintomas, Fallas) :-
    is_list(Sintomas),
    findall(
        Falla,
        (   member(Sintoma, Sintomas),
            fallas_por_sintoma(Sintoma, Falla)
        ),
        Brutas
    ),
    eliminar_duplicados(Brutas, Fallas).

% ----------------------------------------------------------------------------
% Consultas de componentes
% ----------------------------------------------------------------------------

% componentes_por_subsistema(+Subsistema, -IdComponente)
% Devuelve cada identificador de componente del subsistema por backtracking.
% Ejemplo: ?- componentes_por_subsistema(electrico, Componente).
componentes_por_subsistema(Subsistema, IdComponente) :-
    componente(IdComponente, Subsistema, _, _).

% componentes_por_sintoma(+Sintoma, -IdComponente)
% Encuentra componentes de fallas asociadas al sintoma; permite alternativas.
% Ejemplo: ?- componentes_por_sintoma(no_arranca, Componente).
componentes_por_sintoma(Sintoma, IdComponente) :-
    fallas_por_sintoma(Sintoma, Falla),
    falla_catalogo(Falla, _, IdComponente, _, _).

% informacion_componente(+IdComponente, -Subsistema, -Nombre, -Funcion)
% Consulta los datos descriptivos completos de un componente existente.
% Ejemplo: ?- informacion_componente(bateria, S, Nombre, Funcion).
informacion_componente(IdComponente, Subsistema, Nombre, Funcion) :-
    componente(IdComponente, Subsistema, Nombre, Funcion).

% ----------------------------------------------------------------------------
% Consultas de vehiculos
% ----------------------------------------------------------------------------

% perfiles_por_combustible(+Combustible, -Marca, -Modelo, -AnioMin, -AnioMax)
% Devuelve los perfiles de vehiculo catalogados para el combustible indicado.
% Ejemplo: ?- perfiles_por_combustible(diesel, Marca, Modelo, Min, Max).
perfiles_por_combustible(Combustible, Marca, Modelo, AnioMin, AnioMax) :-
    perfil_modelo_vehiculo(Marca, Modelo, AnioMin, AnioMax, Combustible, _, _).

% ----------------------------------------------------------------------------
% Operaciones propias con listas y reglas recursivas
% ----------------------------------------------------------------------------

% eliminar_duplicados(+Lista, -SinDuplicados)
% Operacion propia que conserva la primera aparicion de cada elemento.
% Caso base: lista vacia. Paso recursivo: procesa la cola y omite la cabeza si
% ya aparece en esa cola (el resultado final conserva el orden original).
% Ejemplo: ?- eliminar_duplicados([a,b,a,c,b], R). % R = [a,b,c]

eliminar_duplicados(Lista, Resultado) :-
    eliminar_duplicados_aux(Lista, [], Resultado).

eliminar_duplicados_aux([], _, []).
eliminar_duplicados_aux([Cabeza|Cola], Visitados, Resultado) :-
    (   memberchk(Cabeza, Visitados)
    ->  eliminar_duplicados_aux(Cola, Visitados, Resultado)
    ;   Resultado = [Cabeza|Resto],
        eliminar_duplicados_aux(Cola, [Cabeza|Visitados], Resto)
    ).

% filtrar_sintomas_validos(+Entrada, -Validos)
% Regla recursiva propia: conserva los elementos reconocidos por sintoma_valido/1.
% Caso base: []. Cada paso consume exactamente un elemento.
% Ejemplo: ?- filtrar_sintomas_validos([no_arranca, falso], R).
filtrar_sintomas_validos([], []).
filtrar_sintomas_validos([Sintoma|Resto], [Sintoma|Validos]) :-
    sintoma_valido(Sintoma), !,
    filtrar_sintomas_validos(Resto, Validos).
filtrar_sintomas_validos([_|Resto], Validos) :-
    filtrar_sintomas_validos(Resto, Validos).

% contar_elementos(+Lista, -Cantidad)
% Regla recursiva propia para contar elementos; no usa length/2.
% Caso base: []. Paso recursivo: cuenta la cola y suma uno.
% Ejemplo: ?- contar_elementos([a,b,c], N). % N = 3
contar_elementos([], 0).
contar_elementos([_|Resto], Cantidad) :-
    contar_elementos(Resto, CantidadResto),
    Cantidad is CantidadResto + 1.

% filtrar_sintomas_desconocidos(+Entrada, -Desconocidos)
% Auxiliar recursivo que obtiene elementos no registrados en el catalogo.
% Ejemplo: ?- filtrar_sintomas_desconocidos([no_arranca, x], R). % R = [x]
filtrar_sintomas_desconocidos([], []).
filtrar_sintomas_desconocidos([Sintoma|Resto], [Sintoma|Desconocidos]) :-
    \+ sintoma_valido(Sintoma), !,
    filtrar_sintomas_desconocidos(Resto, Desconocidos).
filtrar_sintomas_desconocidos([_|Resto], Desconocidos) :-
    filtrar_sintomas_desconocidos(Resto, Desconocidos).

% ----------------------------------------------------------------------------
% Escenarios de backtracking para demostrar soluciones alternativas
% ----------------------------------------------------------------------------

% Estas consultas son relacionales y no recopilan las respuestas en una lista.
% Tras cada respuesta, presione ; en el toplevel para solicitar otra solucion.
%
% 1. Varias fallas vinculadas a un sintoma:
%    ?- fallas_por_sintoma(no_arranca, Falla).
%
% 2. Componentes compatibles con el sintoma:
%    ?- componentes_por_sintoma(no_arranca, Componente).
%
% 3. Pruebas alternativas de una falla (si hay mas de una en los hechos):
%    ?- pruebas_por_falla(Falla, Prueba).
%    Falla puede dejarse libre para recorrer todas las fallas y sus pruebas.
%
% Consultas adicionales para estudio:
%    ?- sintomas_por_falla(bateria_descargada, Sintoma).
%    ?- perfiles_por_combustible(gasolina, Marca, Modelo, Min, Max).
%    ?- fallas_por_sintomas([no_arranca, luces_tenues], Fallas).
% ============================================================================
