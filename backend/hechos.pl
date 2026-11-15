% ============================================================================
% Proyecto: Sistema Experto Inteligente de Diagnostico Automotriz (Parte 2)
% Archivo : backend/hechos.pl
% Modulo  : Base de Conocimientos (Hechos del Dominio Automotriz)
% Autor   : Daniel
% ============================================================================
% Contiene hechos estaticos estructurados sobre subsistemas (mecanico,
% electrico, electronico), caracteristicas vehiculares, componentes,
% catalogo oficial de sintomas, fallas especificas, pruebas adicionales
% y acciones correctivas, ademas de hechos dinamicos para sesion activa.
% Todos los textos evitan caracteres de control y se mantienen dentro de
% los limites de buffer de frontend/tipos.h e integracion/conexion.c.
% ============================================================================

:- dynamic vehiculo_actual/5.
:- dynamic sintoma_activo/1.

% ----------------------------------------------------------------------------
% 1. SUBSISTEMAS AUTOMOTRICES (subsistema/3)
%    subsistema(IdSubsistema, NombreLegible, Descripcion).
% ----------------------------------------------------------------------------

subsistema(mecanico, 'Subsistema Mecanico',
    'Conjunto de elementos de combustion, refrigeracion, lubricacion, alimentacion y frenado').
subsistema(electrico, 'Subsistema Electrico',
    'Circuito de almacenamiento, carga, arranque y encendido primario de alto amperaje').
subsistema(electronico, 'Subsistema Electronico',
    'Red de sensores, actuadores electronicos, modulos de control (ECU) y diagnostico OBD').

% ----------------------------------------------------------------------------
% 2. CATALOGO DE COMBUSTIBLES Y PROPULSION (combustible_catalogo/4)
%    combustible_catalogo(IdCombustible, AlimentacionDefecto, Encendido, Categoria).
% ----------------------------------------------------------------------------

combustible_catalogo(gasolina, inyeccion_electronica, encendido_por_chispa, combustion_interna).
combustible_catalogo(diesel, inyeccion_diesel, encendido_por_compresion, combustion_interna).
combustible_catalogo(hibrido, inyeccion_electronica, encendido_por_chispa, hibrido_combustion_electrica).
combustible_catalogo(electrico, propulsion_electrica, control_inversor_electrico, propulsion_electrica_pura).
combustible_catalogo(glp, inyeccion_electronica, encendido_por_chispa, combustion_interna).

% ----------------------------------------------------------------------------
% 3. PERFILES DE REFERENCIA DE VEHICULOS (perfil_modelo_vehiculo/7)
%    perfil_modelo_vehiculo(Marca, Modelo, AnioMin, AnioMax, Combustible, Transmision, Alimentacion).
% ----------------------------------------------------------------------------

perfil_modelo_vehiculo(toyota, corolla, 1988, 1994, gasolina, manual, carburador).
perfil_modelo_vehiculo(toyota, corolla, 1995, 2026, gasolina, automatica, inyeccion_electronica).
perfil_modelo_vehiculo(toyota, hilux, 2005, 2026, diesel, manual, inyeccion_diesel).
perfil_modelo_vehiculo(toyota, prius, 2004, 2026, hibrido, cvt, inyeccion_electronica).
perfil_modelo_vehiculo(chevrolet, spark, 2006, 2022, gasolina, manual, inyeccion_electronica).
perfil_modelo_vehiculo(chevrolet, aveo, 2004, 2024, gasolina, manual, inyeccion_electronica).
perfil_modelo_vehiculo(hyundai, accent, 1996, 2026, gasolina, automatica, inyeccion_electronica).
perfil_modelo_vehiculo(hyundai, tucson, 2005, 2026, gasolina, automatica, inyeccion_electronica).
perfil_modelo_vehiculo(ford, fiesta, 1998, 2023, gasolina, manual, inyeccion_electronica).
perfil_modelo_vehiculo(ford, ranger, 2006, 2026, diesel, automatica, inyeccion_diesel).
perfil_modelo_vehiculo(nissan, sentra, 1995, 2026, gasolina, cvt, inyeccion_electronica).
perfil_modelo_vehiculo(nissan, leaf, 2011, 2026, electrico, reductora_directa, propulsion_electrica).
perfil_modelo_vehiculo(volkswagen, gol, 1990, 1994, gasolina, manual, carburador).
perfil_modelo_vehiculo(volkswagen, gol, 1995, 2023, gasolina, manual, inyeccion_electronica).

