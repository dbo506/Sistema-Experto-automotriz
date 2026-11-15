% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz (Parte 2)
% Archivo : backend/inferencia.pl
% Modulo  : Razonamiento Compuesto, Hipotesis Alternativas y Descarte
% Autor   : Daniel
% ============================================================================
% Implementa reglas de inferencia compuestas que deducen estados de
% subsistema y fallas derivadas no almacenadas literalmente como hechos,
% genera multiples diagnosticos compatibles (RF-07), aplica descarte
% explicito de hipotesis incompatibles (\+) y deriva recomendaciones (RF-12).
% ============================================================================

:- consult('reglas.pl').

% ----------------------------------------------------------------------------
% 1. PREDICADOS INTERMEDIOS DE CONDICION FUNCIONAL
% ----------------------------------------------------------------------------

% energia_bateria_confirmada(+Sintomas)
% Concluye integridad basica de bateria cuando luces y voltaje son adecuados.
energia_bateria_confirmada(Sintomas) :-
    tiene_sintoma(luces_funcionan, Sintomas),
    tiene_sintoma(voltaje_bateria_adecuado, Sintomas).

% bloqueo_giro_arranque(+Sintomas)
% Concluye bloqueo de giro cuando el vehiculo no arranca y el motor de arranque no gira.
bloqueo_giro_arranque(Sintomas) :-
    tiene_sintoma(no_arranca, Sintomas),
    tiene_sintoma(motor_arranque_no_gira, Sintomas).

% evidencia_caida_tension_arranque(+Sintomas)
% Detecta indicios electricos consistentes con deficit de carga o tension.
evidencia_caida_tension_arranque(Sintomas) :-
    (   tiene_sintoma(luces_tenues, Sintomas)
    ;   tiene_sintoma(luces_no_encienden, Sintomas)
    ;   tiene_sintoma(motor_arranque_gira_lento, Sintomas)
    ;   tiene_sintoma(voltaje_bateria_bajo, Sintomas)
    ).

% giro_efectivo_sin_encendido(+Sintomas)
% Concluye que el circuito de arranque opera, pero falla la combustion o ignicion.
giro_efectivo_sin_encendido(Sintomas) :-
    tiene_sintoma(no_arranca, Sintomas),
    tiene_sintoma(motor_arranque_gira_normal, Sintomas).

% vehiculo_combustion_interna(+Vehiculo)
% Verdadero cuando el vehiculo evaluado posee motor de combustion interna.
vehiculo_combustion_interna(Vehiculo) :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    Sist \= propulsion_electrica.

% ----------------------------------------------------------------------------
% 2. REGLAS DE INFERENCIA COMPUESTAS (ESTADO DE SUBSISTEMA Y FALLA DEDUCIDA)
% ----------------------------------------------------------------------------

% estado_subsistema_inferido(+Vehiculo, +Sintomas, -IdSubsistema, -EstadoInferido)
% Deduce estados funcionales intermedios encadenando sintomas y perfil del vehiculo.

% Regla compuesta 1 (Caso obligatorio del dominio):
% No arranca + luces funcionan + motor de arranque no gira + voltaje adecuado
% -> interrupcion en circuito de arranque con bateria sana.
estado_subsistema_inferido(_, Sintomas, electrico, interrupcion_circuito_arranque_con_bateria_sana) :-
    bloqueo_giro_arranque(Sintomas),
    energia_bateria_confirmada(Sintomas).

% Regla compuesta 2:
% Bloqueo de giro + chasquido al girar llave + luces funcionales
% -> bloqueo electromecanico en acoplamiento del arranque.
estado_subsistema_inferido(_, Sintomas, electrico, bloqueo_electromecanico_arranque) :-
    bloqueo_giro_arranque(Sintomas),
    tiene_sintoma(chasquido_al_girar_llave, Sintomas),
    tiene_sintoma(luces_funcionan, Sintomas).

% Regla compuesta 3:
% No arranca + evidencia de caida de tension
% -> deficit de energia primaria en almacenamiento.
estado_subsistema_inferido(_, Sintomas, electrico, deficit_energia_primaria_bateria) :-
    tiene_sintoma(no_arranca, Sintomas),
    evidencia_caida_tension_arranque(Sintomas).

