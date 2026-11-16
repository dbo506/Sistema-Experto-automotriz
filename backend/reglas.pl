% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz (Parte 2)
% Archivo : backend/reglas.pl
% Modulo  : Reglas Logicas de Vehiculo, Sintomas, Componentes y Diagnostico
% Autor   : Daniel
% ============================================================================
% Relaciona caracteristicas del vehiculo (combustible, anio, kilometraje)
% con subsistemas, componentes sospechosos y diagnosticos preliminares.
% ============================================================================

:- consult('hechos.pl').

% ----------------------------------------------------------------------------
% 1. GESTION DE SESION DINAMICA Y VALIDACION DE SINTOMAS
% ----------------------------------------------------------------------------

% limpiar_sesion_activa/0
% Elimina hechos dinamicos de vehiculo y sintomas activos de la sesion actual.
limpiar_sesion_activa :-
    retractall(vehiculo_actual(_, _, _, _, _)),
    retractall(sintoma_activo(_)).

% cargar_sesion_activa(+Vehiculo, +Sintomas)
% Registra en memoria dinamica el vehiculo y los sintomas validos de la sesion.
cargar_sesion_activa(Vehiculo, Sintomas) :-
    limpiar_sesion_activa,
    (   Vehiculo = vehiculo(Marca, Modelo, Anio, Kilometraje, Combustible)
    ->  assertz(vehiculo_actual(Marca, Modelo, Anio, Kilometraje, Combustible))
    ;   true
    ),
    (   is_list(Sintomas)
    ->  forall(
            (   member(Sintoma, Sintomas),
                sintoma_valido(Sintoma)
            ),
            assertz(sintoma_activo(Sintoma))
        )
    ;   true
    ).

% sintoma_valido(+IdSintoma)
% Verdadero si el atomo pertenece al catalogo oficial de sintomas.
sintoma_valido(IdSintoma) :-
    atom(IdSintoma),
    sintoma_catalogo(IdSintoma, _, _, _).

% tiene_sintoma(+IdSintoma, +Sintomas)
% Verifica si un sintoma esta presente en la lista dada o como hecho dinamico.
tiene_sintoma(IdSintoma, Sintomas) :-
    (   is_list(Sintomas)
    ->  member(IdSintoma, Sintomas)
    ;   sintoma_activo(IdSintoma)
    ).

% vehiculo_efectivo(+VehiculoEntrada, -VehiculoResuelto)
% Resuelve el termino vehiculo desde argumento explicito o desde sesion dinamica.
vehiculo_efectivo(vehiculo(M, Mo, A, K, C), vehiculo(M, Mo, A, K, C)) :- !.
vehiculo_efectivo(sin_vehiculo, vehiculo(M, Mo, A, K, C)) :-
    vehiculo_actual(M, Mo, A, K, C), !.
vehiculo_efectivo(_, sin_vehiculo).

% ----------------------------------------------------------------------------
% 2. NORMALIZACION Y CARACTERIZACION DEL VEHICULO
% ----------------------------------------------------------------------------

alias_combustible(gasolina, gasolina).
alias_combustible(regular, gasolina).
alias_combustible(super, gasolina).
alias_combustible(nafta, gasolina).
alias_combustible(bencina, gasolina).
alias_combustible(diesel, diesel).
alias_combustible('di\xe9\sel', diesel).
alias_combustible(gasoil, diesel).
alias_combustible(acpm, diesel).
alias_combustible(hibrido, hibrido).
alias_combustible('h\xed\brido', hibrido).
alias_combustible(hybrid, hibrido).
alias_combustible(electrico, electrico).
alias_combustible('el\xe9\ctrico', electrico).
alias_combustible(ev, electrico).
alias_combustible(glp, glp).
alias_combustible(gas, glp).
alias_combustible(gnv, glp).

% normalizar_combustible(+TextoCombustible, -CombustibleNorm)
% Normaliza variantes de texto ingresadas por el usuario en C hacia atomos canonicos.
normalizar_combustible(Texto, CombustibleNorm) :-
    atom(Texto),
    downcase_atom(Texto, Minuscula),
    alias_combustible(Minuscula, CombustibleNorm), !.
