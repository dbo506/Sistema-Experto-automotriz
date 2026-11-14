#include "interfaz.h"
#include "validaciones.h"
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <time.h>
#include <stdlib.h>

void limpiarConsola(void) {
    fflush(stdout);
#ifdef _WIN32
    if (system("cls") != 0)
        puts("\n  [AVISO] No se pudo limpiar la consola.\n");
#else
    if (system("clear") != 0)
        puts("\n  [AVISO] No se pudo limpiar la consola.\n");
#endif
}

int esperarVolver(void) {
    long opcion;
    puts("\n==========================================================\n"
         "  [0] Volver al menu principal\n");
    return leerEntero("  Seleccione una opcion: ", 0, 0, &opcion);
}

/* -1: cancelacion, 0: fin de entrada, 1: dato completo. */
static int leerCampo(const char *mensaje, char *destino, size_t capacidad) {
    if (!leerTexto(mensaje, destino, capacidad)) return 0;
    return strcmp(destino, "0") == 0 ? -1 : 1;
}

static int leerNumeroCancelable(const char *mensaje, long minimo,
                                long maximo, int permiteCero, long *valor) {
    char entrada[64];
    while (leerTexto(mensaje, entrada, sizeof entrada)) {
        if (strcmp(entrada, "volver") == 0 ||
            (!permiteCero && strcmp(entrada, "0") == 0)) return -1;
        if (convertirEntero(entrada, minimo, maximo, valor)) return 1;
        printf("  [ERROR] Ingrese un entero entre %ld y %ld.\n", minimo, maximo);
    }
    return 0;
}

void mostrarEncabezado(const char *titulo) {
    size_t longitud = strlen(titulo);
    int margen = longitud < 58 ? (int)((58 - longitud) / 2) : 2;
    printf("\n==========================================================\n"
           "%*s%s\n"
           "==========================================================\n\n",
           margen, "", titulo);
}

/* Ajusta los parrafos por palabras sin cortar los bytes de un caracter. */
static void mostrarParrafo(const char *texto) {
    size_t columna = 4;
    fputs("    ", stdout);
    while (*texto) {
        size_t longitud = strcspn(texto, " \t\r\n");
        if (!longitud) { texto++; continue; }
        if (columna > 4 && columna + 1 + longitud > 58) {
            fputs("\n    ", stdout);
            columna = 4;
        } else if (columna > 4) {
            fputc(' ', stdout);
            columna++;
        }
        fwrite(texto, 1, longitud, stdout);
        columna += longitud;
        texto += longitud;
    }
    fputc('\n', stdout);
}

