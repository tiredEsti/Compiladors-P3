%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdbool.h>
	#include <math.h>
	#include <stdarg.h>
	#include "syn.tab.h"

	#define MAX_QUADS 500

	int errflag = 0;
	int temp = 1;
	int gdb = 0;			//used for debugging

	quad *quad_list;


	int currQuad = 0;

	extern FILE* yyin;
	extern int yylineno;

	extern int yywrap( );
	extern int yylex();
	extern void yyerror(char *explanation);

	FILE* flog;

	int yyterminate()
	{
	  return 0;
	}



	void addQuad(int num_args, ...);	
	variable arithmeticCalc(variable v1, char* op, variable v2);
	variable booleanCalc(variable v1, char *op, variable v2);
	void yyerror(char *explanation);
	variable powFunction(variable v1, variable v2);
	char *newTemp();
	void printQuads();

	list *makelist(int i);
	list *merge(list *l1, list *l2);
	void backpatch(list *p, int l);

%}

%code requires {
  	#include "symtab.h"
	#include "structs.h"
}

%union {
    variable var;
};

%token <var> FL INT ID A_ID ADD SUB MUL DIV MOD POW BOOLOP BOOL B_ID

%token ASSIGN LPAREN RPAREN EOL END SCOMMENT MCOMMENT LERR REPEAT DO DONE AND NOT OR IF THEN ELSE FI WHILE UNTIL FOR IN RANG 
%type <var> statement statement_list arithmetic_op1 arithmetic_op2 arithmetic_op3 arithmetic repeat_statementStart repeat_statementEnd id boolean_op1 boolean_op2 boolean_op3 boolean_arithmetic boolean M N indexed_statementStart
%start program

%%
program : statement_list	{backpatch($1.nextlist, currQuad);}

statement_list : statement_list M statement { 
	backpatch($1.nextlist, $2.repeat); 
	$$.nextlist = $3.nextlist;
}
|	statement_list statement {backpatch($2.nextlist, currQuad+1);}| statement {$$.nextlist = $1.nextlist;}
| statement_list repeat_statementStart | statement_list repeat_statementEnd;

repeat_statementStart: REPEAT arithmetic {
	
	
	if($2.type == UNDEFINED){
		$$.type = UNDEFINED;
		yylineno++;
		yyerror($2.place);
	} else {
		fprintf(flog, "Line %d, LOOP START\n", yylineno); 
		yylineno++;
		$$ = $2;
		$$.ctr = (char *)malloc(100);
		strcpy($$.ctr, newTemp());
		addQuad(3, $$.ctr,":=", "0");
		$$.repeat = currQuad +1;
	}											
};

repeat_statementEnd: repeat_statementStart DO EOL statement_list DONE {
	fprintf(flog, "Line %d, LOOP END\n", yylineno); 
	if($4.type == UNDEFINED || $1.type == UNDEFINED){
		$$.type = UNDEFINED;
		yyerror("SEMANTIC ERROR: Loop error detected.\n");
	} else{
		if($1.type == INTEGER) addQuad(5, $1.ctr, ":=", $1.ctr, "ADDI", "1");
		else addQuad(5, $1.ctr, ":=", $1.ctr, "ADDF", "1");
		
		char str[20];
		sprintf(str, "%d", $1.repeat);
		if ($1.type == INTEGER)	{
			addQuad(6, "IF", $1.ctr, "LTI", $1.place, "GOTO", str);
		} else {
			addQuad(6, "IF", $1.ctr, "LTF", $1.place, "GOTO", str);
		}
	}
};



