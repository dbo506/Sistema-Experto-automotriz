#ifndef CONEXION_H
#define CONEXION_H
#include "../frontend/tipos.h"
typedef enum { CONSULTAR, GUARDAR, RECUPERAR, REPORTAR } Operacion;
/* Devuelve 1 solo con respuesta valida y completa; nunca altera sesion al fallar. */
int ejecutarOperacion(Operacion operacion, Sesion *sesion, const char *recurso);
#endif