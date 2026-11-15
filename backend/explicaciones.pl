% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz (Parte 2)
% Archivo : backend/explicaciones.pl
% Modulo  : Explicabilidad, Justificacion y Punto de Entrada del Motor (RF-11)
% Autor   : Daniel
% ============================================================================
% Construye dinamicamente explicaciones justificadas a partir de los sintomas
% reales, caracteristicas del vehiculo y descartes aplicados, y expone el
% predicado principal diagnosticar/3 esperado por C y consultas.pl.
% ============================================================================

:- consult('inferencia.pl').

% ----------------------------------------------------------------------------
% 1. CONSTRUCTORES AUXILIARES DE CONTEXTO DINAMICO
% ----------------------------------------------------------------------------

% sintomas_sustento_falla(+Sintomas, +IdFalla, -TextoSintomas)
% Extrae los sintomas reales presentes que sustentan la hipotesis IdFalla.
sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas) :-
    findall(
        S,
        (   tiene_sintoma(S, Sintomas),
            sintoma_asociado_falla(IdFalla, S, _)
        ),
        Coincidentes
    ),
    list_to_set(Coincidentes, Unicos),
    (   Unicos = [_|_]
    ->  atomic_list_concat(Unicos, ', ', TextoSintomas)
    ;   (   is_list(Sintomas), Sintomas = [_|_]
        ->  atomic_list_concat(Sintomas, ', ', TextoSintomas)
        ;   findall(SA, sintoma_activo(SA), Activos),
            (   Activos = [_|_]
            ->  atomic_list_concat(Activos, ', ', TextoSintomas)
            ;   TextoSintomas = 'sintomas registrados'
            )
        )
    ).

% contexto_vehiculo_texto(+Vehiculo, -TextoVehiculo)
% Genera un resumen dinamico de las condiciones reales del vehiculo evaluado.
contexto_vehiculo_texto(vehiculo(Marca, Modelo, Anio, Km, Comb), TextoVehiculo) :-
    !,
    sistema_alimentacion_vehiculo(vehiculo(Marca, Modelo, Anio, Km, Comb), SistAlim),
    nivel_desgaste_kilometraje(vehiculo(Marca, Modelo, Anio, Km, Comb), NivelKm),
    atomic_list_concat(
        [Marca, ' ', Modelo, ' (', Anio, ', ', Comb, ', ', SistAlim, ', ', Km, ' km - ', NivelKm, ')'],
        '',
        TextoVehiculo
    ).
contexto_vehiculo_texto(_, 'vehiculo sin datos especificos registrados').

% resumen_descartes_texto(+Vehiculo, +Sintomas, -TextoDescartes)
% Resume dinamicamente los descartes de hipotesis incompatibles aplicados.
resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes) :-
    descartes_relevantes(Vehiculo, Sintomas, Motivos),
    (   Motivos = [_|_]
    ->  atomic_list_concat(Motivos, '; ', Detalle),
        atom_concat('Descartes: ', Detalle, TextoDescartes)
    ;   TextoDescartes = 'Sin exclusiones incompatibles adicionales'
    ).

% ----------------------------------------------------------------------------
% 2. REGLAS DE EXPLICACION DE CONCLUSIONES (RF-11)
% ----------------------------------------------------------------------------

% construir_explicacion_falla(+Vehiculo, +Sintomas, +IdFalla, +IdSubsistema, +EstadoInferido, -ExplicacionTexto)
% Construye la justificacion logica unificando datos reales de la inferencia.

