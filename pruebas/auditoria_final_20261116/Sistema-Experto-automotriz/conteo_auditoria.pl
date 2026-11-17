
:- use_module(library(http/json)).
terms(S,Ts) :- read_term(S,T,[]),(T==end_of_file -> Ts=[] ; Ts=[T|R],terms(S,R)).
read_source(F,Ts) :- setup_call_cleanup(open(F,read,S,[encoding(utf8)]),terms(S,Ts),close(S)).
rule((H:-B),H,B).
fact(T) :- T\=(_:-_),T\=(:-_),T\=(_-->_),ground(T).
pi(H,P) :- callable(H),functor(H,N,A),format(atom(P),'~w/~d',[N,A]).
stats(F,D) :- read_source(F,Ts),findall(T,(member(T,Ts),fact(T)),Fs),sort(Fs,UF),length(UF,NF),findall(T,(member(T,Ts),rule(T,_,_)),Rs),sort(Rs,UR),length(UR,NR),findall(P,(member(T,Ts),(rule(T,H,_);fact(T),H=T),pi(H,P)),Ps),sort(Ps,UP),length(UP,NP),findall(P,(member(T,Ts),rule(T,H,B),pi(H,P),sub_term(Sub,B),nonvar(Sub),callable(Sub),pi(Sub,P)),Rec),sort(Rec,URec),D=_{archivo:F,hechos_ground_unicos:NF,clausulas_regla_unicas:NR,predicados:NP,indicadores:UP,recursivos_directos:URec}.
main :- expand_file_name('backend/*.pl',Files),maplist(stats,Files,Ds),json_write_dict(current_output,Ds,[width(0)]),nl.
