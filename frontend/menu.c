#include <stdio.h>
#include <string.h>
#include "menu.h"
#include "interfaz.h"
#include "validaciones.h"
#include "../integracion/conexion.h"

static void mostrarMenuPrincipal(void) {
    puts("\n"
         "==========================================================\n"
         "                          ZYTRON\n"
         "        SISTEMA EXPERTO DE DIAGNOSTICO AUTOMOTRIZ\n"
         "==========================================================\n"
         "\n");
    puts("  [1] Registrar vehiculo\n"
         "  [2] Seleccionar sintomas\n"
         "  [3] Ver informacion registrada\n"
         "  [4] Realizar diagnostico\n"
         "  [5] Guardar sesion\n"
         "  [6] Recuperar sesion\n"
         "  [7] Generar reporte\n\n"
         "  [0] Salir\n\n"
         "----------------------------------------------------------");
}

/* -1: regreso solicitado, 0: EOF, 1: recurso ingresado. */
static int solicitarRecurso(const char *mensaje, char *recurso, size_t capacidad) {
    puts("\n  Escriba 0 para cancelar.\n");
    if (!leerTexto(mensaje, recurso, capacidad)) return 0;
    return strcmp(recurso, "0") == 0 ? -1 : 1;
}

int ejecutarMenu(void) {
    Sesion sesion = {0};
    long opcion;
    int estado;
    char recurso[160];
    for (;;) {
        limpiarConsola();
        mostrarMenuPrincipal();
        if (!leerEntero("  Seleccione una opcion: ", 0, 7, &opcion) || opcion == 0) break;
        limpiarConsola();
        switch (opcion) {
            case 1:
                if (!registrarVehiculo(&sesion)) return 0;
                continue;
            case 2:
                if (!seleccionarSintomas(&sesion)) return 0;
                continue;
            case 3:
                mostrarResumen(&sesion);
                break;
            case 4:
                mostrarEncabezado("REALIZAR DIAGNOSTICO");
                if (!sesion.tieneVehiculo || !sesion.cantidadSintomas)
                    puts("  [AVISO] Registre un vehiculo y al menos un sintoma.");
                else {
                    puts("  Consultando el motor de diagnostico...\n");
                    if (ejecutarOperacion(CONSULTAR, &sesion, ""))
                        mostrarResultados(&sesion);
                }
                break;
            case 5:
                mostrarEncabezado("GUARDAR SESION");
                if (!sesion.tieneVehiculo) {
                    puts("  [AVISO] Registre primero un vehiculo."); break;
                }
                estado = solicitarRecurso("  Nombre o ruta de sesion: ", recurso, sizeof recurso);
                if (!estado) return 0;
                if (estado == -1) continue;
                ejecutarOperacion(GUARDAR, &sesion, recurso);
                break;
            case 6:
                mostrarEncabezado("RECUPERAR SESION");
                puts("  DATOS DE LA SESION\n"
                     "  ------------------------------------------------------\n\n"
                     "==========================================================\n"
                     "  [0] Volver al menu principal\n");
                if (!leerTexto("  Nombre o ruta de sesion: ", recurso, sizeof recurso)) return 0;
                if (strcmp(recurso, "0") == 0) continue;
                limpiarConsola();
                mostrarEncabezado("RECUPERAR SESION");
                puts("  RESULTADO DE LA RECUPERACION\n"
                     "  ------------------------------------------------------\n");
                ejecutarOperacion(RECUPERAR, &sesion, recurso);
                break;
            case 7:
                mostrarEncabezado("GENERAR REPORTE");
                mostrarResumen(&sesion);
                mostrarResultados(&sesion);
                if (!sesion.tieneVehiculo) {
                    puts("  [AVISO] Registre primero un vehiculo."); break;
                }
                estado = solicitarRecurso("  Ruta del reporte: ", recurso, sizeof recurso);
                if (!estado) return 0;
                if (estado == -1) continue;
                ejecutarOperacion(REPORTAR, &sesion, recurso);
                break;
        }
        if (!esperarVolver()) break;
    }
    puts("\n  Sesion finalizada. Hasta pronto.\n");
    return 0;
}