normalizar_combustible(Texto, gasolina) :-
    atom(Texto),
    downcase_atom(Texto, Min),
    sub_atom(Min, _, _, _, gasol), !.
normalizar_combustible(Texto, diesel) :-
    atom(Texto),
    downcase_atom(Texto, Min),
    sub_atom(Min, _, _, _, dies), !.
normalizar_combustible(Texto, hibrido) :-
    atom(Texto),
    downcase_atom(Texto, Min),
    sub_atom(Min, _, _, _, hibr), !.
normalizar_combustible(Texto, electrico) :-
    atom(Texto),
    downcase_atom(Texto, Min),
    sub_atom(Min, _, _, _, electr), !.
normalizar_combustible(_, desconocido).

% sistema_alimentacion_vehiculo(+Vehiculo, -SistemaAlimentacion)
% Si existe un perfil catalogado para modelo y anio, valida compatibilidad con
% el combustible declarado; si el modelo no esta catalogado, infiere la
% arquitectura a partir del combustible normalizado y el anio de fabricacion.
sistema_alimentacion_vehiculo(Vehiculo, Alimentacion) :-
    Vehiculo = vehiculo(Marca, Modelo, Anio, _, CombTexto),
    atom(Marca),
    atom(Modelo),
    integer(Anio),
    downcase_atom(Marca, MarcaNorm),
    downcase_atom(Modelo, ModeloNorm),
    findall(
        CombPerfil-AlimentacionPerfil,
        (   perfil_modelo_vehiculo(
                MarcaNorm, ModeloNorm, MinAnio, MaxAnio, CombPerfil, _,
                AlimentacionPerfil
            ),
            Anio >= MinAnio,
            Anio =< MaxAnio
        ),
        PerfilesAplicables
    ),
    normalizar_combustible(CombTexto, CombNorm),
    (   PerfilesAplicables == []
    ->  alimentacion_por_anio_y_combustible(Anio, CombNorm, AlimentacionResuelta)
    ;   (   memberchk(CombNorm-AlimentacionPerfil, PerfilesAplicables)
        ->  AlimentacionResuelta = AlimentacionPerfil
        ;   throw(error(domain_error(perfil_vehiculo_incompatible, Vehiculo), _))
        )
    ),
    !,
    Alimentacion = AlimentacionResuelta.
sistema_alimentacion_vehiculo(_, desconocido).

% alimentacion_por_anio_y_combustible(+Anio, +CombNorm, -SistemaAlimentacion)
% Deduce la alimentacion por anio de corte (carburador vs inyeccion) y combustible.
alimentacion_por_anio_y_combustible(Anio, gasolina, carburador) :-
    umbral_operativo(anio_corte_inyeccion, Corte, _),
    Anio < Corte, !.
alimentacion_por_anio_y_combustible(Anio, gasolina, inyeccion_electronica) :-
    umbral_operativo(anio_corte_inyeccion, Corte, _),
    Anio >= Corte, !.
alimentacion_por_anio_y_combustible(_, CombNorm, Alimentacion) :-
    combustible_catalogo(CombNorm, Alimentacion, _, _), !.
alimentacion_por_anio_y_combustible(_, _, desconocido).

% tipo_encendido_vehiculo(+Vehiculo, -TipoEncendido)
% Deduce el encendido solo cuando el perfil confirma la arquitectura.
tipo_encendido_vehiculo(Vehiculo, TipoEncendido) :-
    sistema_alimentacion_vehiculo(Vehiculo, Alimentacion),
    Alimentacion \= desconocido,
    Vehiculo = vehiculo(_, _, _, _, CombTexto),
    normalizar_combustible(CombTexto, CombNorm),
    combustible_catalogo(CombNorm, _, TipoEncendido, _), !.
tipo_encendido_vehiculo(_, desconocido).