% Regla compuesta 4:
% Testigo de bateria encendido + sintomas de caida electrica en operacion
% -> falla de generacion o regulacion en sistema de carga.
estado_subsistema_inferido(_, Sintomas, electrico, falla_generacion_carga_alternador) :-
    tiene_sintoma(testigo_bateria_encendido, Sintomas),
    (   tiene_sintoma(luces_tenues, Sintomas)
    ;   tiene_sintoma(voltaje_bateria_bajo, Sintomas)
    ;   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ).

% Regla compuesta 5:
% Motor de combustion + (giro normal sin encendido o perdida de potencia con tirones)
% -> deficiencia en suministro y presion de combustible.
estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, deficiencia_suministro_combustible) :-
    vehiculo_combustion_interna(Vehiculo),
    (   giro_efectivo_sin_encendido(Sintomas)
    ;   (   tiene_sintoma(perdida_potencia, Sintomas),
            tiene_sintoma(tirones_al_acelerar, Sintomas)
        )
    ).

% Regla compuesta 6:
% Motor de combustion + humo negro + consumo excesivo + sintoma de marcha/olor
% -> mezcla aire-combustible rica y combustion incompleta.
estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, mezcla_rica_combustion_incompleta) :-
    vehiculo_combustion_interna(Vehiculo),
    tiene_sintoma(humo_negro_escape, Sintomas),
    tiene_sintoma(consumo_excesivo_combustible, Sintomas),
    (   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(olor_gasolina, Sintomas)
    ;   tiene_sintoma(perdida_potencia, Sintomas)
    ).

% Regla compuesta 7:
% Encendido por chispa + inestabilidad/tirones + caida de rendimiento
% -> falla de ignicion en cilindros.
estado_subsistema_inferido(Vehiculo, Sintomas, electrico, falla_ignicion_cilindros) :-
    tipo_encendido_vehiculo(Vehiculo, Enc),
    (Enc = encendido_por_chispa ; Enc = desconocido),
    (   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(tirones_al_acelerar, Sintomas)
    ),
    (   tiene_sintoma(perdida_potencia, Sintomas)
    ;   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ).

% Regla compuesta 8:
% Motor de combustion + sobrecalentamiento + fuga/humo blanco/perdida de potencia
% -> compromiso termico y posible dano estructural de culata o flujo refrigerante.
estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, compromiso_termico_estructural_motor) :-
    vehiculo_combustion_interna(Vehiculo),
    tiene_sintoma(sobrecalentamiento_motor, Sintomas),
    (   tiene_sintoma(fuga_refrigerante, Sintomas)
    ;   tiene_sintoma(humo_blanco_escape, Sintomas)
    ;   tiene_sintoma(perdida_potencia, Sintomas)
    ).

% Regla compuesta 9:
% Motor de combustion + humo azul + perdida de potencia + desgaste/ruido
% -> degradacion de sellado y compresion en anillos de piston.
estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, degradacion_compresion_anillos) :-
    vehiculo_combustion_interna(Vehiculo),
    tiene_sintoma(humo_azul_escape, Sintomas),
    tiene_sintoma(perdida_potencia, Sintomas),
    (   tiene_sintoma(ruido_metalico_motor, Sintomas)
    ;   nivel_desgaste_kilometraje(Vehiculo, kilometraje_alto)
    ;   nivel_desgaste_kilometraje(Vehiculo, kilometraje_critico)
    ).

% Regla compuesta 10:
% Testigo Check Engine + anomalia electronica o de marcha
% -> desincronizacion en gestion electronica de sensores y ECU.
estado_subsistema_inferido(_, Sintomas, electronico, desincronizacion_gestion_electronica_ecu) :-
    tiene_sintoma(testigo_check_engine, Sintomas),
    (   tiene_sintoma(codigo_error_obd_sensor, Sintomas)
    ;   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ;   tiene_sintoma(fallo_acelerador_electronico, Sintomas)
    ;   tiene_sintoma(ralenti_inestable, Sintomas)
    ).