% ----------------------------------------------------------------------------
% 4. UMBRALES OPERATIVOS DE KILOMETRAJE Y TECNOLOGIA (umbral_operativo/3)
%    umbral_operativo(Parametro, ValorMin, ValorMax).
% ----------------------------------------------------------------------------

umbral_operativo(kilometraje_bajo, 0, 49999).
umbral_operativo(kilometraje_moderado, 50000, 119999).
umbral_operativo(kilometraje_alto, 120000, 199999).
umbral_operativo(kilometraje_critico, 200000, 9999999).
umbral_operativo(anio_corte_inyeccion, 1995, 9999).

% ----------------------------------------------------------------------------
% 5. COMPONENTES Y RELACION COMPONENTE-SUBSISTEMA (componente/4)
%    componente(IdComponente, IdSubsistema, NombreLegible, FuncionPrincipal).
% ----------------------------------------------------------------------------

% Subsistema electrico
componente(bateria, electrico, 'Bateria de 12V',
    'Almacena energia quimica y suministra corriente inicial para el arranque y accesorios').
componente(alternador, electrico, 'Alternador',
    'Genera corriente electrica con el motor en marcha para alimentar sistemas y recargar bateria').
componente(motor_arranque, electrico, 'Motor de arranque',
    'Convierte energia electrica en torque mecanico para girar el volante del ciguenal').
componente(rele_arranque, electrico, 'Rele de arranque',
    'Interruptor electromagnetico que habilita la corriente de mando hacia el solenoide').
componente(solenoide_arranque, electrico, 'Solenoide de arranque',
    'Acopla el pinon bendix y cierra el circuito de alta corriente al motor de arranque').
componente(circuito_control_arranque, electrico, 'Circuito de control de arranque',
    'Cableado, interruptor de encendido, fusible e inhibidor de arranque en transmision').
componente(sistema_encendido_bujias, electrico, 'Bujias y bobinas de encendido',
    'Generan el arco electrico de alta tension para inflamar la mezcla aire-combustible').

% Subsistema mecanico
componente(bomba_combustible, mecanico, 'Bomba de combustible',
    'Presuriza y envia combustible desde el tanque hacia el riel de inyeccion o carburador').
componente(inyectores_combustible, mecanico, 'Inyectores de combustible',
    'Pulverizan el combustible dosificado dentro del multiple o camara de combustion').
componente(carburador, mecanico, 'Carburador',
    'Mezcla mecanicamente aire y combustible por efecto Venturi en motores antiguos').
componente(empaque_culata, mecanico, 'Empaque de culata',
    'Sella la union entre bloque y culata separando compresion, aceite y refrigerante').
componente(termostato_enfriamiento, mecanico, 'Termostato de refrigeracion',
    'Regula la circulacion de refrigerante hacia el radiador segun la temperatura del motor').
componente(anillos_piston, mecanico, 'Anillos de piston',
    'Mantienen la estanqueidad de compresion y controlan la pelicula de aceite en cilindros').
componente(circuito_hidraulico_frenos, mecanico, 'Circuito hidraulico de frenos',
    'Transmite presion hidraulica desde el cilindro maestro hacia mordazas y cilindros').
componente(discos_freno, mecanico, 'Discos de freno',
    'Superficie metalica giratoria sobre la que actuan las pastillas para frenar el vehiculo').

