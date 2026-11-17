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

typedef struct {
    const char *id;
    const char *subsistema;
    const char *descripcion;
} SintomaCatalogo;

static const SintomaCatalogo CATALOGO_SINTOMAS[] = {
    {"no_arranca", "ELECTRICO", "El motor no logra ponerse en marcha"},
    {"luces_funcionan", "ELECTRICO", "Faros y luces mantienen intensidad normal"},
    {"luces_tenues", "ELECTRICO", "Luces debiles o parpadean al arrancar"},
    {"luces_no_encienden", "ELECTRICO", "Ausencia total de iluminacion"},
    {"motor_arranque_no_gira", "ELECTRICO", "Motor de arranque inmovil al girar llave"},
    {"motor_arranque_gira_lento", "ELECTRICO", "Motor de arranque gira lento y sin fuerza"},
    {"motor_arranque_gira_normal", "ELECTRICO", "Arranque gira normal pero no enciende"},
    {"voltaje_bateria_adecuado", "ELECTRICO", "Voltaje de bateria en reposo >= 12.4V"},
    {"voltaje_bateria_bajo", "ELECTRICO", "Voltaje de bateria menor a 12.0V"},
    {"chasquido_al_girar_llave", "ELECTRICO", "Clic o chasquido al intentar arrancar"},
    {"testigo_bateria_encendido", "ELECTRICO", "Testigo de bateria encendido en tablero"},
    {"testigo_check_engine", "ELECTRONICO", "Testigo Check Engine encendido"},
    {"codigo_error_obd_sensor", "ELECTRONICO", "Escaner OBD registra falla de sensor"},
    {"fallo_acelerador_electronico", "ELECTRONICO", "Respuesta nula o tardia del acelerador"},
    {"motor_se_apaga_en_marcha", "ELECTRONICO", "El motor se apaga en circulacion o ralenti"},
    {"ralenti_inestable", "MECANICO", "Oscilaciones o vibracion de RPM en ralenti"},
    {"perdida_potencia", "MECANICO", "Falta de fuerza y aceleracion deficiente"},
    {"tirones_al_acelerar", "MECANICO", "Sacudidas o cortes al acelerar"},
    {"consumo_excesivo_combustible", "MECANICO", "Aumento notable en gasto de combustible"},
    {"olor_gasolina", "MECANICO", "Olor fuerte a combustible sin quemar"},
    {"humo_negro_escape", "MECANICO", "Humo oscuro denso por escape"},
    {"humo_azul_escape", "MECANICO", "Humo azulado por quema de aceite"},
    {"humo_blanco_escape", "MECANICO", "Humo blanco espeso y persistente en escape"},
    {"sobrecalentamiento_motor", "MECANICO", "Temperatura en zona roja o ebullicion"},
    {"fuga_refrigerante", "MECANICO", "Perdida o descenso continuo de refrigerante"},
    {"ruido_metalico_motor", "MECANICO", "Golpeteo o sonido metalico en motor"},
    {"pedal_freno_esponjoso", "MECANICO", "Pedal de freno blando o se hunde"},
    {"vibracion_al_frenar", "MECANICO", "Pulsacion en pedal o vibracion al frenar"}
};

#define TOTAL_CATALOGO_SINTOMAS (sizeof CATALOGO_SINTOMAS / sizeof CATALOGO_SINTOMAS[0])

static int estaSeleccionado(const Sesion *sesion, const char *id) {
    size_t i;
    for (i = 0; i < sesion->cantidadSintomas; i++)
        if (strcmp(sesion->sintomas[i].id, id) == 0) return 1;
    return 0;
}

static const char *descripcionSintoma(const char *id) {
    size_t i;
    for (i = 0; i < TOTAL_CATALOGO_SINTOMAS; i++)
        if (strcmp(CATALOGO_SINTOMAS[i].id, id) == 0)
            return CATALOGO_SINTOMAS[i].descripcion;
    return NULL;
}

typedef struct {
    const char *marca;
    const char *modelo;
    int anioMin;
    int anioMax;
    const char *combustible;
    const char *alimentacion;
} PerfilVehiculo;