% Regla compuesta 11:
% Pedal esponjoso o vibracion al frenar
% -> anomalia hidraulica o de friccion en sistema de frenado.
estado_subsistema_inferido(_, Sintomas, mecanico, anomalia_hidraulica_o_friccion_frenos) :-
    (   tiene_sintoma(pedal_freno_esponjoso, Sintomas)
    ;   tiene_sintoma(vibracion_al_frenar, Sintomas)
    ).

% inferir_falla_compuesta(+Vehiculo, +Sintomas, -IdFalla, -EstadoInferido)
% Traduce los estados intermedios inferidos en hipotesis diagnosticas especificas.
inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, interrupcion_circuito_arranque_con_bateria_sana) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electrico, interrupcion_circuito_arranque_con_bateria_sana),
    member(IdFalla, [falla_rele_arranque, falla_solenoide_arranque, falla_circuito_control_arranque]).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, bloqueo_electromecanico_arranque) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electrico, bloqueo_electromecanico_arranque),
    member(IdFalla, [falla_solenoide_arranque, motor_arranque_averiado]).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, deficit_energia_primaria_bateria) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electrico, deficit_energia_primaria_bateria),
    member(IdFalla, [bateria_descargada, alternador_defectuoso]).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, falla_generacion_carga_alternador) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electrico, falla_generacion_carga_alternador),
    member(IdFalla, [alternador_defectuoso, bateria_descargada]).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, deficiencia_suministro_combustible) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, deficiencia_suministro_combustible),
    member(IdFalla, [bomba_combustible_defectuosa, inyectores_sucios_o_defectuosos, carburador_desajustado_o_sucio]).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, mezcla_rica_combustion_incompleta) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, mezcla_rica_combustion_incompleta),
    member(IdFalla, [inyectores_sucios_o_defectuosos, sensor_maf_map_defectuoso, carburador_desajustado_o_sucio]).

inferir_falla_compuesta(Vehiculo, Sintomas, bujias_o_bobinas_encendido_fallando, falla_ignicion_cilindros) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electrico, falla_ignicion_cilindros).

inferir_falla_compuesta(Vehiculo, Sintomas, IdFalla, compromiso_termico_estructural_motor) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, compromiso_termico_estructural_motor),
    (   (   tiene_sintoma(humo_blanco_escape, Sintomas)
        ;   tiene_sintoma(fuga_refrigerante, Sintomas)
        )
    ->  member(IdFalla, [fuga_empaque_culata, termostato_bloqueado])
    ;   IdFalla = termostato_bloqueado
    ).

inferir_falla_compuesta(Vehiculo, Sintomas, desgaste_anillos_piston, degradacion_compresion_anillos) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, degradacion_compresion_anillos).

inferir_falla_compuesta(Vehiculo, Sintomas, sensor_posicion_ciguenal_ckp, desincronizacion_gestion_electronica_ecu) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electronico, desincronizacion_gestion_electronica_ecu),
    (   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ;   tiene_sintoma(no_arranca, Sintomas)
    ;   tiene_sintoma(codigo_error_obd_sensor, Sintomas)
    ).
inferir_falla_compuesta(Vehiculo, Sintomas, sensor_maf_map_defectuoso, desincronizacion_gestion_electronica_ecu) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electronico, desincronizacion_gestion_electronica_ecu),
    (   tiene_sintoma(consumo_excesivo_combustible, Sintomas)
    ;   tiene_sintoma(humo_negro_escape, Sintomas)
    ;   tiene_sintoma(ralenti_inestable, Sintomas)
    ;   tiene_sintoma(codigo_error_obd_sensor, Sintomas)
    ).
inferir_falla_compuesta(Vehiculo, Sintomas, cuerpo_aceleracion_electronico_descalibrado, desincronizacion_gestion_electronica_ecu) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electronico, desincronizacion_gestion_electronica_ecu),
    (   tiene_sintoma(fallo_acelerador_electronico, Sintomas)
    ;   tiene_sintoma(ralenti_inestable, Sintomas)
    ).
