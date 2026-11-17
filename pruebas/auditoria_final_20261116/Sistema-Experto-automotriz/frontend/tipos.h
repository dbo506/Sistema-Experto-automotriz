#ifndef TIPOS_H
#define TIPOS_H
#include <stddef.h>
#define MAX_SINTOMAS 20
#define MAX_RESULTADOS 20
#define TAM_TEXTO 160
typedef struct {
    char marca[64], modelo[64], combustible[32];
    int anio;
    long kilometraje;
} Vehiculo;
typedef struct { char id[64]; } Sintoma;
typedef struct {
    char diagnostico[TAM_TEXTO];
    char explicacion[512];
    char recomendacion[512];
} Resultado;
typedef struct {
    int tieneVehiculo;
    Vehiculo vehiculo;
    Sintoma sintomas[MAX_SINTOMAS];
    size_t cantidadSintomas;
    Resultado resultados[MAX_RESULTADOS];
    size_t cantidadResultados;
} Sesion;
#endif