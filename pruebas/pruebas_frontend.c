
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