statement: id ASSIGN arithmetic 	{
									
									if($3.type == UNDEFINED){
										yyerror($3.place);
									} else {
										
										$3.name = (char *)malloc(100);
										strcpy($3.name, $1.name);
										sym_enter($1.name, &$3);
										addQuad(3, $1.name, ":=", $3.place);
										fprintf(flog, "Line %d, ASSIGNATION %s := %s\n", yylineno, $1.name, $3.place); 
									}
									yylineno++; 
								}
		| id ASSIGN arithmetic EOL	{	
									if($3.type == UNDEFINED){
										yyerror($3.place);
									} else {
										
										$3.name = (char *)malloc(100);
										strcpy($3.name, $1.name);
										sym_enter($1.name, &$3);
										addQuad(3, $1.name, ":=", $3.place);
										fprintf(flog, "Line %d, ASSIGNATION %s := %s\n", yylineno, $1.name, $3.place); 
									}
									yylineno++;
								}
		| id				{	
									if($1.type == UNDEFINED){
										yyerror($1.place);
									} else {	
												
											if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {	
												yyerror("SEMANTIC ERROR: VARIABLE NOT FOUND.\n"); errflag = 1; YYERROR;
											} 
											else { 
												addQuad(2, "PARAM", $1.name);
												fprintf(flog, "Line %d, PARAM %s set\n", yylineno, $1.name);

												if($1.type == INTEGER){
													addQuad(3, "CALL", "PUTI", "1");
													fprintf(flog, "Line %d, calling PUTI\n", yylineno);
												}
												else{
													addQuad(3, "CALL", "PUTF", "1");
													fprintf(flog, "Line %d, calling PUTF\n", yylineno);
												}
											}
										}	
									yylineno++;
								}
		| IF LPAREN boolean RPAREN THEN EOL M statement_list N ELSE M statement_list FI {
			yylineno++;
			yylineno++;
			backpatch($9.nextlist, currQuad+1);
			backpatch($3.truelist, $7.repeat);
			backpatch($3.falselist, $11.repeat);
			list * temp = merge($8.nextlist, $9.nextlist);
			$$.nextlist = merge(temp, $12.nextlist);
			fprintf(flog, "Line %d: IF ELSE end\n", yylineno++);

		}

		| IF LPAREN boolean RPAREN THEN EOL M statement_list FI EOL{
			fprintf(flog, "Line %d: IF end\n", yylineno++);
			backpatch($3.truelist, $7.repeat);
			$$.nextlist = merge($3.falselist, $8.nextlist);
		}
		| WHILE LPAREN M boolean RPAREN DO EOL M statement_list DONE EOL {
			fprintf(flog, "Line %d: WHILE Loop end\n", yylineno++);
			//backpatch($9.nextlist, $3.repeat);
			backpatch($4.truelist, $8.repeat);
			$$.nextlist = $4.falselist;
			char * aux = malloc(sizeof(char)*10);
			sprintf(aux, "%d", $3.repeat);
			addQuad(2, "GOTO", aux);
			free(aux);
		}
		| DO EOL M statement_list UNTIL LPAREN boolean RPAREN EOL {
			yylineno++;
			fprintf(flog, "Line %d: DO UNTIL Loop end\n", yylineno++);
			backpatch($7.truelist, $3.repeat);
			$$.nextlist = merge($7.falselist, $4.nextlist);
		}
		| indexed_statementStart DO EOL statement_list DONE EOL	{
			yylineno++;
			addQuad(5, $1.name, ":=", $1.name, "ADDI", "1");
			char * aux = malloc(sizeof(char)*10);
			sprintf(aux, "%d", $1.repeat);
			addQuad(2, "GOTO", aux);
			char * aux2 = malloc(sizeof(char)*10);
			sprintf(aux2, "%d", currQuad+1);
			quad_list[$1.repeat].label = malloc(sizeof(char)*100+1);
			strcpy(quad_list[$1.repeat].label , aux2);

			free(aux);
			free(aux2);
			fprintf(flog, "Line %d: For loop ended\n", yylineno++);
		}
		| EOL					{yylineno++;}
		| SCOMMENT			{ fprintf(flog, "Line %d, SINGLE LINE COMMENT DETECTED\n", yylineno);yylineno++; }
		| MCOMMENT			{ fprintf(flog, "Line %d, MULTIPLE LINE COMMENT DETECTED\n", yylineno);yylineno++; }
		| END					{fprintf(flog, "Line %d, End of the file, execution COMPLETED\n", yylineno); YYABORT;}
		| LERR EOL			{$$.type = UNDEFINED; yyerror("LEXICAL ERROR: invalid character.\n"); yylineno++; }
		| LERR 				{$$.type = UNDEFINED; yyerror("LEXICAL ERROR: invalid character.\n");} 
		| error	EOL			{	$$.type = UNDEFINED;
								if (errflag == 1){ errflag = 0;}
								else {	//printf("\tSYNTAX ERROR: no matching rule found\n");
    									fprintf(flog,"\tSYNTAX ERROR: no matching rule found\n");} yylineno++;};
id: ID | A_ID | B_ID;

indexed_statementStart: FOR A_ID IN arithmetic RANG arithmetic {
	if($2.type != INTEGER){
		$$.type = UNDEFINED;
		yyerror("SEMANTIC ERROR: Loop initialization, invalid float operation.\n");
		yylineno++;
	} else{ 
		fprintf(flog, "Line %d: For loop started\n", yylineno++);
		addQuad(3, $2.name, ":=", $4.place);
		fprintf(flog, "Line %d, ASSIGNATION %s := %s\n", yylineno, $2.name, $4.place); 
		$$.place = $4.place;
		$$.repeat = currQuad;
		$$.name = $2.name;
		addQuad(5, "IF", $2.name, "LEI", $6.place, "GOTO");
	}
};


