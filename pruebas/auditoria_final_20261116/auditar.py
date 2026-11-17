from pathlib import Path
import subprocess,shutil,hashlib,json,os,datetime,re
R=Path.cwd(); A=R/'pruebas/auditoria_final_20261116'; W=A/'Sistema-Experto-automotriz';W.mkdir()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
originals={str(p.relative_to(R)):digest(p) for folder in ['backend','frontend','integracion','pruebas'] for p in (R/folder).rglob('*') if p.is_file() and A not in p.parents}
originals['README.md']=digest(R/'README.md')
(A/'hashes_antes.json').write_text(json.dumps(originals,indent=2),encoding='utf-8')
for d in ['backend','frontend','integracion']:shutil.copytree(R/d,W/d)
shutil.copy2(R/'README.md',W/'README.md');(W/'pruebas').mkdir();shutil.copy2(R/'pruebas/ejecutar_pruebas.py',W/'pruebas/ejecutar_pruebas.py')
SWI=r'C:\Program Files\swipl\bin\swipl.exe'; env=os.environ.copy();env['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\swipl\bin;'+env['PATH']
results=[]
def run(name,cmd,inp=None,extra_env=None):
 e=env.copy();e.update(extra_env or {})
 try:
  p=subprocess.run(cmd,cwd=W,env=e,input=inp,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=55);code=p.returncode;out=p.stdout+p.stderr
 except Exception as ex:code=None;out=repr(ex)
 (A/(name+'.txt')).write_text('COMANDO: '+subprocess.list2cmdline(cmd)+'\nCWD: '+str(W)+'\nENTRADA:\n'+str(inp)+'\nCODIGO: '+str(code)+'\nSALIDA:\n'+out,encoding='utf-8')
 return code,out
def menu(name,lines,predicate,extra_env=None):
 inp='\n'.join(map(str,lines))+'\n'; c,o=run(name,[str(W/'auditoria.exe')],inp,extra_env);ok=c==0 and predicate(o)
 results.append({'caso':name,'estado':'APROBADO' if ok else 'NO VERIFICADA' if c is None else 'FALLIDO','codigo':c,'evidencia':name+'.txt'})
 return o
compile_cmd=['gcc','-std=c11','-Wall','-Wextra','-pedantic','-Werror','frontend/main.c','frontend/menu.c','frontend/interfaz.c','frontend/validaciones.c','integracion/conexion.c','-o','auditoria.exe']
c,o=run('compilacion_estricta',compile_cmd);assert c==0,o
c,o=run('15_pruebas',['python','pruebas/ejecutar_pruebas.py']);print('PRUEBAS EXISTENTES',c,o)
# Registro manual, correccion, cancelacion, duplicados y eliminacion mediante menu real.
reg=[1,'Toyota','Corolla',2015,100000,'gasolina',0]
add=lambda ss:[2]+sum(([1,s] for s in ss),[])+[0]
arr=['no_arranca','luces_funcionan','motor_arranque_no_gira','voltaje_bateria_adecuado']
menu('menu_01_02_03_validaciones', [99]+[1,'','Toyota','Corolla','abc',1800,2015,-1,100000,'gasolina',0]+[1,'Honda','Civic',2018,'volver']+[2,1,'NO VALIDO',1,99,1,'no_arranca',1,'no_arranca',1,'luces_tenues',2,1,0,3,0,0],lambda o:all(x in o for x in ['El campo es obligatorio.','[ERROR] Ingrese un entero','El sintoma ya esta seleccionado.','Sintoma eliminado.','Toyota','Corolla','100000','luces_tenues','Sesion finalizada.']) and 'Honda\n  Modelo' not in o)
# Guardar y reporte desde menu completo, varias hipotesis.
menu('menu_04_05_07_extremo_a_extremo',reg+add(arr)+[4,0,5,'auditoria_e2e',0,7,'reporte_auditoria_e2e.txt',0,0],lambda o:all(x in o for x in ['DIAGNOSTICO [1]','DIAGNOSTICO [2]','EXPLICACION','RECOMENDACION']) and (W/'backend/sesiones/auditoria_e2e.ses').is_file() and (W/'reporte_auditoria_e2e.txt').is_file())
saved=(W/'backend/sesiones/auditoria_e2e.ses').read_text(encoding='utf-8')
menu('menu_06_recuperacion_otro_proceso',[6,'auditoria_e2e',0,3,0,7,'reporte_recuperado.txt',0,0],lambda o:all(x in o for x in ['Toyota','Corolla','2015','100000','voltaje_bateria_adecuado']) and (W/'reporte_recuperado.txt').is_file() and (W/'reporte_recuperado.txt').read_bytes()==(W/'reporte_auditoria_e2e.txt').read_bytes())
menu('menu_sin_resultados',reg+add(['luces_funcionan'])+[4,0,3,0,0],lambda o:'No se encontraron' in o and 'No hay diagnosticos disponibles' in o and 'Sesion finalizada.' in o)
menu('menu_errores_backend',reg+add(['inventado'])+[4,0,3,0,6,'sesion_inexistente_auditoria',0,3,0,0],lambda o:'Sintomas desconocidos: [inventado]' in o and 'No se encontro la sesion solicitada.' in o and o.count('INFORMACION REGISTRADA')==2 and 'Sesion finalizada.' in o)
menu('menu_contradiccion',reg+add(['luces_funcionan','luces_tenues'])+[4,0,3,0,0],lambda o:'Sintomas incompatibles' in o and 'Sesion finalizada.' in o)
menu('menu_cancelaciones',reg+[1,0,2,0,3,0,4,0,5,0,6,0,7,0,3,0,0],lambda o:o.count('INFORMACION REGISTRADA')>=3 and 'Toyota' in o and 'Sesion finalizada.' in o)
# Reporte existente debe conservarse.
h=digest(W/'reporte_auditoria_e2e.txt')
menu('menu_reporte_no_sobrescribe',[6,'auditoria_e2e',0,7,'reporte_auditoria_e2e.txt',0,0],lambda o:'no se sobrescribio' in o and digest(W/'reporte_auditoria_e2e.txt')==h)
# SWI ausente: el ejecutable C funciona y conserva la sesion.
menu('menu_motor_no_disponible',reg+add(['pedal_freno_esponjoso'])+[4,0,3,0,0],lambda o:'No se pudo iniciar el servicio' in o and 'Toyota' in o and 'Sesion finalizada.' in o,{'PATH':r'C:\Windows\System32;C:\Windows'})
# EOF no bloquea.
menu('menu_fin_entrada',[1,'Toyota'],lambda o:'Sesion finalizada.' not in o)
# Conteo sintactico con lector Prolog: excluye comentarios/directivas y hechos repetidos.
source=r'''
:- use_module(library(http/json)).
terms(S,Ts) :- read_term(S,T,[]),(T==end_of_file -> Ts=[] ; Ts=[T|R],terms(S,R)).
read_source(F,Ts) :- setup_call_cleanup(open(F,read,S,[encoding(utf8)]),terms(S,Ts),close(S)).
rule((H:-B),H,B).
fact(T) :- T\=(_:-_),T\=(:-_),T\=(_-->_),ground(T).
pi(H,P) :- callable(H),functor(H,N,A),format(atom(P),'~w/~d',[N,A]).
stats(F,D) :- read_source(F,Ts),findall(T,(member(T,Ts),fact(T)),Fs),sort(Fs,UF),length(UF,NF),findall(T,(member(T,Ts),rule(T,_,_)),Rs),sort(Rs,UR),length(UR,NR),findall(P,(member(T,Ts),(rule(T,H,_);fact(T),H=T),pi(H,P)),Ps),sort(Ps,UP),length(UP,NP),findall(P,(member(T,Ts),rule(T,H,B),pi(H,P),sub_term(Sub,B),nonvar(Sub),callable(Sub),pi(Sub,P)),Rec),sort(Rec,URec),D=_{archivo:F,hechos_ground_unicos:NF,clausulas_regla_unicas:NR,predicados:NP,indicadores:UP,recursivos_directos:URec}.
main :- expand_file_name('backend/*.pl',Files),maplist(stats,Files,Ds),json_write_dict(current_output,Ds,[width(0)]),nl.
'''
(W/'conteo_auditoria.pl').write_text(source,encoding='utf-8')
c,statsout=run('conteos_prolog',[SWI,'-q','-s','conteo_auditoria.pl','-g','main','-t','halt']);assert c==0,statsout
stats=json.loads(statsout);(A/'conteos.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
# Carga de todos los modulos de produccion.
run('carga_modulos',[SWI,'-q','-g',"consult('backend/puente.pl'),consult('backend/consultas.pl'),halt"])
queries=["sintomas_por_subsistema(electrico,R)","cantidad_sintomas_subsistema(electrico,R)","findall(F,fallas_por_sintoma(no_arranca,F),R)","findall(S,sintomas_por_falla(bateria_descargada,S),R)","sintomas_validos([no_arranca,inventado],R)","sintomas_desconocidos_lista([no_arranca,raro,raro],R)","findall(F,fallas_por_severidad(alta,F),R)","findall(P,pruebas_por_falla(bateria_descargada,P),R)","findall(C,componentes_por_subsistema(electrico,C),R)","findall(Mo,perfiles_por_combustible(diesel,_,Mo,_,_),R)"]
for i,q in enumerate(queries,1):run(f'consulta_{i:02}',[SWI,'-q','-s','backend/consultas.pl','-g',f'({q},writeln(R)->halt(0);halt(1))'])
# Cinco conclusiones explicadas reales y diferentes, verificadas no vacias.
scenarios=[['pedal_freno_esponjoso'],['vibracion_al_frenar'],arr,['testigo_bateria_encendido'],['sobrecalentamiento_motor','fuga_refrigerante']]
for i,ss in enumerate(scenarios,1):
 goal="diagnosticar(vehiculo('Toyota','Corolla',2015,100000,gasolina),["+','.join(ss)+"],R),R=[_|_],forall(member(resultado(D,E,C),R),(atom_length(D,LD),LD>0,atom_length(E,LE),LE>0,atom_length(C,LC),LC>0)),writeln(R)"
 run(f'explicacion_{i:02}',[SWI,'-q','-s','backend/puente.pl','-g',f'({goal}->halt(0);halt(1))'])
# Contrasta catalogo real C con Prolog.
c,o=run('catalogo_prolog',[SWI,'-q','-s','backend/consultas.pl','-g','catalogo_sintomas(R),write_canonical(R),nl,halt'])
cids=re.findall(r'\{"([a-z_]+)", "(?:ELECTRICO|ELECTRONICO|MECANICO)"', (R/'frontend/interfaz.c').read_text(encoding='utf-8'))
(A/'comparacion_catalogo.txt').write_text('C: '+repr(cids)+'\nProlog: '+o+'\n',encoding='utf-8')
changed=[p for p,h in originals.items() if not (R/p).is_file() or digest(R/p)!=h]
(A/'integridad_originales.json').write_text(json.dumps({'archivos_verificados':len(originals),'modificados':changed},indent=2),encoding='utf-8')
(A/'resultados_menu.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
(A/'documentos_encontrados.txt').write_text('\n'.join(str(p.relative_to(R)) for d in ['documentacion','datos'] for p in (R/d).rglob('*') if p.is_file()),encoding='utf-8')
print('MENU',json.dumps(results,ensure_ascii=False));print('INTEGRIDAD',len(originals),changed);print('CONTEOS',[(s['archivo'],s['hechos_ground_unicos'],s['clausulas_regla_unicas'],s['predicados'],s['recursivos_directos']) for s in stats])
