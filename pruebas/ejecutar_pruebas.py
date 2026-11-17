from pathlib import Path
import subprocess, os, json, datetime, hashlib
ROOT=Path.cwd(); P=ROOT/'pruebas'; P.mkdir(exist_ok=True)
assert ROOT.name=='Sistema-Experto-automotriz'
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='main'
SWI=r'C:\Program Files\swipl\bin\swipl.exe'
def write(name,text): (P/name).write_text(text,encoding='utf-8')
write('pruebas_frontend.c',r'''
#include "../frontend/interfaz.h"
#include "../frontend/validaciones.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
 Sesion s={0},antes; int n=atoi(argv[1]),ok=0; long v;
 if(argc!=3 || !freopen(argv[2],"r",stdin)) return 2;
 s.tieneVehiculo=1; strcpy(s.vehiculo.marca,"Toyota"); strcpy(s.vehiculo.modelo,"Corolla");
 strcpy(s.vehiculo.combustible,"gasolina"); s.vehiculo.anio=2015;s.vehiculo.kilometraje=100000;
 if(n==1){ memset(&s,0,sizeof s); registrarVehiculo(&s);ok=s.tieneVehiculo && !strcmp(s.vehiculo.marca,"Toyota") && !strcmp(s.vehiculo.modelo,"Corolla") && s.vehiculo.anio==2015 && s.vehiculo.kilometraje==100000 && !strcmp(s.vehiculo.combustible,"gasolina"); }
 if(n==2){registrarVehiculo(&s);ok=s.vehiculo.anio==2015 && s.vehiculo.kilometraje==100000 && !convertirEntero("abc",0,100,&v) && !convertirEntero("-1",0,100,&v);}
 if(n==3){strcpy(s.sintomas[0].id,"no_arranca");s.cantidadSintomas=1;s.cantidadResultados=1;strcpy(s.resultados[0].diagnostico,"previo");antes=s;registrarVehiculo(&s);ok=memcmp(&antes,&s,sizeof s)==0;}
 if(n>=4 && n<=6){seleccionarSintomas(&s);ok=(n==6 ? s.cantidadSintomas==1 && !strcmp(s.sintomas[0].id,"luces_tenues") : s.cantidadSintomas==1 && !strcmp(s.sintomas[0].id,"no_arranca"));}
 if(n==7){strcpy(s.sintomas[0].id,"no_arranca");s.cantidadSintomas=1;antes=s;mostrarResumen(&s);ok=memcmp(&antes,&s,sizeof s)==0;}
 printf("\nESTADO_REAL vehiculo=%d marca=%s modelo=%s anio=%d km=%ld combustible=%s sintomas=%zu resultados=%zu\n",s.tieneVehiculo,s.vehiculo.marca,s.vehiculo.modelo,s.vehiculo.anio,s.vehiculo.kilometraje,s.vehiculo.combustible,s.cantidadSintomas,s.cantidadResultados);
 for(size_t i=0;i<s.cantidadSintomas;i++) printf("SINTOMA_REAL %s\n",s.sintomas[i].id);
 printf("CP%02d %s\n",n,ok?"APROBADO":"FALLIDO");return ok?0:1;
}
''')
write('pruebas_prolog.pl',r'''
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
''')
rows=[]; logs=[]
def run(cmd,inp=None):
 try:
  r=subprocess.run(cmd,input=inp,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=40)
  return r.returncode,r.stdout+r.stderr
 except Exception as e:return None,repr(e)
def record(n,name,func,entrada,expected,cmd,check=None,inp=None):
 code,out=run(cmd,inp); ok=code==0 and (check(out) if check else True)
 status='NO EJECUTADA' if code is None else ('APROBADO' if ok else 'FALLIDO')
 ev=f'cp{n:02d}_salida.txt'; write(ev,f'COMANDO: {subprocess.list2cmdline(cmd)}\nENTRADA: {entrada}\nCODIGO: {code}\n\n{out}')
 rows.append(dict(numero=n,nombre=name,funcionalidad=func,entrada=entrada,esperado=expected,obtenido=f'Codigo de proceso: {code}. '+out[-1800:],estado=status,evidencia='pruebas/'+ev))
 logs.append((ev,(P/ev).read_text(encoding='utf-8')))
 return ok
for cmd in [['gcc','--version'],[SWI,'--version'],['gcc','-std=c11','-Wall','-Wextra','-pedantic','frontend/main.c','frontend/menu.c','frontend/interfaz.c','frontend/validaciones.c','integracion/conexion.c','-o','pruebas/zytron.exe'],['gcc','-std=c11','-Wall','-Wextra','-pedantic','pruebas/pruebas_frontend.c','frontend/interfaz.c','frontend/validaciones.c','-o','pruebas/pruebas_frontend.exe']]:
 code,out=run(cmd); logs.append(('PREPARACION',f'{subprocess.list2cmdline(cmd)}\nCodigo: {code}\n{out}'))