arithmetic: arithmetic_op1 | arithmetic ADD arithmetic_op1	{$$ = arithmeticCalc($1, "+", $3);}
		| arithmetic SUB arithmetic_op1 					{$$ = arithmeticCalc($1, "-", $3);}
		| ADD arithmetic_op1								{($$ = $2);}
		| SUB arithmetic_op2								{	$$.type = $2.type;
																$$.place = (char *)malloc(5);
																strcpy($$.place, newTemp());
																if($2.type == INTEGER) addQuad(4, $$.place, ":=", "CHSI", $2.place);
																else addQuad(4, $$.place,":=", "CHSF", $2.place);
															};

arithmetic_op1: arithmetic_op2 | arithmetic_op1 MUL arithmetic_op2 	{$$ = arithmeticCalc($1, "*", $3);}
		| arithmetic_op1 DIV arithmetic_op2 						{$$ = arithmeticCalc($1, "/", $3);}
		| arithmetic_op1 MOD arithmetic_op2							{$$ = arithmeticCalc($1, "%", $3);};

arithmetic_op2: arithmetic_op3 | arithmetic_op2 POW arithmetic_op3	{$$ = arithmeticCalc($1, "**", $3);};

arithmetic_op3: LPAREN arithmetic RPAREN	{$$ = $2;}
			| INT 							{ 	if($1.type == UNDEFINED){
													yyerror($1.name);
												} else $$ = $1;
											}
		| FL								{ 	if($1.type == UNDEFINED){
													yyerror($1.name);
												} else $$ = $1;
											}
		| A_ID								{ 	if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {	yyerror("SEMANTIC ERROR: VARIABLE NOT FOUND.\n");errflag = 1; $$.type = UNDEFINED; YYERROR;} 
												else { $$.type = $1.type; $$.place = (char *)malloc(100);strcpy($$.place, $1.name); $$.name = (char *)malloc(100);strcpy($$.name, $1.name);}}
		|ID								{ 	if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {	yyerror("SEMANTIC ERROR: VARIABLE NOT FOUND.\n"); errflag = 1; $$.type = UNDEFINED; YYERROR;} 
												else { $$.type = $1.type; $$.place = (char *)malloc(50); strcpy($$.place, $1.name); $$.name = (char *)malloc(100);strcpy($$.name, $1.name);}};

M: { $$.repeat = currQuad+1; };

N: { $$.nextlist = makelist(currQuad); addQuad(1, "GOTO");};


boolean: boolean_op1 | boolean OR M boolean_op1		{ 
	
	$$.place = (char *)malloc(10);
	$$.type = BOOLEAN;
	strcpy($$.place, newTemp());
	backpatch($1.falselist, $3.repeat);
	$$.truelist = merge($1.truelist, $4.truelist);
	$$.falselist = $4.falselist;
};

boolean_op1: boolean_op2 | boolean_op1 AND M boolean_op2 {
	$$.place = (char *)malloc(10);
	$$.type = BOOLEAN;
	strcpy($$.place, newTemp());
	backpatch($1.truelist, $3.repeat);
	$$.truelist = $4.truelist;
	$$.truelist = merge($1.falselist, $4.falselist);

};

boolean_op2: boolean_op3 | NOT boolean_op2 {
	$$=$2;
	$$.truelist = $2.falselist;
	$$.falselist = $2.truelist;
};

boolean_op3: boolean_arithmetic
	| LPAREN boolean RPAREN	{ $$ = $2; }
	| BOOL 	{ 
		$$.place = (char *)malloc(10);
		$$.type = BOOLEAN;
		strcpy($$.place, $1.place);
		if (strcmp($1.place, "TRUE") == 0) {
			$$.truelist = makelist(currQuad);
			addQuad(1, "GOTO");
		} else {
			$$.falselist = makelist(currQuad);
			addQuad(1, "GOTO");
		}
	}
	| B_ID	{	
		if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {
			yyerror("SEMANTIC ERROR: VARIABLE NOT FOUND\n");errflag = 1; YYERROR;
		}
		else { $$.type = $1.type; $$.value=$1.value; $$.place = $1.place;}
	};

