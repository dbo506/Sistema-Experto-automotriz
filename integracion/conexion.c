#include "conexion.h"
#include "../frontend/validaciones.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <limits.h>

/* Ningun dato del usuario se incluye en el comando del shell. */
static void escribirAtomo(FILE *f, const char *texto) {
    const unsigned char *p = (const unsigned char *)texto;
    fputc(39, f);
    for (; *p; p++) {
        if (*p == 39 || *p == 92) fprintf(f, "\\x%02x\\", (unsigned)*p);
        else fputc(*p, f);
    }
    fputc(39, f);
}
static int copiar(char *destino, size_t capacidad, const char *origen) {
    size_t i, n = strlen(origen);
    if (!n || n >= capacidad) return 0;
    for (i = 0; i < n; i++)
        if ((unsigned char)origen[i] < 32 || (unsigned char)origen[i] == 127) return 0;
    memmove(destino, origen, n + 1);
    return 1;
}
/* Separacion estricta: no acepta columnas vacias ni adicionales. */
static int columnas(char *linea, char **campos, int maximo) {
    int n = 1;
    char *p;
    campos[0] = linea;
    for (p = linea; *p; p++) if (*p == '\t') {
        if (n == maximo) return 0;
        *p = '\0';
        campos[n++] = p + 1;
    }
    return n;
}
static int recibir(FILE *f, Operacion op, Sesion *sesion) {
    Sesion nueva = *sesion;
    char linea[2048], *c[7];
    int n, fin = 0, vehiculo = 0, contenido = 0;
    long numero;
    size_t i;
    if (op == CONSULTAR) nueva.cantidadResultados = 0;
    if (op == RECUPERAR) memset(&nueva, 0, sizeof nueva);
    while (fgets(linea, sizeof linea, f)) {
        size_t largo = strlen(linea);
        if (!largo || linea[largo - 1] != '\n' || fin) return 0;
        linea[--largo] = '\0';
        if (largo && linea[largo - 1] == '\r') linea[--largo] = '\0';
        n = columnas(linea, c, 7);
        if (!n) return 0;
        if (!strcmp(c[0], "FIN") && n == 1) { fin = 1; continue; }
        if (!strcmp(c[0], "ERROR") && n == 2) {
            if (copiar(linea, sizeof linea, c[1])) printf("Prolog: %s\n", linea);
            return 0;
        }
        if (!strcmp(c[0], "OK") && n == 1 && (op == GUARDAR || op == REPORTAR) && !contenido) {
            contenido = 1;
        } else if (!strcmp(c[0], "RESULTADO") && n == 4 &&
                   (op == CONSULTAR || op == RECUPERAR)) {
            Resultado *r;
            if (nueva.cantidadResultados == MAX_RESULTADOS) return 0;
            r = &nueva.resultados[nueva.cantidadResultados++];
            if (!copiar(r->diagnostico, sizeof r->diagnostico, c[1]) ||
                !copiar(r->explicacion, sizeof r->explicacion, c[2]) ||
                !copiar(r->recomendacion, sizeof r->recomendacion, c[3])) return 0;
        } else if (!strcmp(c[0], "VEHICULO") && n == 6 && op == RECUPERAR && !vehiculo) {
            if (!copiar(nueva.vehiculo.marca, sizeof nueva.vehiculo.marca, c[1]) ||
                !copiar(nueva.vehiculo.modelo, sizeof nueva.vehiculo.modelo, c[2]) ||
                !convertirEntero(c[3], 1886, 9999, &numero)) return 0;
            nueva.vehiculo.anio = (int)numero;
            if (!convertirEntero(c[4], 0, LONG_MAX, &nueva.vehiculo.kilometraje) ||
                !copiar(nueva.vehiculo.combustible, sizeof nueva.vehiculo.combustible, c[5])) return 0;
            nueva.tieneVehiculo = vehiculo = 1;
        } else if (!strcmp(c[0], "SINTOMA") && n == 2 && op == RECUPERAR) {
            if (!identificadorValido(c[1]) || nueva.cantidadSintomas == MAX_SINTOMAS) return 0;
            for (i = 0; i < nueva.cantidadSintomas; i++)
                if (!strcmp(nueva.sintomas[i].id, c[1])) return 0;
            strcpy(nueva.sintomas[nueva.cantidadSintomas++].id, c[1]);
        } else return 0;
    }
    if (ferror(f) || !fin || (op == RECUPERAR && !vehiculo) ||
        ((op == GUARDAR || op == REPORTAR) && !contenido)) return 0;
    *sesion = nueva;
    return 1;
}
int ejecutarOperacion(Operacion op, Sesion *sesion, const char *recurso) {
    static const char *const nombres[] = {"consultar", "guardar", "recuperar", "reportar"};
    char entrada[96], salida[104], comando[512];
    FILE *f, *reserva;
    unsigned intento;
    size_t i;
    int correcto = 0, estado;
    if (op < CONSULTAR || op > REPORTAR) return 0;
    f = fopen("backend/puente.pl", "r");
    if (!f) { puts("Falta backend/puente.pl: integracion pendiente de Daniel y Jose."); return 0; }
    fclose(f);
#ifdef _WIN32
    estado = system("swipl --version >NUL 2>&1");
#else
    estado = system("swipl --version >/dev/null 2>&1");
#endif
    if (estado != 0) { puts("No se pudo ejecutar SWI-Prolog. Agregue swipl al PATH."); return 0; }
    /* Apertura exclusiva C11: no sobrescribe archivos existentes. */
    for (intento = 0; intento < 100; intento++) {
        snprintf(entrada, sizeof entrada, "ipc_%lu_%lu_%u.req", (unsigned long)time(NULL), (unsigned long)clock(), intento);
        snprintf(salida, sizeof salida, "%s.res", entrada);
        f = fopen(entrada, "wx");
        if (!f) continue;
        reserva = fopen(salida, "wx");
        if (reserva) { fclose(reserva); break; }
        fclose(f);
        remove(entrada);
    }
    if (intento == 100) { puts("No se pudieron crear archivos de intercambio."); return 0; }
    fprintf(f, "solicitud(1,%s,", nombres[op]);
    escribirAtomo(f, recurso);
    fputs(",sesion(", f);
    if (sesion->tieneVehiculo) {
        fputs("vehiculo(", f);
        escribirAtomo(f, sesion->vehiculo.marca); fputc(',', f);
        escribirAtomo(f, sesion->vehiculo.modelo);
        fprintf(f, ",%d,%ld,", sesion->vehiculo.anio, sesion->vehiculo.kilometraje);
        escribirAtomo(f, sesion->vehiculo.combustible); fputc(')', f);
    } else fputs("sin_vehiculo", f);
    fputs(",[", f);
    for (i = 0; i < sesion->cantidadSintomas; i++) {
        if (i) fputc(',', f);
        escribirAtomo(f, sesion->sintomas[i].id);
    }
    fputs("],[", f);
    for (i = 0; i < sesion->cantidadResultados; i++) {
        if (i) fputc(',', f);
        fputs("resultado(", f);
        escribirAtomo(f, sesion->resultados[i].diagnostico); fputc(',', f);
        escribirAtomo(f, sesion->resultados[i].explicacion); fputc(',', f);
        escribirAtomo(f, sesion->resultados[i].recomendacion); fputc(')', f);
    }
    fputs("])).\n", f);
    estado = ferror(f);
    if (fclose(f) != 0) estado = 1;
    if (!estado) {
        snprintf(comando, sizeof comando,
                 "swipl -q -s backend/puente.pl -g main -t halt -- %s %s", entrada, salida);
        if (system(comando) == 0) {
            f = fopen(salida, "r");
            if (f) { correcto = recibir(f, op, sesion); fclose(f); }
        }
    }
    remove(entrada);
    remove(salida);
    if (!correcto) puts("La operacion fallo o la respuesta no cumple el protocolo. Sesion conservada.");
    else if (op == CONSULTAR && !sesion->cantidadResultados) puts("Prolog no encontro diagnosticos.");
    else puts("Operacion confirmada por Prolog.");
    return correcto;
}