inputs=['Toyota\nCorolla\n2015\n100000\ngasolina\n0\n','Toyota\nCorolla\nabc\n1800\n2015\n-1\n100000\ngasolina\n0\n','Honda\nCivic\n2018\nvolver\n','1\nno_arranca\n0\n','1\nno_arranca\n1\nno_arranca\n0\n','1\nno_arranca\n1\nluces_tenues\n2\n1\n0\n','']
names=['Registro correcto de vehiculo','Rechazo y correccion de datos incorrectos','Cancelacion sin perder la sesion','Registro de sintoma','Control de sintoma duplicado','Eliminacion de sintoma','Visualizacion de informacion']
expected=['Toyota Corolla 2015, 100000 km, gasolina; tieneVehiculo=1.','Rechazar abc y 1800 como anio, -1 como km; aceptar 2015 y 100000.','Conservar byte a byte vehiculo, sintoma y resultado previos al cancelar en kilometraje.','Lista exactamente [no_arranca].','Aviso de duplicado; lista exactamente [no_arranca].','Eliminar no_arranca y conservar luces_tenues como unico sintoma.','Mostrar Toyota, Corolla, 2015, 100000, gasolina y no_arranca; sesion intacta.']
for n in range(1,8):
 f=f'cp{n:02d}_entrada.txt';write(f,inputs[n-1]); check=None
 if n==2:check=lambda o:'[ERROR] Ingrese un entero' in o
 if n==5:check=lambda o:'El sintoma ya esta seleccionado.' in o
 if n==7:check=lambda o:all(x in o for x in ['INFORMACION REGISTRADA','Toyota','Corolla','100000','no_arranca','gasolina'])
 record(n,names[n-1],['registrarVehiculo/validaciones C']*3+['seleccionarSintomas C']*3+['mostrarResumen C'] if False else ('registrarVehiculo C' if n<=3 else 'seleccionarSintomas C' if n<=6 else 'mostrarResumen C'),repr(inputs[n-1])+'; sesion inicial Toyota Corolla 2015, 100000 km, gasolina (excepto CP01 vacia). CP03: no_arranca y resultado previo.',expected[n-1],['pruebas/pruebas_frontend.exe',str(n),'pruebas/'+f],check)
plist=[('cp08_diagnostico','Diagnostico con sintomas validos','diagnosticar/3 e hipotesis_diagnostica/5','Toyota Corolla 2015 gasolina; [pedal_freno_esponjoso]','Resultados validos y presencia de aire_sistema_frenos.'),('cp09_alternativos','Diagnosticos alternativos','hipotesis_diagnostica/5','[no_arranca,luces_funcionan,motor_arranque_no_gira,voltaje_bateria_adecuado]','Rele, solenoide y circuito de control; excluir bateria descargada.'),('cp10_compuesta','Inferencia compuesta','estado_subsistema_inferido/4','Lista CP09; control negativo sin voltaje_bateria_adecuado','Interrupcion de circuito con bateria sana solo con evidencia completa.'),('cp11_listas','Consultas con listas','sintomas_validos/2, sintomas_desconocidos_lista/2','[no_arranca,inventado,luces_tenues]; [no_arranca,raro,raro]; []','[no_arranca,luces_tenues]; [raro]; [].'),('cp12_recursion','Reglas recursivas','eliminar_duplicados/2, contar_elementos/2','[a,b,a,c,b]; [a,b,c]; []','[a,b,c]; 3; 0.'),('cp13_backtracking','Soluciones mediante backtracking','findall/3 sobre fallas_por_sintoma/2','no_arranca; control negativo inventado','Al menos tres fallas distintas, incluyendo bateria y rele; inventado sin soluciones.')]
observaciones=[
"diagnosticar(vehiculo('Toyota','Corolla',2015,100000,gasolina),[pedal_freno_esponjoso],R),writeln(resultados_reales(R))",
"findall(F,hipotesis_diagnostica(vehiculo('Toyota','Corolla',2015,100000,gasolina),[no_arranca,luces_funcionan,motor_arranque_no_gira,voltaje_bateria_adecuado],F,_,_),R),writeln(hipotesis_reales(R))",
"findall(E,estado_subsistema_inferido(vehiculo('Toyota','Corolla',2015,100000,gasolina),[no_arranca,luces_funcionan,motor_arranque_no_gira,voltaje_bateria_adecuado],electrico,E),R),writeln(estados_reales(R))",
"sintomas_validos([no_arranca,inventado,luces_tenues],R),sintomas_desconocidos_lista([no_arranca,raro,raro],D),writeln(validos(R)),writeln(desconocidos(D))",
"eliminar_duplicados([a,b,a,c,b],R),contar_elementos([a,b,c],N),contar_elementos([],Z),writeln(recursion_real(R,N,Z))",
"findall(F,fallas_por_sintoma(no_arranca,F),R),writeln(soluciones_reales(R))"]
for n,(test,name,func,inp,exp) in enumerate(plist,8):
 record(n,name,func,inp,exp,[SWI,'-q','-s','pruebas/pruebas_prolog.pl','-g',f'({observaciones[n-8]},run_tests(zytron:{test})->halt(0);halt(1))'])