% Subsistema electronico
componente(sensor_maf_map, electronico, 'Sensor de flujo/presion de aire (MAF/MAP)',
    'Mide masa o presion de aire admitido para que la ECU calcule la inyeccion').
componente(sensor_ckp_ciguenal, electronico, 'Sensor de posicion del ciguenal (CKP)',
    'Informa RPM y posicion angular del ciguenal para sincronizar chispa e inyeccion').
componente(cuerpo_aceleracion_electronico, electronico, 'Cuerpo de aceleracion electronico',
    'Regula electronicamente la apertura de la mariposa de admision segun demanda del pedal').
componente(unidad_control_ecu, electronico, 'Unidad de control electronico (ECU)',
    'Computadora central que procesa senales de sensores y comanda actuadores del motor').

% ----------------------------------------------------------------------------
% 6. CATALOGO OFICIAL DE SINTOMAS (sintoma_catalogo/4)
%    sintoma_catalogo(IdSintoma, SubsistemaPrimario, Categoria, Descripcion).
%    Nota: Los identificadores cumplen ^[a-z][a-z0-9_]{0,62}$ (validaciones.c).
% ----------------------------------------------------------------------------

sintoma_catalogo(no_arranca, electrico, arranque,
    'El motor no logra ponerse en marcha al accionar el encendido').
sintoma_catalogo(luces_funcionan, electrico, iluminacion,
    'Los faros y luces de cabina mantienen intensidad normal').
sintoma_catalogo(luces_tenues, electrico, iluminacion,
    'Las luces encienden con brillo debil o parpadean al dar arranque').
sintoma_catalogo(luces_no_encienden, electrico, iluminacion,
    'Ausencia total de iluminacion en faros y tablero').
sintoma_catalogo(motor_arranque_no_gira, electrico, arranque,
    'El motor de arranque permanece inmovil al girar la llave o pulsar boton').
sintoma_catalogo(motor_arranque_gira_lento, electrico, arranque,
    'El motor de arranque gira con poca fuerza y cadencia lenta').
sintoma_catalogo(motor_arranque_gira_normal, electrico, arranque,
    'El motor de arranque gira a velocidad normal pero el motor no enciende').
sintoma_catalogo(voltaje_bateria_adecuado, electrico, medicion,
    'Medicion de bateria en reposo igual o superior a 12.4 voltios').
sintoma_catalogo(voltaje_bateria_bajo, electrico, medicion,
    'Medicion de bateria por debajo de 12.0 voltios').
sintoma_catalogo(chasquido_al_girar_llave, electrico, arranque,
    'Se escucha un clic o chasquido metalico unico o repetido al intentar arrancar').
sintoma_catalogo(testigo_bateria_encendido, electrico, tablero,
    'Luz de advertencia de bateria permanece encendida en el tablero').
sintoma_catalogo(testigo_check_engine, electronico, tablero,
    'Indicador luminoso Check Engine encendido o parpadeando en el tablero').
sintoma_catalogo(codigo_error_obd_sensor, electronico, escaneo,
    'Escaner OBD registra codigo de falla asociado a sensores o control').
sintoma_catalogo(fallo_acelerador_electronico, electronico, control,
    'Respuesta nula, tardia o modo de proteccion al pisar el acelerador').
sintoma_catalogo(motor_se_apaga_en_marcha, electronico, operacion,
    'El motor se detiene de forma repentina mientras circula o en ralenti').
sintoma_catalogo(ralenti_inestable, mecanico, operacion,
    'Vibraciones o oscilaciones de RPM cuando el vehiculo esta detenido en marcha minima').
sintoma_catalogo(perdida_potencia, mecanico, rendimiento,
    'Falta de fuerza y aceleracion deficiente bajo carga o en pendientes').
sintoma_catalogo(tirones_al_acelerar, mecanico, rendimiento,
    'Sacudidas o cortes intermitentes al demandar aceleracion').