inferir_falla_compuesta(Vehiculo, Sintomas, falla_unidad_control_ecu, desincronizacion_gestion_electronica_ecu) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, electronico, desincronizacion_gestion_electronica_ecu),
    tiene_sintoma(codigo_error_obd_sensor, Sintomas),
    (   tiene_sintoma(motor_se_apaga_en_marcha, Sintomas)
    ;   tiene_sintoma(no_arranca, Sintomas)
    ;   tiene_sintoma(fallo_acelerador_electronico, Sintomas)
    ).

inferir_falla_compuesta(Vehiculo, Sintomas, aire_sistema_frenos, anomalia_hidraulica_o_friccion_frenos) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, anomalia_hidraulica_o_friccion_frenos),
    tiene_sintoma(pedal_freno_esponjoso, Sintomas).
inferir_falla_compuesta(Vehiculo, Sintomas, discos_freno_deformados, anomalia_hidraulica_o_friccion_frenos) :-
    estado_subsistema_inferido(Vehiculo, Sintomas, mecanico, anomalia_hidraulica_o_friccion_frenos),
    tiene_sintoma(vibracion_al_frenar, Sintomas).

% ----------------------------------------------------------------------------
% 3. DESCARTE EXPLICITO DE HIPOTESIS INCOMPATIBLES
% ----------------------------------------------------------------------------

% hipotesis_incompatible(+Vehiculo, +Sintomas, +IdFalla, -MotivoDescarte)
% Reglas explicitas que excluyen una hipotesis por evidencia contradictoria
% o por incompatibilidad arquitectonica del vehiculo.

hipotesis_incompatible(_, Sintomas, bateria_descargada,
    'luces funcionan normalmente y voltaje de bateria es adecuado') :-
    energia_bateria_confirmada(Sintomas).
hipotesis_incompatible(_, Sintomas, bateria_descargada,
    'el motor de arranque gira con velocidad y fuerza normal') :-
    tiene_sintoma(motor_arranque_gira_normal, Sintomas).

hipotesis_incompatible(Vehiculo, _, carburador_desajustado_o_sucio,
    'el vehiculo no utiliza carburador segun su sistema de alimentacion') :-
    sistema_alimentacion_vehiculo(Vehiculo, Sist),
    member(Sist, [inyeccion_electronica, inyeccion_diesel, propulsion_electrica]).

hipotesis_incompatible(Vehiculo, _, inyectores_sucios_o_defectuosos,
    'el vehiculo posee carburador mecanico y no utiliza inyectores') :-
    sistema_alimentacion_vehiculo(Vehiculo, carburador).

hipotesis_incompatible(Vehiculo, _, cuerpo_aceleracion_electronico_descalibrado,
    'el vehiculo utiliza carburador mecanico sin mariposa electronica') :-
    sistema_alimentacion_vehiculo(Vehiculo, carburador).

hipotesis_incompatible(Vehiculo, _, bujias_o_bobinas_encendido_fallando,
    'el tipo de motor no emplea encendido por chispa ni bujias') :-
    tipo_encendido_vehiculo(Vehiculo, Enc),
    member(Enc, [encendido_por_compresion, control_inversor_electrico]).

hipotesis_incompatible(Vehiculo, _, IdFalla,
    'el vehiculo es 100% electrico y carece de motor de combustion interna') :-
    sistema_alimentacion_vehiculo(Vehiculo, propulsion_electrica),
    member(IdFalla, [
        bomba_combustible_defectuosa, inyectores_sucios_o_defectuosos,
        carburador_desajustado_o_sucio, bujias_o_bobinas_encendido_fallando,
        fuga_empaque_culata, termostato_bloqueado, desgaste_anillos_piston,
        sensor_maf_map_defectuoso, sensor_posicion_ciguenal_ckp,
        cuerpo_aceleracion_electronico_descalibrado, motor_arranque_averiado,
        falla_rele_arranque, falla_solenoide_arranque, falla_circuito_control_arranque
    ]).

hipotesis_incompatible(_, Sintomas, IdFalla,
    'el motor de arranque gira normalmente y descarta fallo en circuito de arranque') :-
    tiene_sintoma(motor_arranque_gira_normal, Sintomas),
    member(IdFalla, [
        falla_rele_arranque, falla_solenoide_arranque,
        falla_circuito_control_arranque, motor_arranque_averiado
    ]).