% transmision_vehiculo(+Vehiculo, -Transmision)
% Determina la transmision conocida a partir del perfil del modelo o desconocido.
transmision_vehiculo(vehiculo(Marca, Modelo, Anio, _, _), Transmision) :-
    atom(Marca),
    atom(Modelo),
    integer(Anio),
    downcase_atom(Marca, MarcaNorm),
    downcase_atom(Modelo, ModeloNorm),
    perfil_modelo_vehiculo(MarcaNorm, ModeloNorm, MinAnio, MaxAnio, _, Transmision, _),
    Anio >= MinAnio,
    Anio =< MaxAnio, !.
transmision_vehiculo(_, desconocido).

% nivel_desgaste_kilometraje(+Vehiculo, -NivelDesgaste)
% Clasifica el desgaste acumulado por kilometraje usando umbrales operativos.
nivel_desgaste_kilometraje(vehiculo(_, _, _, Km, _), Nivel) :-
    integer(Km),
    member(Nivel, [kilometraje_bajo, kilometraje_moderado, kilometraje_alto, kilometraje_critico]),
    umbral_operativo(Nivel, Min, Max),
    Km >= Min,
    Km =< Max, !.
nivel_desgaste_kilometraje(_, kilometraje_desconocido).

% antiguedad_vehiculo(+Vehiculo, -CategoriaAntiguedad)
% Clasifica la antiguedad tecnologica del vehiculo segun anio de fabricacion.
antiguedad_vehiculo(vehiculo(_, _, Anio, _, _), reciente) :-
    integer(Anio), Anio >= 2020, !.
antiguedad_vehiculo(vehiculo(_, _, Anio, _, _), intermedio) :-
    integer(Anio), Anio >= 2012, Anio < 2020, !.
antiguedad_vehiculo(vehiculo(_, _, Anio, _, _), antiguo) :-
    integer(Anio), Anio >= 1995, Anio < 2012, !.
antiguedad_vehiculo(vehiculo(_, _, Anio, _, _), clasico) :-
    integer(Anio), Anio < 1995, !.
antiguedad_vehiculo(_, antiguedad_desconocida).

% ----------------------------------------------------------------------------
% 3. RELACION SINTOMAS - COMPONENTES - SUBSISTEMAS
% ----------------------------------------------------------------------------

% pertenece_subsistema(+IdComponente, -IdSubsistema)
% Asocia un componente con el subsistema automotriz al que pertenece.
pertenece_subsistema(IdComponente, IdSubsistema) :-
    componente(IdComponente, IdSubsistema, _, _).

% componente_afectado_por_sintoma(+IdSintoma, -IdComponente, -IdSubsistema)
% Relaciona un sintoma observado con componentes candidatos y su subsistema.
componente_afectado_por_sintoma(IdSintoma, IdComponente, IdSubsistema) :-
    sintoma_asociado_falla(IdFalla, IdSintoma, _),
    falla_catalogo(IdFalla, IdSubsistema, IdComponente, _, _).

% subsistema_comprometido(+Sintomas, -IdSubsistema)
% Identifica subsistemas comprometidos a partir de los sintomas reportados.
subsistema_comprometido(Sintomas, IdSubsistema) :-
    subsistema(IdSubsistema, _, _),
    tiene_sintoma(IdSintoma, Sintomas),
    (   sintoma_catalogo(IdSintoma, IdSubsistema, _, _)
    ;   componente_afectado_por_sintoma(IdSintoma, _, IdSubsistema)
    ).

% componente_compatible_vehiculo(+Vehiculo, +IdComponente)
% Verifica que un componente exista en la arquitectura del vehiculo evaluado.
componente_compatible_vehiculo(Vehiculo, carburador) :-
    !,
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist = carburador.
componente_compatible_vehiculo(Vehiculo, inyectores_combustible) :-
    !,
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    memberchk(Sist, [inyeccion_electronica, inyeccion_diesel]).
componente_compatible_vehiculo(Vehiculo, sistema_encendido_bujias) :-
    !,
    tipo_encendido_vehiculo(Vehiculo, Enc),
    Enc = encendido_por_chispa.
