#ifndef VALIDACIONES_H
#define VALIDACIONES_H
#include <stddef.h>
int leerTexto(const char *mensaje, char *destino, size_t capacidad);
int leerEntero(const char *mensaje, long minimo, long maximo, long *valor);
int convertirEntero(const char *texto, long minimo, long maximo, long *valor);
int identificadorValido(const char *texto);
#endif