sintoma_catalogo(consumo_excesivo_combustible, mecanico, alimentacion,
    'Incremento notable en el gasto de combustible frente al rendimiento normal').
sintoma_catalogo(olor_gasolina, mecanico, alimentacion,
    'Olor fuerte a combustible sin quemar alrededor del motor o escape').
sintoma_catalogo(humo_negro_escape, mecanico, emisiones,
    'Emision de humo oscuro denso por el escape por mezcla excesivamente rica').
sintoma_catalogo(humo_azul_escape, mecanico, emisiones,
    'Emision de humo azulado por quema de aceite en camara de combustion').
sintoma_catalogo(humo_blanco_escape, mecanico, emisiones,
    'Humo blanco espeso y persistente en escape aun con motor en temperatura normal').
sintoma_catalogo(sobrecalentamiento_motor, mecanico, temperatura,
    'Indicador de temperatura en zona roja o ebullicion en deposito de refrigerante').
sintoma_catalogo(fuga_refrigerante, mecanico, temperatura,
    'Perdida visible o descenso continuo de liquido refrigerante sin causa externa obvia').
sintoma_catalogo(ruido_metalico_motor, mecanico, estructura,
    'Golpeteo o sonido metalico anomalo proveniente del bloque o parte alta del motor').
sintoma_catalogo(pedal_freno_esponjoso, mecanico, frenos,
    'El pedal de freno se siente blando, se hunde excesivamente o pierde firmeza').
sintoma_catalogo(vibracion_al_frenar, mecanico, frenos,
    'Pulsacion en el pedal o vibracion en el volante al aplicar los frenos').

% ----------------------------------------------------------------------------
% 7. CATALOGO DE FALLAS ESPECIFICAS (falla_catalogo/5)
%    falla_catalogo(IdFalla, Subsistema, Componente, TituloDiagnostico, Severidad).
% ----------------------------------------------------------------------------

falla_catalogo(falla_rele_arranque, electrico, rele_arranque,
    'Falla en rele de arranque', media).
falla_catalogo(falla_solenoide_arranque, electrico, solenoide_arranque,
    'Falla en solenoide del motor de arranque', media).
falla_catalogo(falla_circuito_control_arranque, electrico, circuito_control_arranque,
    'Interrupcion en circuito de control de arranque', media).
falla_catalogo(bateria_descargada, electrico, bateria,
    'Bateria descargada o con capacidad insuficiente', baja).
falla_catalogo(alternador_defectuoso, electrico, alternador,
    'Falla en alternador o regulador de voltaje', alta).
falla_catalogo(motor_arranque_averiado, electrico, motor_arranque,
    'Averia mecanica o electrica en motor de arranque', alta).
falla_catalogo(bujias_o_bobinas_encendido_fallando, electrico, sistema_encendido_bujias,
    'Falla en bujias o bobinas de encendido', media).

falla_catalogo(bomba_combustible_defectuosa, mecanico, bomba_combustible,
    'Baja presion o falla en bomba de combustible', alta).
falla_catalogo(inyectores_sucios_o_defectuosos, mecanico, inyectores_combustible,
    'Inyectores de combustible obstruidos o defectuosos', media).
falla_catalogo(carburador_desajustado_o_sucio, mecanico, carburador,
    'Carburador desajustado o con obstruccion interna', media).
falla_catalogo(fuga_empaque_culata, mecanico, empaque_culata,
    'Fuga en empaque de culata y perdida de sellado', critica).
falla_catalogo(termostato_bloqueado, mecanico, termostato_enfriamiento,
    'Termostato bloqueado o falla en flujo refrigerante', alta).
falla_catalogo(desgaste_anillos_piston, mecanico, anillos_piston,
    'Desgaste en anillos de piston y perdida de compresion', critica).
falla_catalogo(aire_sistema_frenos, mecanico, circuito_hidraulico_frenos,
    'Presencia de aire o fuga en circuito hidraulico de frenos', critica).