componente_compatible_vehiculo(Vehiculo, IdComponente) :-
    componente(IdComponente, mecanico, _, _),
    \+ member(IdComponente, [circuito_hidraulico_frenos, discos_freno]),
    !,
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    memberchk(Sist, [carburador, inyeccion_electronica, inyeccion_diesel]).
componente_compatible_vehiculo(_, IdComponente) :-
    componente(IdComponente, _, _, _).

% componente_sospechoso(+Vehiculo, +Sintomas, -IdComponente)
% Determina componentes posiblemente afectados compatibles con el vehiculo.
componente_sospechoso(Vehiculo, Sintomas, IdComponente) :-
    tiene_sintoma(IdSintoma, Sintomas),
    componente_afectado_por_sintoma(IdSintoma, IdComponente, _),
    componente_compatible_vehiculo(Vehiculo, IdComponente).

% ----------------------------------------------------------------------------
% 4. REGLAS DE DIAGNOSTICO PRELIMINAR (SINTOMAS + CONDICIONES -> FALLA)
% ----------------------------------------------------------------------------

% diagnostico_preliminar(+Vehiculo, +Sintomas, -IdFalla)
% Genera candidatos preliminares de falla a partir de patrones de sintomas
% y condiciones generales del vehiculo (antes de descarte e inferencia compuesta).

diagnostico_preliminar(_, Sintomas, falla_rele_arranque) :-
    tiene_sintoma(no_arranca, Sintomas),
    tiene_sintoma(motor_arranque_no_gira, Sintomas),
    tiene_sintoma(luces_funcionan, Sintomas).

diagnostico_preliminar(_, Sintomas, falla_solenoide_arranque) :-
    tiene_sintoma(no_arranca, Sintomas),
    tiene_sintoma(motor_arranque_no_gira, Sintomas),
    (   tiene_sintoma(chasquido_al_girar_llave, Sintomas)
    ;   tiene_sintoma(luces_funcionan, Sintomas)
    ).

diagnostico_preliminar(_, Sintomas, falla_circuito_control_arranque) :-
    tiene_sintoma(no_arranca, Sintomas),
    tiene_sintoma(motor_arranque_no_gira, Sintomas),
    tiene_sintoma(voltaje_bateria_adecuado, Sintomas).

diagnostico_preliminar(_, Sintomas, bateria_descargada) :-
    (   tiene_sintoma(no_arranca, Sintomas)
    ;   tiene_sintoma(motor_arranque_gira_lento, Sintomas)
    ),
    (   tiene_sintoma(voltaje_bateria_bajo, Sintomas)
    ;   tiene_sintoma(luces_tenues, Sintomas)
    ;   tiene_sintoma(luces_no_encienden, Sintomas)
    ).

diagnostico_preliminar(_, Sintomas, alternador_defectuoso) :-
    tiene_sintoma(testigo_bateria_encendido, Sintomas).
diagnostico_preliminar(_, Sintomas, alternador_defectuoso) :-
    tiene_sintoma(voltaje_bateria_bajo, Sintomas),
    (   tiene_sintoma(luces_tenues, Sintomas)
    ;   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ).

