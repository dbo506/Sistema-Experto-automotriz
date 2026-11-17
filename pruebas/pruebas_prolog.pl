
:- ensure_loaded('../backend/puente.pl').
:- ensure_loaded('../backend/consultas.pl').
:- use_module(library(plunit)).
:- begin_tests(zytron).
vehiculo(vehiculo('Toyota','Corolla',2015,100000,gasolina)).
arranque([no_arranca,luces_funcionan,motor_arranque_no_gira,voltaje_bateria_adecuado]).
test(cp08_diagnostico) :- vehiculo(V), diagnosticar(V,[pedal_freno_esponjoso],R),writeln(resultados_reales(R)),assertion(R=[resultado(_,_,_)|_]),validar_sesion(sesion(V,[pedal_freno_esponjoso],R)), assertion(hipotesis_diagnostica(V,[pedal_freno_esponjoso],aire_sistema_frenos,_,_)).
test(cp09_alternativos) :- vehiculo(V),arranque(S),findall(F,hipotesis_diagnostica(V,S,F,_,_),Fs),writeln(hipotesis_reales(Fs)),assertion(memberchk(falla_rele_arranque,Fs)),assertion(memberchk(falla_solenoide_arranque,Fs)),assertion(memberchk(falla_circuito_control_arranque,Fs)),assertion(\+memberchk(bateria_descargada,Fs)).
test(cp10_compuesta) :- vehiculo(V),arranque(S),findall(E,estado_subsistema_inferido(V,S,electrico,E),Es),writeln(estados_reales(Es)),assertion(memberchk(interrupcion_circuito_arranque_con_bateria_sana,Es)),assertion(\+estado_subsistema_inferido(V,[no_arranca,luces_funcionan,motor_arranque_no_gira],electrico,interrupcion_circuito_arranque_con_bateria_sana)).
test(cp11_listas) :- sintomas_validos([no_arranca,inventado,luces_tenues],R),sintomas_desconocidos_lista([no_arranca,raro,raro],D),writeln(validos(R)),writeln(desconocidos(D)),assertion(R==[no_arranca,luces_tenues]),assertion(D==[raro]),assertion(sintomas_validos([],[])).
test(cp12_recursion) :- eliminar_duplicados([a,b,a,c,b],R),contar_elementos([a,b,c],N),contar_elementos([],Z),writeln(recursion_real(R,N,Z)),assertion(R==[a,b,c]),assertion(N==3),assertion(Z==0).
test(cp13_backtracking) :- findall(F,fallas_por_sintoma(no_arranca,F),Fs),writeln(soluciones_reales(Fs)),sort(Fs,U),length(U,N),assertion(N>=3),assertion(memberchk(bateria_descargada,Fs)),assertion(memberchk(falla_rele_arranque,Fs)),assertion(\+fallas_por_sintoma(inventado,_)).
:- end_tests(zytron).
% Redireccion exclusiva del estado dinamico del proceso de pruebas.
% Se ejecutan los predicados originales, sin editar backend ni usar mocks.
almacen_pruebas :- retractall(persistencia_directorio_backend(_)),assertz(persistencia_directorio_backend('pruebas/almacen')).
sesion_prueba(sesion(V,[pedal_freno_esponjoso],R)) :- V=vehiculo('Toyota','Corolla',2015,100000,gasolina),diagnosticar(V,[pedal_freno_esponjoso],R).
guardar_prueba :- almacen_pruebas,sesion_prueba(S),guardar_sesion(cp14,S),writeln(guardado_real(S)).
recuperar_prueba :- almacen_pruebas,recuperar_sesion(cp14,S),sesion_prueba(E),writeln(recuperado_real(S)),S==E.
reporte_prueba :- sesion_prueba(S),generar_reporte('pruebas/reporte_cp15.txt',S),writeln(reporte_generado(S)).