falla_catalogo(discos_freno_deformados, mecanico, discos_freno,
    'Alabeo o desgaste irregular en discos de freno', alta).

falla_catalogo(sensor_maf_map_defectuoso, electronico, sensor_maf_map,
    'Lectura erronea en sensor de aire MAF o MAP', media).
falla_catalogo(sensor_posicion_ciguenal_ckp, electronico, sensor_ckp_ciguenal,
    'Falla en sensor de posicion del ciguenal (CKP)', alta).
falla_catalogo(cuerpo_aceleracion_electronico_descalibrado, electronico, cuerpo_aceleracion_electronico,
    'Falla o descalibracion en cuerpo de aceleracion electronico', media).
falla_catalogo(falla_unidad_control_ecu, electronico, unidad_control_ecu,
    'Anomalia en unidad de control electronico (ECU) o arnes', critica).

% ----------------------------------------------------------------------------
% 8. RELACION SINTOMAS ASOCIADOS A FALLAS (sintoma_asociado_falla/3)
%    sintoma_asociado_falla(IdFalla, IdSintoma, RolEvidencia).
% ----------------------------------------------------------------------------

sintoma_asociado_falla(falla_rele_arranque, no_arranca, primario).
sintoma_asociado_falla(falla_rele_arranque, motor_arranque_no_gira, primario).
sintoma_asociado_falla(falla_rele_arranque, luces_funcionan, secundario).
sintoma_asociado_falla(falla_rele_arranque, voltaje_bateria_adecuado, secundario).

sintoma_asociado_falla(falla_solenoide_arranque, no_arranca, primario).
sintoma_asociado_falla(falla_solenoide_arranque, motor_arranque_no_gira, primario).
sintoma_asociado_falla(falla_solenoide_arranque, chasquido_al_girar_llave, primario).
sintoma_asociado_falla(falla_solenoide_arranque, luces_funcionan, secundario).
sintoma_asociado_falla(falla_solenoide_arranque, voltaje_bateria_adecuado, secundario).

sintoma_asociado_falla(falla_circuito_control_arranque, no_arranca, primario).
sintoma_asociado_falla(falla_circuito_control_arranque, motor_arranque_no_gira, primario).
sintoma_asociado_falla(falla_circuito_control_arranque, luces_funcionan, secundario).
sintoma_asociado_falla(falla_circuito_control_arranque, voltaje_bateria_adecuado, secundario).

sintoma_asociado_falla(bateria_descargada, no_arranca, primario).
sintoma_asociado_falla(bateria_descargada, voltaje_bateria_bajo, primario).
sintoma_asociado_falla(bateria_descargada, luces_tenues, secundario).
sintoma_asociado_falla(bateria_descargada, luces_no_encienden, secundario).
sintoma_asociado_falla(bateria_descargada, motor_arranque_gira_lento, primario).

sintoma_asociado_falla(alternador_defectuoso, testigo_bateria_encendido, primario).
sintoma_asociado_falla(alternador_defectuoso, voltaje_bateria_bajo, primario).
sintoma_asociado_falla(alternador_defectuoso, luces_tenues, secundario).
sintoma_asociado_falla(alternador_defectuoso, motor_se_apaga_en_marcha, secundario).

sintoma_asociado_falla(motor_arranque_averiado, no_arranca, primario).
sintoma_asociado_falla(motor_arranque_averiado, motor_arranque_no_gira, primario).
sintoma_asociado_falla(motor_arranque_averiado, motor_arranque_gira_lento, secundario).
sintoma_asociado_falla(motor_arranque_averiado, chasquido_al_girar_llave, secundario).