int registrarVehiculo(Sesion *sesion) {
    Vehiculo nuevo = {0};
    long numero;
    int estado;
    time_t ahora = time(NULL);
    struct tm *fecha = localtime(&ahora);
    int maxAnio = fecha ? fecha->tm_year + 1901 : 2100;
    mostrarEncabezado("REGISTRO DE VEHICULO");
    puts("  [0] Volver al menu principal sin guardar cambios\n\n"
         "  Todos los campos son obligatorios.\n"
         "  En kilometraje: 0 es valido; escriba volver para cancelar.\n");
    estado = leerCampo("  Marca        : ", nuevo.marca, sizeof nuevo.marca);
    if (estado != 1) return estado == -1;
    estado = leerCampo("  Modelo       : ", nuevo.modelo, sizeof nuevo.modelo);
    if (estado != 1) return estado == -1;
    estado = leerNumeroCancelable("  Anio         : ", 1886, maxAnio, 0, &numero);
    if (estado != 1) return estado == -1;
    nuevo.anio = (int)numero;
    estado = leerNumeroCancelable("  Kilometraje (volver: cancelar): ", 0, LONG_MAX, 1,
                                 &nuevo.kilometraje);
    if (estado != 1) return estado == -1;
    estado = leerCampo("  Combustible  : ", nuevo.combustible, sizeof nuevo.combustible);
    if (estado != 1) return estado == -1;
    sesion->vehiculo = nuevo;
    sesion->tieneVehiculo = 1;
    sesion->cantidadResultados = 0;
    puts("\n  [OK] Vehiculo registrado correctamente.\n"
         "  [INFO] Los resultados anteriores se invalidaron.");
    return esperarVolver();
}
int seleccionarSintomas(Sesion *sesion) {
    long opcion, indice;
    char id[64];
    const char *aviso = NULL;
    size_t i;
    for (;;) {
        limpiarConsola();
        mostrarEncabezado("SELECCION DE SINTOMAS");
        if (aviso) { puts(aviso); aviso = NULL; }
        printf("  Sintomas seleccionados: %zu / %d\n\n",
               sesion->cantidadSintomas, MAX_SINTOMAS);
        if (!sesion->cantidadSintomas) puts("  Aun no hay sintomas seleccionados.");
        for (i = 0; i < sesion->cantidadSintomas; i++)
            printf("  [%2zu] %s\n", i + 1, sesion->sintomas[i].id);
        puts("\n----------------------------------------------------------\n"
             "  [1] Agregar sintoma\n"
             "  [2] Quitar sintoma\n\n"
             "  [0] Volver al menu principal\n");
        if (!leerEntero("  Seleccione una opcion: ", 0, 2, &opcion)) return 0;
        if (!opcion) return 1;
        limpiarConsola();
        puts("  [0] Volver al menu principal\n");
        if (opcion == 1) {
            if (sesion->cantidadSintomas == MAX_SINTOMAS) {
                aviso = "\n  [AVISO] Limite de sintomas alcanzado.\n"; continue;
            }
            puts("\n  Ingrese un identificador del catalogo de sintomas.\n"
                 "  Use a-z, 0-9 o _; debe comenzar con una letra minuscula.\n");
            if (!leerTexto("  Identificador: ", id, sizeof id)) return 0;
            if (strcmp(id, "0") == 0) return 1;
            if (!identificadorValido(id)) {
                aviso = "\n  [ERROR] Identificador invalido; debe iniciar con a-z.\n"; continue;
            }
            for (i = 0; i < sesion->cantidadSintomas; i++)
                if (strcmp(id, sesion->sintomas[i].id) == 0) break;
            if (i < sesion->cantidadSintomas) {
                aviso = "\n  [AVISO] El sintoma ya esta seleccionado.\n"; continue;
            }
            strcpy(sesion->sintomas[sesion->cantidadSintomas++].id, id);
            aviso = "\n  [OK] Sintoma agregado.\n";
        } else {
            if (!sesion->cantidadSintomas) {
                aviso = "\n  [AVISO] No hay sintomas para quitar.\n"; continue;
            }
            if (!leerEntero("  Numero del sintoma que desea quitar (0: volver): ", 0,
                            (long)sesion->cantidadSintomas, &indice)) return 0;
            if (!indice) return 1;
            for (i = (size_t)indice; i < sesion->cantidadSintomas; i++)
                sesion->sintomas[i - 1] = sesion->sintomas[i];
            sesion->cantidadSintomas--;
            aviso = "\n  [OK] Sintoma eliminado.\n";
        }
        sesion->cantidadResultados = 0;
    }
}

void mostrarResumen(const Sesion *sesion) {
    size_t i;
    mostrarEncabezado("INFORMACION REGISTRADA");
    puts("  VEHICULO\n  ------------------------------------------------------");
    if (sesion->tieneVehiculo)
        printf("  Marca        : %s\n"
               "  Modelo       : %s\n"
               "  Anio         : %d\n"
               "  Kilometraje  : %ld km\n"
               "  Combustible  : %s\n",
               sesion->vehiculo.marca, sesion->vehiculo.modelo, sesion->vehiculo.anio,
               sesion->vehiculo.kilometraje, sesion->vehiculo.combustible);
    else puts("  [INFO] No hay vehiculo registrado.");
    printf("\n  SINTOMAS SELECCIONADOS (%zu)\n  ------------------------------------------------------\n", sesion->cantidadSintomas);
    if (!sesion->cantidadSintomas) puts("  [INFO] No hay sintomas seleccionados.");
    for (i = 0; i < sesion->cantidadSintomas; i++)
        printf("  [%2zu] %s\n", i + 1, sesion->sintomas[i].id);
}

void mostrarResultados(const Sesion *sesion) {
    size_t i;
    mostrarEncabezado("RESULTADOS DEL DIAGNOSTICO");
    if (!sesion->cantidadResultados)
        puts("  [INFO] No hay diagnosticos disponibles en la sesion.");
    for (i = 0; i < sesion->cantidadResultados; i++) {
        if (i) puts("\n----------------------------------------------------------");
        printf("  DIAGNOSTICO [%zu]\n\n", i + 1);
        mostrarParrafo(sesion->resultados[i].diagnostico);
        puts("\n  EXPLICACION\n");
        mostrarParrafo(sesion->resultados[i].explicacion);
        puts("\n  RECOMENDACION\n");
        mostrarParrafo(sesion->resultados[i].recomendacion);
    }
}