diagnostico_preliminar(_, Sintomas, motor_arranque_averiado) :-
    tiene_sintoma(no_arranca, Sintomas),
    (   tiene_sintoma(motor_arranque_no_gira, Sintomas)
    ;   tiene_sintoma(motor_arranque_gira_lento, Sintomas)
    ),
    (   tiene_sintoma(chasquido_al_girar_llave, Sintomas)
    ;   tiene_sintoma(voltaje_bateria_adecuado, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, bujias_o_bobinas_encendido_fallando) :-
    tipo_encendido_vehiculo(Vehiculo, Enc),
    (Enc = encendido_por_chispa ; Enc = desconocido),
    (   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(tirones_al_acelerar, Sintomas)
    ;   (tiene_sintoma(no_arranca, Sintomas), tiene_sintoma(motor_arranque_gira_normal, Sintomas))
    ),
    (   tiene_sintoma(perdida_potencia, Sintomas)
    ;   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ;   tiene_sintoma(tirones_al_acelerar, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, bomba_combustible_defectuosa) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica,
    (   (   tiene_sintoma(no_arranca, Sintomas),
            tiene_sintoma(motor_arranque_gira_normal, Sintomas)
        )
    ;   (   tiene_sintoma(perdida_potencia, Sintomas),
            (   tiene_sintoma(tirones_al_acelerar, Sintomas)
            ;   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
            )
        )
    ).

diagnostico_preliminar(Vehiculo, Sintomas, inyectores_sucios_o_defectuosos) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    (Sist = inyeccion_electronica ; Sist = inyeccion_diesel ; Sist = desconocido),
    (   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(tirones_al_acelerar, Sintomas)
    ),
    (   tiene_sintoma(humo_negro_escape, Sintomas)
    ;   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ;   tiene_sintoma(olor_gasolina, Sintomas)
    ;   tiene_sintoma(perdida_potencia, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, carburador_desajustado_o_sucio) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    (Sist = carburador ; Sist = desconocido),
    (   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(humo_negro_escape, Sintomas)
    ;   tiene_sintoma(tirones_al_acelerar, Sintomas)
    ),
    (   tiene_sintoma(olor_gasolina, Sintomas)
    ;   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ;   tiene_sintoma(humo_negro_escape, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, fuga_empaque_culata) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica,
    tiene_sintoma(sobrecalentamiento_motor, Sintomas),
    (   tiene_sintoma(humo_blanco_escape, Sintomas)
    ;   tiene_sintoma(fuga_refrigerante, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, termostato_bloqueado) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica,
    tiene_sintoma(sobrecalentamiento_motor, Sintomas).

diagnostico_preliminar(Vehiculo, Sintomas, desgaste_anillos_piston) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica,
    tiene_sintoma(humo_azul_escape, Sintomas),
    (   tiene_sintoma(perdida_potencia, Sintomas)
    ;   tiene_sintoma(ruido_metalico_motor, Sintomas)
    ;   nivel_desgaste_kilometraje(Vehiculo, kilometraje_alto)
    ;   nivel_desgaste_kilometraje(Vehiculo, kilometraje_critico)
    ).

diagnostico_preliminar(_, Sintomas, aire_sistema_frenos) :-
    tiene_sintoma(pedal_freno_esponjoso, Sintomas).

diagnostico_preliminar(_, Sintomas, discos_freno_deformados) :-
    tiene_sintoma(vibracion_al_frenar, Sintomas).

diagnostico_preliminar(Vehiculo, Sintomas, sensor_maf_map_defectuoso) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    (Sist = inyeccion_electronica ; Sist = inyeccion_diesel ; Sist = desconocido),
    (   tiene_sintoma(testigo_check_engine, Sintomas)
    ;   tiene_sintoma(codigo_error_obd_sensor, Sintomas)
    ),
    (   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ;   tiene_sintoma(humo_negro_escape, Sintomas)
    ;   tiene_sintoma(ralenti_inestable, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, sensor_posicion_ciguenal_ckp) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica,
    (   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ;   (tiene_sintoma(no_arranca, Sintomas), tiene_sintoma(motor_arranque_gira_normal, Sintomas))
    ),
    (   tiene_sintoma(testigo_check_engine, Sintomas)
    ;   tiene_sintoma(codigo_error_obd_sensor, Sintomas)
    ;   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ).

diagnostico_preliminar(Vehiculo, Sintomas, cuerpo_aceleracion_electronico_descalibrado) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    (Sist = inyeccion_electronica ; Sist = inyeccion_diesel ; Sist = desconocido),
    (   tiene_sintoma(fallo_acelerador_electronico, Sintomas)
    ;   (   tiene_sintoma(testigo_check_engine, Sintomas),
            tiene_sintoma(ralenti_inestable, Sintomas),
            tiene_sintoma(perdida_potencia, Sintomas)
        )
    ).

diagnostico_preliminar(_, Sintomas, falla_unidad_control_ecu) :-
    tiene_sintoma(testigo_check_engine, Sintomas),
    tiene_sintoma(codigo_error_obd_sensor, Sintomas),
    (   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ;   tiene_sintoma(no_arranca, Sintomas)
    ;   tiene_sintoma(fallo_acelerador_electronico, Sintomas)
    ).