sintoma_asociado_falla(bujias_o_bobinas_encendido_fallando, ralenti_inestable, primario).
sintoma_asociado_falla(bujias_o_bobinas_encendido_fallando, tirones_al_acelerar, primario).
sintoma_asociado_falla(bujias_o_bobinas_encendido_fallando, perdida_potencia, secundario).
sintoma_asociado_falla(bujias_o_bobinas_encendido_fallando, consumo_excesivo_combustible, secundario).
sintoma_asociado_falla(bujias_o_bobinas_encendido_fallando, no_arranca, secundario).

sintoma_asociado_falla(bomba_combustible_defectuosa, no_arranca, primario).
sintoma_asociado_falla(bomba_combustible_defectuosa, motor_arranque_gira_normal, primario).
sintoma_asociado_falla(bomba_combustible_defectuosa, perdida_potencia, primario).
sintoma_asociado_falla(bomba_combustible_defectuosa, tirones_al_acelerar, secundario).
sintoma_asociado_falla(bomba_combustible_defectuosa, motor_se_apaga_en_marcha, secundario).

sintoma_asociado_falla(inyectores_sucios_o_defectuosos, ralenti_inestable, primario).
sintoma_asociado_falla(inyectores_sucios_o_defectuosos, tirones_al_acelerar, primario).
sintoma_asociado_falla(inyectores_sucios_o_defectuosos, humo_negro_escape, secundario).
sintoma_asociado_falla(inyectores_sucios_o_defectuosos, consumo_excesivo_combustible, secundario).
sintoma_asociado_falla(inyectores_sucios_o_defectuosos, olor_gasolina, secundario).

sintoma_asociado_falla(carburador_desajustado_o_sucio, ralenti_inestable, primario).
sintoma_asociado_falla(carburador_desajustado_o_sucio, humo_negro_escape, primario).
sintoma_asociado_falla(carburador_desajustado_o_sucio, olor_gasolina, secundario).
sintoma_asociado_falla(carburador_desajustado_o_sucio, consumo_excesivo_combustible, secundario).
sintoma_asociado_falla(carburador_desajustado_o_sucio, tirones_al_acelerar, secundario).

sintoma_asociado_falla(fuga_empaque_culata, sobrecalentamiento_motor, primario).
sintoma_asociado_falla(fuga_empaque_culata, humo_blanco_escape, primario).
sintoma_asociado_falla(fuga_empaque_culata, fuga_refrigerante, primario).
sintoma_asociado_falla(fuga_empaque_culata, perdida_potencia, secundario).

sintoma_asociado_falla(termostato_bloqueado, sobrecalentamiento_motor, primario).
sintoma_asociado_falla(termostato_bloqueado, fuga_refrigerante, secundario).

sintoma_asociado_falla(desgaste_anillos_piston, humo_azul_escape, primario).
sintoma_asociado_falla(desgaste_anillos_piston, perdida_potencia, primario).
sintoma_asociado_falla(desgaste_anillos_piston, ruido_metalico_motor, secundario).

sintoma_asociado_falla(aire_sistema_frenos, pedal_freno_esponjoso, primario).
sintoma_asociado_falla(discos_freno_deformados, vibracion_al_frenar, primario).

sintoma_asociado_falla(sensor_maf_map_defectuoso, testigo_check_engine, primario).
sintoma_asociado_falla(sensor_maf_map_defectuoso, humo_negro_escape, secundario).
sintoma_asociado_falla(sensor_maf_map_defectuoso, consumo_excesivo_combustible, primario).
sintoma_asociado_falla(sensor_maf_map_defectuoso, ralenti_inestable, secundario).
sintoma_asociado_falla(sensor_maf_map_defectuoso, codigo_error_obd_sensor, primario).

sintoma_asociado_falla(sensor_posicion_ciguenal_ckp, motor_se_apaga_en_marcha, primario).
sintoma_asociado_falla(sensor_posicion_ciguenal_ckp, no_arranca, primario).
sintoma_asociado_falla(sensor_posicion_ciguenal_ckp, motor_arranque_gira_normal, secundario).
sintoma_asociado_falla(sensor_posicion_ciguenal_ckp, testigo_check_engine, secundario).
sintoma_asociado_falla(sensor_posicion_ciguenal_ckp, codigo_error_obd_sensor, secundario).