static const PerfilVehiculo PERFILES_VEHICULOS[] = {
    {"Toyota", "Corolla", 1988, 1994, "gasolina", "carburador"},
    {"Toyota", "Corolla", 1995, 2026, "gasolina", "inyeccion_electronica"},
    {"Toyota", "Hilux", 2005, 2026, "diesel", "inyeccion_diesel"},
    {"Toyota", "Prius", 2004, 2026, "hibrido", "inyeccion_electronica"},
    {"Chevrolet", "Spark", 2006, 2022, "gasolina", "inyeccion_electronica"},
    {"Chevrolet", "Aveo", 2004, 2024, "gasolina", "inyeccion_electronica"},
    {"Hyundai", "Accent", 1996, 2026, "gasolina", "inyeccion_electronica"},
    {"Hyundai", "Tucson", 2005, 2026, "gasolina", "inyeccion_electronica"},
    {"Ford", "Fiesta", 1998, 2023, "gasolina", "inyeccion_electronica"},
    {"Ford", "Ranger", 2006, 2026, "diesel", "inyeccion_diesel"},
    {"Nissan", "Sentra", 1995, 2026, "gasolina", "inyeccion_electronica"},
    {"Nissan", "Leaf", 2011, 2026, "electrico", "propulsion_electrica"},
    {"Volkswagen", "Gol", 1990, 1994, "gasolina", "carburador"},
    {"Volkswagen", "Gol", 1995, 2023, "gasolina", "inyeccion_electronica"}
};

#define TOTAL_PERFILES_VEHICULOS (sizeof PERFILES_VEHICULOS / sizeof PERFILES_VEHICULOS[0])

static void mostrarPerfilesVehiculos(void) {
    size_t i;
    puts("  PERFILES CATALOGADOS (escriba 1-14 para elegir o ingrese su marca):\n"
         "  ------------------------------------------------------------------");
    for (i = 0; i < TOTAL_PERFILES_VEHICULOS; i++) {
        printf("  [%2zu] %-11s %-9s (%d-%d)  %-10s %s\n",
               i + 1,
               PERFILES_VEHICULOS[i].marca,
               PERFILES_VEHICULOS[i].modelo,
               PERFILES_VEHICULOS[i].anioMin,
               PERFILES_VEHICULOS[i].anioMax,
               PERFILES_VEHICULOS[i].combustible,
               PERFILES_VEHICULOS[i].alimentacion);
    }
    putchar('\n');
}

static void mostrarCatalogoSintomas(const Sesion *sesion) {
    size_t i;
    const char *grupoActual = "";
    mostrarEncabezado("CATALOGO OFICIAL DE SINTOMAS");
    for (i = 0; i < TOTAL_CATALOGO_SINTOMAS; i++) {
        if (strcmp(grupoActual, CATALOGO_SINTOMAS[i].subsistema) != 0) {
            grupoActual = CATALOGO_SINTOMAS[i].subsistema;
            printf("  --- SUBSISTEMA %s ---\n", grupoActual);
        }
        printf("  [%2zu] %c %-29s %s\n",
               i + 1,
               estaSeleccionado(sesion, CATALOGO_SINTOMAS[i].id) ? '*' : ' ',
               CATALOGO_SINTOMAS[i].id,
               CATALOGO_SINTOMAS[i].descripcion);
    }
    puts("\n  (*) Ya agregado en la sesion actual.\n"
         "  [0] Volver al menu principal\n");
}