boolean_arithmetic: arithmetic BOOLOP arithmetic 	{
	//$$ = booleanCalc($1, $2.place, $3);
	int aux = currQuad +1;
	$$.truelist = makelist(currQuad);
	$$.falselist = makelist(aux);
	char buffer[100];
	sprintf(buffer, $2.place);
	if ($1.type == INTEGER && $3.type == INTEGER) strcat(buffer, "I");
    else strcat(buffer, "F");
	addQuad(5, "IF", $1.place, buffer, $3.place, "GOTO");
	addQuad(1, "GOTO");
};

%%

void yyerror(char *explanation){
    if (strcmp(explanation, "End of the file, execution COMPLETED\n") == 0){
    	//printf("%s", explanation);
    	fprintf(flog,"%s", explanation);
    } else{ 
    	//printf("Line %d\t%s", yylineno, explanation);
    	fprintf(flog,"Line %d\t%s", yylineno, explanation);
    }
}

void addQuad(int num_args, ...) {
  va_list args;
  va_start(args, num_args);
  quad q;
  q.one = NULL;
  q.two = NULL;
  q.three = NULL;
  q.four = NULL;
  q.five = NULL;
  q.six = NULL;
  q.label = NULL;

  if (num_args > 0) {q.one = (char *)malloc(100); (char *)malloc(100); strcpy(q.one, va_arg(args, char*));}
  if (num_args > 1) {q.two = (char *)malloc(100); (char *)malloc(100);strcpy(q.two, va_arg(args, char*));}
  if (num_args > 2) {q.three = (char *)malloc(100); (char *)malloc(100);strcpy(q.three, va_arg(args, char*));}
  if (num_args > 3) {q.four = (char *)malloc(100); (char *)malloc(100);strcpy(q.four, va_arg(args, char*));}
  if (num_args > 4) {q.five = (char *)malloc(100); (char *)malloc(100);strcpy(q.five, va_arg(args, char*));}
  if (num_args > 5) {q.six = (char *)malloc(100); (char *)malloc(100);strcpy(q.six, va_arg(args, char*));}
  quad_list[currQuad] = q;
  currQuad++;
  va_end(args);
}




char *newTemp() {
  char tempString[50];
  sprintf(tempString, "$t%d", temp);
  temp++;
  char *tempPointer = tempString;
  return tempPointer;
}


/*TODO
variable booleanCalc(variable v1, char *op, variable v2) {
	variable result = {.type = BOOLEAN};
    result.place = (char *)malloc(100);
    if (strcmp(op, "EQ")==0 || strcmp(op, "NE") == 0){
    	if(v1.type == v2.type){
    		addQuad(5, "IF", v1.place, op, v2.place, "GOTO");
    	} else{
    		yyerror("SEMANITC ERRORS: variables must have the same type.\n");
    	}

    } else{
    	//TODO
    }
}*/


variable arithmeticCalc(variable v1, char *op, variable v2) {
    variable result = {.type = UNDEFINED};
    result.place = (char *)malloc(100);
    if(strcmp(op, "**")==0){
    	result = powFunction(v1, v2);
    	return result;
    } 

    if (v1.type == INTEGER && v2.type == INTEGER) {
        result.type = INTEGER;
        strcpy(result.place, newTemp());
        if (strcmp(op, "+") == 0) {
            addQuad(5, result.place, ":=", v1.place, "ADDI", v2.place);
        } else if (strcmp(op, "-") == 0) {
            addQuad(5, result.place, ":=", v1.place, "SUBI", v2.place);
        } else if (strcmp(op, "*") == 0) {
            addQuad(5, result.place, ":=", v1.place, "MULI", v2.place);
        } else if (strcmp(op, "/") == 0) {
            if(strcmp(v2.place, "0") == 0)
            {
                result.type = UNDEFINED;
                strcpy(result.place, "SEMANTIC ERROR: Division by zero\n");
                return result;
            }
            addQuad(5, result.place,":=", v1.place, "DIVI", v2.place);
        } else if (strcmp(op, "%") == 0) {
            addQuad(5, result.place, ":=", v1.place, "MODI", v2.place);
        }
    } else if ((v1.type == INTEGER || v1.type == FLOAT) && (v2.type == INTEGER || v2.type == FLOAT)) {
        result.type = FLOAT;

        char * chTemp = (char *)malloc(100);
        strcpy(chTemp, newTemp());
        if (v1.type == INTEGER) {
            addQuad(4, chTemp, ":=", "I2F", v1.place);
            v1.type = FLOAT;
            strcpy(v1.place, chTemp);
        } 
        if (v2.type == INTEGER) {
            addQuad(4, chTemp,":=",  "I2F", v2.place);
            v2.type = FLOAT;
            strcpy(v2.place, chTemp);
        }
        strcpy(result.place, newTemp());
		if (strcmp(op, "+") == 0) {
			addQuad(5, result.place, ":=", v1.place, "ADDF", v2.place);
		} else if (strcmp(op, "-") == 0) {
			addQuad(5, result.place,":=",  v1.place, "SUBF", v2.place);
		} else if (strcmp(op, "*") == 0) {
			addQuad(5, result.place, ":=", v1.place, "MULF", v2.place);
		} else if (strcmp(op, "/") == 0) {
			if(strcmp(v2.place, "0") == 0)
			{
				result.type = UNDEFINED;
                strcpy(result.place, "SEMANTIC ERROR: Division by zero\n");
                return result;
			}
			addQuad(5, result.place, ":=", v1.place, "DIVF", v2.place);
		} else if (strcmp(op, "%") == 0) {
			result.type = UNDEFINED;
            strcpy(result.place, "SEMANTIC ERROR: Invalid operation for float type.\n");
            return result;
		} 
    } else {
		result.type = UNDEFINED;
        strcpy(result.place, "SEMANTIC ERROR: Invalid type for arithmetic operation.\n");
        return result;
	}
	fprintf(flog, "Line %d, OPERATION %s stored in %s SUCCESS\n", yylineno, op, result.place);
	return result;
}