sintoma_asociado_falla(cuerpo_aceleracion_electronico_descalibrado, fallo_acelerador_electronico, primario).
sintoma_asociado_falla(cuerpo_aceleracion_electronico_descalibrado, ralenti_inestable, primario).
sintoma_asociado_falla(cuerpo_aceleracion_electronico_descalibrado, testigo_check_engine, secundario).
sintoma_asociado_falla(cuerpo_aceleracion_electronico_descalibrado, perdida_potencia, secundario).

sintoma_asociado_falla(falla_unidad_control_ecu, testigo_check_engine, primario).
sintoma_asociado_falla(falla_unidad_control_ecu, codigo_error_obd_sensor, primario).
sintoma_asociado_falla(falla_unidad_control_ecu, motor_se_apaga_en_marcha, secundario).
sintoma_asociado_falla(falla_unidad_control_ecu, no_arranca, secundario).

% ----------------------------------------------------------------------------
% 9. PRUEBAS DE VERIFICACION ADICIONALES (prueba_verificacion/2)
%    prueba_verificacion(IdFalla, TextoPrueba).
% ----------------------------------------------------------------------------

prueba_verificacion(falla_rele_arranque,
    'Intercambiar el rele de arranque por uno identico o medir continuidad en bobina y salida 87').
prueba_verificacion(falla_solenoide_arranque,
    'Medir llegada de 12V al terminal S del solenoide al accionar llave y verificar caida de tension').
prueba_verificacion(falla_circuito_control_arranque,
    'Verificar fusible de ignicion, interruptor de arranque, sensor de posicion P/N o embrague y cableado').
prueba_verificacion(bateria_descargada,
    'Realizar prueba de carga de bateria con analizador digital y revisar limpieza y apriete de bornes').
prueba_verificacion(alternador_defectuoso,
    'Medir voltaje en bornes con motor encendido (esperado 13.8V a 14.5V) y revisar tension de banda').
prueba_verificacion(motor_arranque_averiado,
    'Medir consumo de amperaje durante arranque y verificar giro libre del pinon bendix y carbones').
prueba_verificacion(bujias_o_bobinas_encendido_fallando,
    'Inspeccionar electrodos de bujias, resistencia de bobinas y verificar pulsos de chispa por cilindro').
prueba_verificacion(bomba_combustible_defectuosa,
    'Medir presion en riel de combustible con manometro y verificar fusible, rele y flujo de bomba').
prueba_verificacion(inyectores_sucios_o_defectuosos,
    'Ejecutar prueba de balance de inyectores en banco, verificar resistencia de bobinas y patron de rocio').
prueba_verificacion(carburador_desajustado_o_sucio,
    'Revisar nivel de flotador, limpieza de espreas internas y ajuste de tornillo de mezcla en ralenti').
prueba_verificacion(fuga_empaque_culata,
    'Realizar prueba quimica de gases de combustion en refrigerante y medir compresion entre cilindros').
prueba_verificacion(termostato_bloqueado,
    'Comprobar diferencia termica entre mangueras superior e inferior del radiador y activacion de ventilador').
prueba_verificacion(desgaste_anillos_piston,
    'Efectuar prueba de compresion seca y humeda en todos los cilindros y revisar consumo de aceite').
prueba_verificacion(aire_sistema_frenos,
    'Inspeccionar nivel de liquido en deposito, buscar fugas en lineas o mordazas y probar recorrido del pedal').
prueba_verificacion(discos_freno_deformados,
    'Medir alabeo axial de discos con reloj comparador y verificar espesor minimo y estado de pastillas').
prueba_verificacion(sensor_maf_map_defectuoso,
    'Monitorear flujo g/s o vacio kPa en datos en vivo OBD2 y revisar entradas de aire no medido').
