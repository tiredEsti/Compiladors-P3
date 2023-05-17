%{
  #include <stdio.h>
  #include <stdlib.h>
  #include "structs.h"
  #include "symtab.h"
  extern FILE *yyin;
  extern FILE* yyout;
  #include "syn.tab.h"

%}

%option noyywrap
%x IN_COMMENT

int [0-9]*
float [0-9]*\.[0-9]*([eE][-+]?[0-9]+)?
string \".*\"



%%
"repeat"  {return REPEAT;}
"do"      {return DO;}
"done"    {return DONE;}
"if"      {return IF;}
"then"    {return THEN;}
"else"    {return ELSE;}
"fi"      {return FI;}
"while"   {return WHILE;}
"until"   {return UNTIL;}
"for"     {return FOR;}
"in"      {return IN;}
".."      {return RANG;}

{float} {
  yylval.var.type = FLOAT;
  yylval.var.place = (char *)malloc(sizeof(char)*yyleng+1);
  strncpy(yylval.var.place, yytext, yyleng+1);
  return FL;
}
{int} {
  yylval.var.type = INTEGER;
  yylval.var.place = (char *)malloc(sizeof(char)*yyleng+1);
  strncpy(yylval.var.place, yytext, yyleng+1);
  return INT;
}



":="            { return ASSIGN; }
"+"             { return ADD; }
"-"             { return SUB; }
"*"             { return MUL; }
"/"             { return DIV; }
"%"             { return MOD; }
"**"            { return POW; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"=="            { yylval.var.type = STRING; yylval.var.place = "EQ"; return BOOLOP; }
">"             { yylval.var.type = STRING; yylval.var.place = "GT"; return BOOLOP; }
">="            { yylval.var.type = STRING; yylval.var.place = "GE"; return BOOLOP; }
"<"             { yylval.var.type = STRING; yylval.var.place = "LT"; return BOOLOP; }
"<="            { yylval.var.type = STRING; yylval.var.place = "LE"; return BOOLOP; }
"<>"            { yylval.var.type = STRING; yylval.var.place = "NE"; return BOOLOP; }

"and"           { return AND; }
"or"            { return OR; }

"not"           { return NOT; }
"true"          { yylval.var.type = BOOLEAN; yylval.var.place = "TRUE" ; return BOOL; }
"false"         { yylval.var.type = BOOLEAN; yylval.var.place = "FALSE" ; return BOOL; }



"\n"            { return EOL; }
"\t"            {}
"\r"            {}
" "             {}



"//".*"\n"       { return SCOMMENT; }                  /* one line comments */



<INITIAL>{
"/*"            BEGIN(IN_COMMENT);
}
<IN_COMMENT>{
"*/"            BEGIN(INITIAL);
[^*\n]+                             /* eat comment in chunks */
"*"                                 /* eat the lone star */
\n    { return MCOMMENT;}
}

[a-zA-Z0-9]*   { yylval.var.name = (char *)malloc(sizeof(char)*yyleng+1);
                  strncpy(yylval.var.name, yytext, yyleng+1);
                  variable aux;
                  if (sym_lookup(yytext, &aux) == SYMTAB_NOT_FOUND){
                    return ID;
                  } 
                  else {  if (aux.type == BOOLEAN) return B_ID;
                          else return A_ID;
                  }
              }


. {return LERR;}


<<EOF>>                 { return END; }

%%