(P/'almacen').mkdir(exist_ok=True)
a,oa=run([SWI,'-q','-s','pruebas/pruebas_prolog.pl','-g','(guardar_prueba->halt(0);halt(1))']);write('cp14_guardado.txt',f'Codigo {a}\n{oa}')
record(14,'Guardar y recuperar entre ejecuciones','guardar_sesion/2 y recuperar_sesion/2 originales; almacen dinamico aislado','Sesion real diagnosticada CP08; recurso cp14; dos procesos SWI independientes.','Crear pruebas/almacen/sesiones/cp14.ses y recuperar un termino exactamente igual en otro proceso.',[SWI,'-q','-s','pruebas/pruebas_prolog.pl','-g','(recuperar_prueba->halt(0);halt(1))'],lambda o:a==0 and (P/'almacen/sesiones/cp14.ses').is_file())
if (P/'reporte_cp15.txt').exists():
 (P/'reporte_cp15.txt').rename(P/('reporte_cp15_anterior_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')+'.txt'))
record(15,'Generar y verificar reporte','generar_reporte/2','Sesion diagnosticada CP08; ruta pruebas/reporte_cp15.txt','Archivo UTF-8 con vehiculo, sintoma, diagnostico, explicacion, recomendacion y cierre.',[SWI,'-q','-s','pruebas/pruebas_prolog.pl','-g','(reporte_prueba->halt(0);halt(1))'],lambda o:(P/'reporte_cp15.txt').is_file() and all(t in (P/'reporte_cp15.txt').read_text(encoding='utf-8') for t in ['Toyota','Corolla','2015','100000','gasolina','pedal_freno_esponjoso','Resultado 1','Fin del reporte.']))
# Verifica el contenido concreto producido, conservandolo completo como evidencia.
if (P/'reporte_cp15.txt').exists():logs.append(('REPORTE CP15',(P/'reporte_cp15.txt').read_text(encoding='utf-8')))
logs.append(('GUARDADO CP14',(P/'cp14_guardado.txt').read_text(encoding='utf-8')))
counts={s:sum(r['estado']==s for r in rows) for s in ['APROBADO','FALLIDO','NO EJECUTADA']}
header='ZYTRON - 15 CASOS DE PRUEBA\nFecha: '+datetime.datetime.now().astimezone().isoformat()+'\nRepositorio: '+str(ROOT)+'\nRama: main\n\nAlcance: CP01-07 ejecutan funciones reales del frontend mediante un arnes C y stdin redirigido; no simulan clics ni el menu completo. Se compilo tambien la aplicacion completa con integracion/conexion.c. CP08-15 ejecutan predicados originales; no se afirma cobertura extremo a extremo del puente C-Prolog. CP14 cambia solamente persistencia_directorio_backend/1 en memoria del proceso para no escribir en backend. CP15 conserva el reporte generado. Las entradas y salidas completas estan en los archivos individuales.\nComando de reproduccion desde la raiz: python pruebas/ejecutar_pruebas.py\nReproduccion: el ejecutor conserva un reporte anterior con nombre fechado antes de repetir CP15; el sistema original rechaza sobrescritura.\n\n'
body=''
for r in rows:
 body+=f"CASO {r['numero']:02d}: {r['nombre']}\nFuncionalidad evaluada: {r['funcionalidad']}\nDatos de entrada: {r['entrada']}\nResultado esperado: {r['esperado']}\nResultado realmente obtenido:\n{r['obtenido']}\nEstado: {r['estado']}\nEvidencia: {r['evidencia']}\nVer tambien: pruebas/pruebas_frontend.c o pruebas/pruebas_prolog.pl; CP14: pruebas/cp14_guardado.txt y pruebas/almacen/sesiones/cp14.ses; CP15: pruebas/reporte_cp15.txt.\n\n"
summary=f'Preparados: {len(rows)}; ejecutados: {len(rows)-counts["NO EJECUTADA"]}; aprobados: {counts["APROBADO"]}; fallidos: {counts["FALLIDO"]}; no ejecutados: {counts["NO EJECUTADA"]}.\n'
write('casos_prueba.txt',header+summary+'\n'+body)
write('evidencias_pruebas.txt',header+summary+'\n'+'\n\n'.join('=== '+name+' ===\n'+out for name,out in logs))
write('resultados.json',json.dumps(rows,ensure_ascii=False,indent=2))
print(summary)