prueba_verificacion(sensor_posicion_ciguenal_ckp,
    'Verificar senal de RPM en escaner durante arranque y medir resistencia o senal de pulso en sensor CKP').
prueba_verificacion(cuerpo_aceleracion_electronico_descalibrado,
    'Inspeccionar acumulacion de carbonilla en mariposa y leer valores de sensores TPS/APP en escaner').
prueba_verificacion(falla_unidad_control_ecu,
    'Verificar alimentaciones positivas, tierras de ECU, comunicacion en red CAN y continuidad de arnes').

% ----------------------------------------------------------------------------
% 10. ACCIONES CORRECTIVAS RECOMENDADAS (accion_correctiva/2)
%     accion_correctiva(IdFalla, TextoAccion).
% ----------------------------------------------------------------------------

accion_correctiva(falla_rele_arranque,
    'Sustituir el rele de arranque defectuoso y limpiar terminales de la caja de fusibles').
accion_correctiva(falla_solenoide_arranque,
    'Reemplazar el solenoide de arranque o reparar contactos internos de cobre y ajustar terminales').
accion_correctiva(falla_circuito_control_arranque,
    'Reparar linea interrumpida, reemplazar fusible o interruptor defectuoso y asegurar conectores').
accion_correctiva(bateria_descargada,
    'Recargar la bateria completamente o reemplazarla si falla la prueba de capacidad y limpiar bornes').
accion_correctiva(alternador_defectuoso,
    'Reparar o sustituir alternador y regulador, y tensar o reemplazar la correa de accesorios').
accion_correctiva(motor_arranque_averiado,
    'Desmontar el motor de arranque para sustituir carbones, bujes, bendix o unidad completa').
accion_correctiva(bujias_o_bobinas_encendido_fallando,
    'Reemplazar bujias desgastadas, sustituir bobinas defectuosas y calibrar apertura de electrodos').
accion_correctiva(bomba_combustible_defectuosa,
    'Sustituir bomba de combustible, reemplazar filtro tapado y verificar regulador de presion').
accion_correctiva(inyectores_sucios_o_defectuosos,
    'Realizar limpieza ultrasonica de inyectores, cambiar microfiltros o sustituir inyectores danados').
accion_correctiva(carburador_desajustado_o_sucio,
    'Desarmar y limpiar carburador con solvente especializado, cambiar empaques y calibrar mezcla').
accion_correctiva(fuga_empaque_culata,
    'Desmontar culata, rectificar planitud, reemplazar empaque de culata y renovar aceite y refrigerante').
accion_correctiva(termostato_bloqueado,
    'Reemplazar el termostato por uno de especificacion original y purgar aire del circuito refrigerante').
accion_correctiva(desgaste_anillos_piston,
    'Realizar ajuste mecanico de motor, pulido o rectificado de cilindros y reemplazo de anillos').
accion_correctiva(aire_sistema_frenos,
    'Corregir fugas detectadas, renovar liquido de frenos y purgar completamente las cuatro ruedas').
accion_correctiva(discos_freno_deformados,
    'Rectificar discos dentro de tolerancia o reemplazar discos y juego completo de pastillas de freno').
accion_correctiva(sensor_maf_map_defectuoso,
    'Limpiar sensor MAF con spray dielectrico especifico o sustituir sensor y sellar fugas de admision').
accion_correctiva(sensor_posicion_ciguenal_ckp,
    'Reemplazar sensor CKP defectuoso, limpiar rueda fonica y revisar aislamiento del conector').
accion_correctiva(cuerpo_aceleracion_electronico_descalibrado,
    'Limpiar garganta del cuerpo de aceleracion y ejecutar reaprendizaje electronico de ralenti con escaner').
accion_correctiva(falla_unidad_control_ecu,
    'Reparar lineas de alimentacion y tierra de arnes o reprogramar y sustituir la unidad ECU').