% Regla de explicacion 1: Circuito de arranque con bateria confirmada sana.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, electrico, interrupcion_circuito_arranque_con_bateria_sana, ExplicacionTexto) :-
    !,
    falla_catalogo(IdFalla, electrico, IdComp, _, Severidad),
    componente(IdComp, electrico, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Por sintomas [', TextoSintomas,
            '] con iluminacion y voltaje adecuados, se deduce interrupcion en circuito de arranque (componente: ',
            NombreComp, ', severidad: ', Severidad, ') en ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 2: Bloqueo electromecanico en acoplamiento de arranque.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, electrico, bloqueo_electromecanico_arranque, ExplicacionTexto) :-
    !,
    falla_catalogo(IdFalla, electrico, IdComp, _, Severidad),
    componente(IdComp, electrico, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Sintomas [', TextoSintomas,
            '] indican bloqueo electromecanico de arranque con chasquido y luces activas; implica ',
            NombreComp, ' (severidad: ', Severidad, ') en ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 3: Deficit de carga primaria o falla de generacion en alternador.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, electrico, EstadoInferido, ExplicacionTexto) :-
    member(EstadoInferido, [deficit_energia_primaria_bateria, falla_generacion_carga_alternador]), !,
    falla_catalogo(IdFalla, electrico, IdComp, _, Severidad),
    componente(IdComp, electrico, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Evidencia electrica [', TextoSintomas,
            '] sustenta estado ', EstadoInferido, ' sobre ',
            NombreComp, ' (severidad: ', Severidad, ') en ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 4: Fallas de alimentacion de combustible y mezcla aire-combustible.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, IdSubsistema, EstadoInferido, ExplicacionTexto) :-
    member(EstadoInferido, [deficiencia_suministro_combustible, mezcla_rica_combustion_incompleta]), !,
    falla_catalogo(IdFalla, IdSubsistema, IdComp, _, Severidad),
    componente(IdComp, IdSubsistema, NombreComp, _),
    sistema_alimentacion_vehiculo(Vehiculo, SistAlim),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Sintomas [', TextoSintomas,
            '] y sistema de alimentacion ', SistAlim,
            ' justifican ', EstadoInferido, ' afectando ',
            NombreComp, ' (severidad: ', Severidad, ') en ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 5: Fallas termicas, compresion interna o ignicion por chispa.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, IdSubsistema, EstadoInferido, ExplicacionTexto) :-
    member(EstadoInferido, [
        compromiso_termico_estructural_motor,
        degradacion_compresion_anillos,
        falla_ignicion_cilindros
    ]), !,
    falla_catalogo(IdFalla, IdSubsistema, IdComp, _, Severidad),
    componente(IdComp, IdSubsistema, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Condicion mecanica-termica [', TextoSintomas,
            '] deduce ', EstadoInferido, ' en ',
            NombreComp, ' (subsistema ', IdSubsistema, ', severidad: ', Severidad, ') para ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 6: Gestion electronica, sensores OBD y unidad ECU.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, electronico, desincronizacion_gestion_electronica_ecu, ExplicacionTexto) :-
    !,
    falla_catalogo(IdFalla, electronico, IdComp, _, Severidad),
    componente(IdComp, electronico, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Alertas electronicas [', TextoSintomas,
            '] senalan desincronizacion de control en ',
            NombreComp, ' (severidad: ', Severidad, ') para ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% Regla de explicacion 7: Sistema de frenos y evaluacion directa de sintomas.
construir_explicacion_falla(Vehiculo, Sintomas, IdFalla, IdSubsistema, EstadoInferido, ExplicacionTexto) :-
    falla_catalogo(IdFalla, IdSubsistema, IdComp, _, Severidad),
    componente(IdComp, IdSubsistema, NombreComp, _),
    sintomas_sustento_falla(Sintomas, IdFalla, TextoSintomas),
    contexto_vehiculo_texto(Vehiculo, TextoVehiculo),
    resumen_descartes_texto(Vehiculo, Sintomas, TextoDescartes),
    atomic_list_concat(
        [
            'Sintomas compatibles [', TextoSintomas,
            '] activan ', EstadoInferido, ' sobre ',
            NombreComp, ' (subsistema ', IdSubsistema, ', severidad: ', Severidad, ') en ',
            TextoVehiculo, '. ', TextoDescartes, '.'
        ],
        '',
        TextoBruto
    ),
    ajustar_longitud_atomo(TextoBruto, 480, ExplicacionTexto).

% ----------------------------------------------------------------------------
% 3. INTERFAZ PRINCIPAL DE DIAGNOSTICO PARA C Y CONSULTAS.PL
% ----------------------------------------------------------------------------

% diagnosticar_hipotesis(+Vehiculo, +Sintomas, -IdFalla, -Resultado)
% Genera un termino resultado(Diagnostico, Explicacion, Recomendacion) por cada
% hipotesis valida no descartada, respetando limites de buffer en C.
diagnosticar_hipotesis(Vehiculo, Sintomas, IdFalla, resultado(DiagnosticoSeguro, ExplicacionSeguro, RecomendacionSeguro)) :-
    vehiculo_efectivo(Vehiculo, VehiculoEval),
    hipotesis_diagnostica(VehiculoEval, Sintomas, IdFalla, IdSubsistema, EstadoInferido),
    falla_catalogo(IdFalla, IdSubsistema, _, DiagnosticoBase, _),
    ajustar_longitud_atomo(DiagnosticoBase, 155, DiagnosticoSeguro),
    construir_explicacion_falla(VehiculoEval, Sintomas, IdFalla, IdSubsistema, EstadoInferido, ExplicacionSeguro),
    derivar_recomendacion(VehiculoEval, Sintomas, IdFalla, _, _, RecomendacionSeguro).

% limitar_resultados(+Lista, -Limitada)
% Acota la lista al maximo MAX_RESULTADOS (20) definido en frontend/tipos.h.
limitar_resultados(Lista, Limitada) :-
    length(Lista, Cantidad),
    (   Cantidad =< 20
    ->  Limitada = Lista
    ;   length(Limitada, 20),
        append(Limitada, _, Lista)
    ).

% diagnosticar(+Vehiculo, +Sintomas, -Resultados)
% Predicado principal del contrato C/Prolog. Devuelve lista de terminos
% resultado(Diagnostico, Explicacion, Recomendacion), o [] sin coincidencias.
diagnosticar(Vehiculo, Sintomas, Resultados) :-
    findall(
        Resultado,
        diagnosticar_hipotesis(Vehiculo, Sintomas, _, Resultado),
        ResultadosBrutos
    ),
    list_to_set(ResultadosBrutos, ResultadosUnicos),
    limitar_resultados(ResultadosUnicos, Resultados).

% diagnosticar_sesion_activa(-Resultados)
% Ejecuta el diagnostico utilizando los hechos dinamicos vehiculo_actual/5
% y sintoma_activo/1 registrados en memoria.
diagnosticar_sesion_activa(Resultados) :-
    findall(Sintoma, sintoma_activo(Sintoma), SintomasActivos),
    vehiculo_efectivo(sin_vehiculo, Vehiculo),
    diagnosticar(Vehiculo, SintomasActivos, Resultados).

% sintomas_desconocidos(+Sintomas, -Desconocidos)
% Lista los identificadores de sintomas que no pertenecen al catalogo oficial.
sintomas_desconocidos(Sintomas, Desconocidos) :-
    is_list(Sintomas),
    findall(
        S,
        (   member(S, Sintomas),
            \+ sintoma_valido(S)
        ),
        Brutos
    ),
    list_to_set(Brutos, Desconocidos).

% catalogo_sintomas(-ListaSintomas)
% Devuelve la lista completa de identificadores oficiales del catalogo de sintomas.
catalogo_sintomas(ListaSintomas) :-
    findall(Id, sintoma_catalogo(Id, _, _, _), ListaSintomas).
