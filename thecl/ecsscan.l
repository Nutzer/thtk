%option noinput nounput noyywrap
%top {
/*
 * Redistribution and use in source and binary forms, with
 * or without modification, are permitted provided that the
 * following conditions are met:
 *
 * 1. Redistributions of source code must retain this list
 *    of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce this
 *    list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
#include <config.h>
}
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include "thecl.h"
    #include "ecsparse.h"
    #include "util.h"
    void yyerror(parser_state_t*, const char*);
    /* yylloc.first_column is initialized to 1. */
    #define YY_USER_INIT yylloc.first_column = 0
    /* XXX: The builtin YY_INPUT does something with the newlines that doesn't
     * work well with Wine/Windows. */
    /* TODO: Add some \r handling to the line counting stuff. */
    #define YY_INPUT(buf,result,max_size) \
    { \
        int c = getc_unlocked(yyin); \
        if (c == EOF) { \
            result = YY_NULL; \
        } else { \
            if (c == '\n') { \
                yylloc.first_line++; \
                yylloc.last_line = yylloc.first_line; \
                yylloc.first_column = 0; \
            } else { \
                yylloc.first_column++; \
            } \
            yylloc.last_column = yylloc.first_column; \
            buf[0] = c; \
            result = 1; \
        } \
    }
%x COMMENT COMMENT_SINGLE CSTRING STRING ESCAPE_CHAR
%%
","        return COMMA;
"?"        return QUESTION;
":"        return COLON;
";"        return SEMICOLON;
"["        return SQUARE_OPEN;
"]"        return SQUARE_CLOSE;
"{"        return BRACE_OPEN;
"}"        return BRACE_CLOSE;
"("        return PARENTHESIS_OPEN;
")"        return PARENTHESIS_CLOSE;
"anim"     return ANIM;
"ecli"     return ECLI;
"sub"      return SUB;
"timeline" return TIMELINE;
"var"      return VAR;
"int"      return INT;
"float"    return FLOAT;
"void"     return VOID;
"inline"   return INLINE;
"return"   return RETURN;
"@"        return AT;

"goto"     return GOTO;
"unless"   return UNLESS;
"if"       return IF;
"else"     return ELSE;
"do"       return DO;
"while"    return WHILE;
"times"    return TIMES;
"switch"   return SWITCH;
"case"     return CASE;
"default"  return DEFAULT;
"break"    return BREAK;
"async"    return ASYNC;
"global"   return GLOBAL;
"="        return ASSIGN;
"+="       return ASSIGNADD;
"-="       return ASSIGNSUB;
"*="       return ASSIGNMUL;
"/="       return ASSIGNDIV;
"%="       return ASSIGNMOD;
"^="       return ASSIGNXOR;
"|="       return ASSIGNBOR;
"&="       return ASSIGNBAND;
"+"        return ADD;
"-"        return SUBTRACT;
"*"        return MULTIPLY;
"/"        return DIVIDE;
"%"        return MODULO;
"=="       return EQUAL;
"!="       return INEQUAL;
"<"        return LT;
"<="       return LTEQ;
">"        return GT;
">="       return GTEQ;
"!"        return NOT;
"||"       return OR;
"&&"       return AND;
"^"        return XOR;
"|"        return B_OR;
"&"        return B_AND;
"--"       return DEC;
"sin"      return SIN;
"cos"      return COS;
"sqrt"     return SQRT;

"$"        return DOLLAR;

_S return CAST_INTEGER;
_f return CAST_FLOATING;
_SS return CAST_II;
_Sf return CAST_IF;
_ff return CAST_FF;
_fS return CAST_FI;

[0-9]+(\.([0-9]*f|[0-9]+)|f) {
    yylval.floating = strtof(yytext, NULL);
    return FLOATING;
}
rad\([-\+]?[0-9]+(\.([0-9]*f|[0-9]+)|f)?\) {
    yylval.floating = strtof(yytext+4, NULL) / 180.0f * 3.14159265359f;
    return FLOATING;
}
ins_[0-9]+ {
    yylval.integer = strtol(yytext+4, NULL, 10);
    return INSTRUCTION;
}
[0-9]+ {
    yylval.integer = strtoul(yytext, NULL, 10);
    return INTEGER;
}
0x[0-9a-fA-F]+ {
    yylval.integer = strtoul(yytext, NULL, 16);
    return INTEGER;
}
0b[0-1]+ {
    yylval.integer = strtoul(yytext+2, NULL, 2);
    return INTEGER;
}
"false" {
    /* boolean "false" */
    yylval.integer = 0;
    return INTEGER;
}
"true" {
    /* boolean "true" */
    yylval.integer = 1;
    return INTEGER;
}

![-*ENHLWXYZO4567]+ {
    yylval.string = strdup(yytext + 1);
    return RANK;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.string = strdup(yytext);

    if (eclmap_is_mnemonic(g_eclmap, yytext))
        return MNEMONIC;
    return IDENTIFIER;
}

\" {
    BEGIN(STRING);
    yylval.string = strdup("");
}
<STRING>[^\"\n\\]+ {
    yylval.string = realloc(yylval.string, strlen(yylval.string) + yyleng + 1);
    strcat(yylval.string, yytext);
}
<STRING>\\ {
    BEGIN(ESCAPE_CHAR);
}
<STRING>\n {
    free(yylval.string);
    yyerror(NULL, "unterminated string");
    BEGIN(INITIAL);
    yyterminate();
}
<STRING>\" {
    BEGIN(INITIAL);
    return TEXT;
}
<ESCAPE_CHAR>[\"\\nr0] {
    char c;
    switch(yytext[0]) {
        case 'n':
            c = '\n';
            break;
        case 'r':
            c = '\r';
            break;
        case '0':
            c = '\0';
            break;
        default:
            c = yylval.string[0];
    }
    size_t len = strlen(yylval.string);
    yylval.string = realloc(yylval.string, len + yyleng + 1);
    /* Length of the yytext string must be 1, since only single character strings
     * match the regex. So we can safely just write one character followed by null
     * terminator in place of it. */
    yylval.string[len] = c;
    yylval.string[len + 1] = '\0';
    BEGIN(STRING);
}
<ESCAPE_CHAR>[^\"\\nr0] {
    char buf[256];
    snprintf(buf, 256, "invalid character escape: %s", yytext);
    yyerror(NULL, buf);
    BEGIN(INITIAL);
    yyterminate();
}

"/*"               BEGIN(COMMENT);
<COMMENT>[^*]*     |
<COMMENT>\*[^*/]*  ;
<COMMENT>"*/"      BEGIN(INITIAL);

"//"                  BEGIN(COMMENT_SINGLE);
<COMMENT_SINGLE>.*    ;
<COMMENT_SINGLE>"\n"  BEGIN(INITIAL);

#([a-zA-Z]+) {
    yylval.string = strdup(yytext + 1);
    return DIRECTIVE;
}

[\t\n\r ]+ ;
. {
    char buf[256];
    snprintf(buf, 256, "illegal token: %s", yytext);
    yyerror(NULL, buf);
    return ILLEGAL_TOKEN;
}
