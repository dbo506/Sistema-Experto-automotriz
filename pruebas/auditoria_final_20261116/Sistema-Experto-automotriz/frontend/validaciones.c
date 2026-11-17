#include "validaciones.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

int leerTexto(const char *mensaje, char *destino, size_t capacidad) {
    int c;
    size_t inicio, fin, i;
    if (capacidad < 2) return 0;
    for (;;) {
        fputs(mensaje, stdout);
        fflush(stdout);
        if (!fgets(destino, (int)capacidad, stdin)) return 0;
        fin = strlen(destino);
        if (fin && destino[fin - 1] != '\n' && !feof(stdin)) {
            c = getchar();
            if (c != '\n' && c != EOF) {
                while ((c = getchar()) != '\n' && c != EOF) {}
                puts("Entrada demasiado larga.");
                continue;
            }
        }
        inicio = 0;
        while (isspace((unsigned char)destino[inicio])) inicio++;
        while (fin > inicio && isspace((unsigned char)destino[fin - 1])) fin--;
        memmove(destino, destino + inicio, fin - inicio);
        destino[fin - inicio] = '\0';
        if (!destino[0]) { puts("El campo es obligatorio."); continue; }
        for (i = 0; destino[i]; i++)
            if (iscntrl((unsigned char)destino[i])) break;
        if (destino[i]) { puts("No se permiten caracteres de control."); continue; }
        return 1;
    }
}
int convertirEntero(const char *texto, long minimo, long maximo, long *valor) {
    char *fin;
    long numero;
    errno = 0;
    numero = strtol(texto, &fin, 10);
    if (fin == texto || errno == ERANGE) return 0;
    while (isspace((unsigned char)*fin)) fin++;
    if (*fin || numero < minimo || numero > maximo) return 0;
    *valor = numero;
    return 1;
}
int leerEntero(const char *mensaje, long minimo, long maximo, long *valor) {
    char texto[64];
    while (leerTexto(mensaje, texto, sizeof texto)) {
        if (convertirEntero(texto, minimo, maximo, valor)) return 1;
        printf("Ingrese un entero entre %ld y %ld.\n", minimo, maximo);
    }
    return 0;
}
int identificadorValido(const char *texto) {
    size_t i;
    if (texto[0] < 'a' || texto[0] > 'z') return 0;
    for (i = 1; texto[i]; i++)
        if (!((texto[i] >= 'a' && texto[i] <= 'z') ||
              (texto[i] >= '0' && texto[i] <= '9') || texto[i] == '_')) return 0;
    return i < 64;
}