hipotesis_incompatible(_, Sintomas, IdFalla,
    'la caida de voltaje e iluminacion indica falta de energia primaria y no falla aislada de mando') :-
    tiene_sintoma(voltaje_bateria_bajo, Sintomas),
    (   tiene_sintoma(luces_no_encienden, Sintomas)
    ;   tiene_sintoma(luces_tenues, Sintomas)
    ),
    member(IdFalla, [falla_rele_arranque, falla_circuito_control_arranque]).

% hipotesis_descartada(+Vehiculo, +Sintomas, +IdFalla)
% Verdadero cuando existe al menos una incompatibilidad probada para IdFalla.
hipotesis_descartada(Vehiculo, Sintomas, IdFalla) :-
    hipotesis_incompatible(Vehiculo, Sintomas, IdFalla, _), !.

% descartes_relevantes(+Vehiculo, +Sintomas, -ListaMotivos)
% Recopila motivos unicos de descarte activos en la evaluacion actual.
descartes_relevantes(Vehiculo, Sintomas, ListaMotivos) :-
    findall(
        Motivo,
        hipotesis_incompatible(Vehiculo, Sintomas, _, Motivo),
        Brutos
    ),
    list_to_set(Brutos, ListaMotivos).

% ----------------------------------------------------------------------------
% 4. GENERACION DE DIAGNOSTICOS ALTERNATIVOS (RF-07) Y RECOMENDACIONES (RF-12)
% ----------------------------------------------------------------------------

% hipotesis_diagnostica(+Vehiculo, +Sintomas, -IdFalla, -IdSubsistema, -EstadoInferido)
% Combina inferencia compuesta y diagnostico preliminar, permitiendo multiples
% hipotesis compatibles y excluyendo toda hipotesis incompatible mediante \+.
hipotesis_diagnostica(Vehiculo, Sintomas, IdFalla, IdSubsistema, EstadoInferido) :-
    vehiculo_efectivo(Vehiculo, VehiculoEval),
    falla_catalogo(IdFalla, IdSubsistema, _, _, _),
    (   inferir_falla_compuesta(VehiculoEval, Sintomas, IdFalla, EstadoInferido)
    ->  true
    ;   diagnostico_preliminar(VehiculoEval, Sintomas, IdFalla),
        EstadoInferido = evaluacion_directa_sintomas
    ),
    \+ hipotesis_descartada(VehiculoEval, Sintomas, IdFalla).

% ajustar_longitud_atomo(+Texto, +MaxCaracteres, -TextoSeguro)
% Recorta un atomo si excede el tamano maximo de buffer en C para evitar truncamiento.
ajustar_longitud_atomo(Texto, Max, Texto) :-
    atom_length(Texto, Longitud),
    Longitud =< Max, !.
ajustar_longitud_atomo(Texto, Max, TextoRecortado) :-
    PrefijoLen is Max - 3,
    PrefijoLen > 0,
    sub_atom(Texto, 0, PrefijoLen, _, Prefijo),
    atom_concat(Prefijo, '...', TextoRecortado).

% derivar_recomendacion(+Vehiculo, +Sintomas, +IdFalla, -Prueba, -Accion, -RecomendacionTexto)
% Deriva prueba adicional y accion correctiva contextualizadas para RF-12.
derivar_recomendacion(Vehiculo, _Sintomas, IdFalla, Prueba, Accion, RecomendacionTexto) :-
    vehiculo_efectivo(Vehiculo, VehiculoEval),
    prueba_verificacion(IdFalla, Prueba),
    accion_correctiva(IdFalla, Accion),
    nivel_desgaste_kilometraje(VehiculoEval, NivelKm),
    (   (NivelKm = kilometraje_alto ; NivelKm = kilometraje_critico)
    ->  NotaDesgaste = ' Considerar revision preventiva adicional por alto kilometraje.'
    ;   NotaDesgaste = ''
    ),
    atomic_list_concat(
        ['Prueba: ', Prueba, '. Accion: ', Accion, '.', NotaDesgaste],
        '',
        TextoCompleto
    ),
    ajustar_longitud_atomo(TextoCompleto, 480, RecomendacionTexto).