int registrarVehiculo(Sesion *sesion) {
    Vehiculo nuevo = {0};
    long numero;
    int estado, minAnio = 1886, perfilElegido = 0;
    time_t ahora = time(NULL);
    struct tm *fecha = localtime(&ahora);
    int maxAnio = fecha ? fecha->tm_year + 1901 : 2100;
    mostrarEncabezado("REGISTRO DE VEHICULO");
    puts("  [0] Volver al menu principal sin guardar cambios\n\n"
         "  Todos los campos son obligatorios.\n"
         "  En kilometraje: 0 es valido; escriba volver para cancelar.\n");
    mostrarPerfilesVehiculos();
    for (;;) {
        estado = leerCampo("  Marca (o 1-14 para perfil): ", nuevo.marca, sizeof nuevo.marca);
        if (estado != 1) return estado == -1;
        if (convertirEntero(nuevo.marca, 1, (long)TOTAL_PERFILES_VEHICULOS, &numero)) {
            const PerfilVehiculo *p = &PERFILES_VEHICULOS[numero - 1];
            strcpy(nuevo.marca, p->marca);
            strcpy(nuevo.modelo, p->modelo);
            strcpy(nuevo.combustible, p->combustible);
            minAnio = p->anioMin;
            maxAnio = p->anioMax;
            perfilElegido = 1;
            printf("\n  [Perfil] %s %s | %s | Rango permitido: %d-%d\n\n",
                   nuevo.marca, nuevo.modelo, nuevo.combustible, minAnio, maxAnio);
            break;
        }
        if (convertirEntero(nuevo.marca, LONG_MIN, LONG_MAX, &numero)) {
            printf("  [ERROR] Numero de perfil fuera de rango (1-%zu).\n",
                   TOTAL_PERFILES_VEHICULOS);
            continue;
        }
        break;
    }
    if (!perfilElegido) {
        estado = leerCampo("  Modelo       : ", nuevo.modelo, sizeof nuevo.modelo);
        if (estado != 1) return estado == -1;
    }
    estado = leerNumeroCancelable("  Anio         : ", minAnio, maxAnio, 0, &numero);
    if (estado != 1) return estado == -1;
    nuevo.anio = (int)numero;
    estado = leerNumeroCancelable("  Kilometraje (volver: cancelar): ", 0, LONG_MAX, 1,
                                 &nuevo.kilometraje);
    if (estado != 1) return estado == -1;
    if (!perfilElegido) {
        puts("  Opciones comunes: gasolina, diesel, hibrido, electrico, glp");
        estado = leerCampo("  Combustible  : ", nuevo.combustible, sizeof nuevo.combustible);
        if (estado != 1) return estado == -1;
    }
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
        for (i = 0; i < sesion->cantidadSintomas; i++) {
            const char *desc = descripcionSintoma(sesion->sintomas[i].id);
            if (desc)
                printf("  [%2zu] %-29s (%s)\n", i + 1, sesion->sintomas[i].id, desc);
            else
                printf("  [%2zu] %s\n", i + 1, sesion->sintomas[i].id);
        }
        puts("\n----------------------------------------------------------\n"
             "  [1] Agregar sintoma (ver catalogo)\n"
             "  [2] Quitar sintoma\n\n"
             "  [0] Volver al menu principal\n");
        if (!leerEntero("  Seleccione una opcion: ", 0, 2, &opcion)) return 0;
        if (!opcion) return 1;
        limpiarConsola();
        if (opcion == 1) {
            if (sesion->cantidadSintomas == MAX_SINTOMAS) {
                aviso = "\n  [AVISO] Limite de sintomas alcanzado.\n"; continue;
            }
            mostrarCatalogoSintomas(sesion);
            if (!leerTexto("  Numero (1-28) o identificador: ", id, sizeof id)) return 0;
            if (strcmp(id, "0") == 0) return 1;
            if (convertirEntero(id, 1, (long)TOTAL_CATALOGO_SINTOMAS, &indice)) {
                strcpy(id, CATALOGO_SINTOMAS[indice - 1].id);
            } else if (convertirEntero(id, LONG_MIN, LONG_MAX, &indice)) {
                aviso = "\n  [ERROR] Numero fuera de rango (1-28).\n"; continue;
            } else if (!identificadorValido(id)) {
                aviso = "\n  [ERROR] Ingrese un numero (1-28) o identificador valido (a-z, 0-9, _).\n";
                continue;
            }
            if (estaSeleccionado(sesion, id)) {
                aviso = "\n  [AVISO] El sintoma ya esta seleccionado.\n"; continue;
            }
            strcpy(sesion->sintomas[sesion->cantidadSintomas++].id, id);
            aviso = "\n  [OK] Sintoma agregado.\n";
        } else {
            puts("  [0] Volver al menu principal\n");
            if (!sesion->cantidadSintomas) {
                aviso = "\n  [AVISO] No hay sintomas para quitar.\n"; continue;
            }
            for (i = 0; i < sesion->cantidadSintomas; i++)
                printf("  [%2zu] %s\n", i + 1, sesion->sintomas[i].id);
            putchar('\n');
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