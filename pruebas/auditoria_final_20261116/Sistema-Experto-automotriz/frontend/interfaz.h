#ifndef INTERFAZ_H
#define INTERFAZ_H
#include "tipos.h"
/* Encabezado ASCII compartido por las pantallas de consola. */
void limpiarConsola(void);
int esperarVolver(void);
void mostrarEncabezado(const char *titulo);
int registrarVehiculo(Sesion *sesion);
int seleccionarSintomas(Sesion *sesion);
void mostrarResumen(const Sesion *sesion);
void mostrarResultados(const Sesion *sesion);
#endif