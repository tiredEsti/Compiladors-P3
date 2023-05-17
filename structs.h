#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>




#ifndef VARIABLE_TYPE
#define VARIABLE_TYPE
typedef enum
{
    INTEGER,
    FLOAT,
    STRING,
    BOOLEAN,
    UNDEFINED
} varType;

typedef struct list_t
{
    int index;
    struct list_t *next;
} list;

typedef struct variable_t
{
    char * name;
    varType type;
    char * place;
    char * ctr;
    int repeat;

    char * value;
    list * truelist;
    list * falselist;
    list * nextlist;

} variable;


typedef struct quad_t
{
    char * one; //resultat o primer parametre a emetre
    char * two; //primera variable
    char * three; //operand
    char * four;    //segona variable
    char * five;    //segona variable
    char * six;    //segona variable
    char * label;

} quad;

#endif