variable powFunction(variable v1, variable v2) {
  fprintf(flog, "Line %d, POW OPERATION DETECTED\n", yylineno);
  variable result;
  result.place = (char *)malloc(100);
  if (v2.type != INTEGER) {
    result.place = "SEMANTIC ERROR: Invalid operation for float type.\n";
    result.type = UNDEFINED;
    return result;
  }

  int v2_int = atoi(v2.place);
  char * prevResult = (char *)malloc(100);

  result.type = v1.type;
  strcpy(result.place, newTemp());

  int i;
  for (i = 1; i < v2_int; i++) {
  	fprintf(flog, "POW LOOP %d\n", i);
  	strcpy(prevResult, result.place);
  	strcpy(result.place, newTemp());
    addQuad(5, result.place, ":=", v1.place, "*", prevResult);
  }

  return result;
}


void printQuads(){
	fprintf(flog, "Line %d, Printing intermediate code\n", yylineno);
	
	if (currQuad == 0) {
  		printf("quad_list is empty\n");
  		return;
	}
	int i;
	for (i= 0; i < currQuad; i++) {
   		quad *q = &quad_list[i];
   		char aux[500];
   		if (q->one != NULL)		sprintf(aux, q->one);
   		if (q->two != NULL)		{strcat(aux, " "); strcat(aux, q->two);}
   		if (q->three != NULL)	{strcat(aux, " "); strcat(aux, q->three);}
   		if (q->four != NULL)	{strcat(aux, " "); strcat(aux, q->four);}
   		if (q->five != NULL)	{strcat(aux, " "); strcat(aux, q->five);}
   		if (q->six != NULL)		{strcat(aux, " "); strcat(aux, q->six);}
   		if (q->label != NULL)	{strcat(aux, " "); strcat(aux, q->label);}
   		strcat(aux, "\0");
   		printf("%d: %s\n", i+1, aux);
	}

	printf("%d: HALT\n", i+1);
	
}

list* makelist(int i){
	list *pointer = malloc(sizeof(list));
	pointer->next = NULL;
	pointer->index = i;
	return pointer;
}

list* merge(list *l1, list *l2){
	list *comb;
	
	if (l1 == NULL) comb = l2;
	else {
		comb = l1;
		while (comb->next != NULL){
			comb = comb->next;
		}
		if (l2 != NULL) comb->next = l2;
	}
	
	return comb;
}

void backpatch(list *p, int l){
	char * label = malloc(sizeof(char)*100+1);
	sprintf(label, "%d", l);
	while(p != NULL){
		quad_list[p->index].label = malloc(sizeof(char)*100+1);
		strcpy(quad_list[p->index].label , label);
		p = p->next;
	}

}



int main(int argc, char** argv) {
    flog = fopen("log.txt", "w");
    if(flog == NULL){
        printf("Error: Unable to open log file log.txt\n");
        return 1;
    }

    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            printf("Error: Unable to open file %s\n", argv[1]);
            return 1;
        }
    }
    else {
        printf("Error: No input file specified\n");
        return 1;
    }
    
    quad_list = (quad *)malloc(sizeof(quad) * MAX_QUADS);
    yyparse();
    printQuads();
    free(quad_list);
    if(fclose(flog) != 0){
        printf("Error: Unable to close log file log.txt\n");
        return 1;
    }

    return 0;
}