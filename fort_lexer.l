/* ΤΜΗΜΑ ΚΩΔΙΚΑ ΠΟΥ ΑΝΤΙΓΡΑΦΕΤΑΙ ΑΥΤΟΥΣΙΟ ΣΤΟ ΤΕΛΙΚΟ ΑΡΧΕΙΟ .c ΤΟΥ ΛΕΚΤΙΚΟΥ ΑΝΑΛΥΤΗ */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "types.h"
#include "fort_syntax_analyzer.tab.h"

/*
ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΜΕΤΑΤΡΟΠΗ ΤΩΝ ICONST ΑΠΟ STRING ΣΕ ΑΚΕΡΑΙΟ
-ΟΛΕΣ ΟΙ ΛΕΚΤΙΚΕΣ ΜΟΝΑΔΕΣ ΔΙΑΒΑΖΟΝΤΑΙ ΩΣ STRING ΑΠΟ ΤΟ FLEX-
*/
int stringtoINT(char *s) {
    if (s[0] == '0' && toupper(s[1]) == 'H') return (int)strtol(s + 2, NULL, 16);
    if (s[0] == '0' && toupper(s[1]) == 'O') return (int)strtol(s + 2, NULL, 8);
    if (s[0] == '0' && toupper(s[1]) == 'B') return (int)strtol(s + 2, NULL, 2);
    return atoi(s); // Ο ΑΡΙΘΜΟΣ ΒΡΙΣΚΕΤΑΙ ΣΕ ΔΕΚΑΔΙΚΗ ΒΑΣΗ
}

/* ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΜΕΤΑΤΡΟΠΗ ΤΩΝ RCONST ΑΠΟ STRING ΣΕ ΠΡΑΓΜΑΤΙΚΟ ΑΡΙΘΜΟ */
double stringtoREAL(char *s) {
    if (s[0] != '0' || (toupper(s[1]) != 'H' && toupper(s[1]) != 'O' && toupper(s[1]) != 'B')) {
        return atof(s); // Ο ΑΡΙΘΜΟΣ ΒΡΙΣΚΕΤΑΙ ΣΕ ΔΕΚΑΔΙΚΗ ΒΑΣΗ
    }

    /* ΕΥΡΕΣΗ ΤΗΣ ΒΑΣΗΣ ΤΟΥ ΑΡΙΘΜΟΥ ΣΕ ΠΕΡΙΠΤΩΣΗ ΠΟΥ ΔΕΝ ΕΙΝΑΙ ΣΤΟ ΔΕΚΑΔΙΚΟ ΣΥΣΤΗΜΑ */
    int base;
    if (toupper(s[1]) == 'H') base = 16;
    else if (toupper(s[1]) == 'O') base = 8;
    else base = 2;
    
    char *dot = strchr(s, '.');
    *dot = '\0'; 
    double intPart = (double)strtol(s + 2, NULL, base); /* ΥΠΟΛΟΓΙΣΜΟΣ ΑΚΕΡΑΙΟΥ ΜΕΡΟΥΣ */ 
    *dot = '.';  
    
    double divisor = base; 
    /* ΒΡΟΓΧΟΣ ΑΠΟ ΜΕΤΑ ΤΗΝ ΤΕΛΕΙΑ ΕΩΣ ΤΟ ΤΕΛΟΣ ΤΟΥ ΔΕΚΑΔΙΚΟΥ ΜΕΡΟΥΣ */
    for (char *pointer = dot + 1; *pointer != '\0'; pointer++) { 
        int realPart;
        if (isdigit(*pointer)) realPart = *pointer - '0'; // Π.Χ. '6' - '0' = 55 - 48 = 6, ΕΚΜΕΤΑΛΕΥΟΜΑΣΤΕ ΤΗΝ ΣΕΙΡΑ ΤΩΝ ASCII ΑΝΑΠΑΡΑΣΤΑΣΕΩΝ
        else realPart = toupper(*pointer) - 'A' + 10; // Ο ΑΡΙΘΜΟΣ ΕΙΝΑΙ ΣΤΟ ΔΕΚΑΕΞΑΔΙΚΟ ΣΥΣΤΗΜΑ
        intPart += realPart / divisor; /* ΠΡΟΣΘΗΚΗ ΤΟΥ ΚΑΘΕ ΨΗΦΙΟΥ ΣΤΟ ΑΚΕΡΑΙΟ ΜΕΡΟΣ ΜΕ ΤΗΝ ΚΑΤΑΛΛΗΛΗ ΔΙΑΙΡΕΣΗ */
        divisor *= base; /* ΑΥΞΗΣΗ ΤΟΥ ΔΙΑΙΡΕΤΗ ΓΙΑ ΤΟ ΕΠΟΜΕΝΟ ΨΗΦΙΟ (ΒΑΣΗ^2, ΒΑΣΗ^3, ...) */
    }
    return intPart;
}

/* ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΜΕΤΑΤΡΟΠΗ ΤΩΝ CCONST ΑΠΟ STRING ΣΕ ΑΚΕΡΑΙΗ ΤΙΜΗ */
int chartoASCII(char *s) {
    if (s[1] != '\\') return s[1]; /* ΑΝ ΤΟ ΣΥΜΒΟΛΟ ΜΕΤΑ ΤΟ ' ΔΕΝ ΕΙΝΑΙ \ ΤΟΤΕ ΕΙΝΑΙ ΧΑΡΑΚΤΗΡΑΣ ΚΑΙ ΕΠΙΣΤΡΕΦΟΥΜΕ ΤΗΝ ASCII ΤΙΜΗ ΤΟΥ */
    switch(s[2]) { // ΑΛΛΙΩΣ ΕΠΙΣΤΡΕΦΟΥΜΕ ΤΗΝ ASCII ΤΙΜΗ ΤΟΥ ΕΚΑΣΤΟΤΕ ΕΙΔΙΚΟΥ ΣΥΜΒΟΛΟΥ
        case 'n': return '\n';
        case 'f': return '\f';
        case 't': return '\t';
        case 'r': return '\r';
        case 'b': return '\b';
        case 'v': return '\v';
        default: return s[2]; 
    }
}

/* ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΟΝ "ΚΑΘΑΡΙΣΜΟ" ΤΟΥ STRING ΑΠΟ ΤΗΝ ΠΕΡΙΤΤΗ ΠΛΗΡΟΦΟΡΙΑ */ 
char* clean_string(char *s, int length) {
    char *string_copy = (char*)malloc(length);
    if (string_copy == NULL) return NULL;

    int string_pointer = 0; /* ΔΕΙΚΤΗΣ ΕΓΓΡΑΦΗΣ ΤΟΥ "ΚΑΘΑΡΟΥ" STRING */ 
    /* ΒΡΟΓΧΟΣ ΠΟΥ ΞΕΚΙΝΑΕΙ ΑΠΟ ΤΗΝ ΔΕΥΤΕΡΗ ΘΕΣΗ ΤΟΥ STRING ΚΑΙ ΣΤΑΜΑΤΑΕΙ ΣΤΗΝ ΠΡΟ ΤΕΛΕΥΤΑΙΑ ΜΕ ΣΚΟΠΟ ΝΑ ΑΓΝΟΗΣΟΥΜΕ ΤΑ "" */
    for (int i = 1; i < length - 1; i++) {
        if (s[i] == '\\') {
            if (s[i + 1] == '\n') {
                i++; /* ΑΝ ΒΡΟΥΜΕ '\n' ΜΕΤΑ ΑΠΟ \ ΑΓΝΟΟΥΜΕ ΚΑΙ ΤΑ 2 ΑΥΞΑΝΟΝΤΑΣ ΤΟΝ ΔΕΙΚΤΗ ΚΑΤΑ 1 */
            }
            else {
                i++; /* ΠΑΜΕ ΣΤΟΝ ΕΠΟΜΕΝΟ ΧΑΡΑΚΤΗΡΑ ΜΕΤΑ ΤΟ \ */ 
                switch(s[i]) {
                    case 'n': string_copy[string_pointer] = '\n'; string_pointer++; break; 
                    case 'f': string_copy[string_pointer] = '\f'; string_pointer++; break;
                    case 't': string_copy[string_pointer] = '\t'; string_pointer++; break;
                    case 'r': string_copy[string_pointer] = '\r'; string_pointer++; break;
                    case 'b': string_copy[string_pointer] = '\b'; string_pointer++; break;
                    case 'v': string_copy[string_pointer] = '\v'; string_pointer++; break;
                    default:  string_copy[string_pointer] = s[i]; string_pointer++; break;
                }
            }
        }
        else {
            string_copy[string_pointer] = s[i]; string_pointer++;
            } 
        }
    string_copy[string_pointer] = '\0';
    return string_copy;
}

/* ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΕΚΤΥΠΩΣΗ ΤΩΝ ΛΕΞΗΜΑΤΩΝ */
void print_token(int token_code) {
    if (token_code == SCONST) {
        printf("Token Code: %d  | Lexeme: %-16s | Token Value: %-16s\n", token_code, yytext, yylval.s_attrs.stringValue);
        }
    else if (token_code == ICONST || token_code == LCONST || token_code == CCONST) {
        printf("Token Code: %d  | Lexeme: %-16s | Token Value: %d\n", token_code, yytext, yylval.s_attrs.intValue);
        }
    else if (token_code == RCONST) {
        printf("Token Code: %d  | Lexeme: %-16s | Token Value: %.5f\n", token_code, yytext, yylval.s_attrs.realValue);
        }
    else printf("Token Code: %d  | Lexeme: %-16s\n", token_code, yytext);
}

/* 
ΠΙΝΑΚΑΣ ΠΟΥ ΘΑ ΠΕΡΙΕΧΕΙ ΚΑΘΕ ΦΟΡΑ ΤΗΝ ΓΡΑΜΜΗ ΠΟΥ ΔΙΑΒΑΖΕΤΑΙ ΑΡΧΙΚΑ ΚΕΝΟΣ \
ΤΟ ΠΕΡΙΕΧΟΜΕΝΟ ΣΒΗΝΕΤΑΙ ΣΕ ΚΑΘΕ ΑΛΛΑΓΗ ΓΡΑΜΜΗΣ
*/
char line_buffer[1024] = "";

/* ΜΑΚΡΟΕΝΤΟΛΗ ΠΟΥ ΕΚΤΕΛΕΙΤΕ ΑΥΤΟΜΑΤΑ ΠΡΙΝ ΑΠΟ ΤΗΝ ΕΝΕΡΓΕΙΑ ΚΑΘΕ ΚΑΝΟΝΑ */
#define YY_USER_ACTION \
    if (yytext[0] == '\n') line_buffer[0] = '\0'; \
    else strncat(line_buffer, yytext, sizeof(line_buffer) - strlen(line_buffer) - 1);
%}

 /* ΤΜΗΜΑ ΡΥΘΜΙΣΕΩΝ-ΟΡΙΣΜΩΝ ΤΟΥ FLEX */

 /* O ΛΕΚΤΙΚΟΣ ΘΑ ΔΙΑΒΑΣΕΙ ΜΟΝΟ ΕΝΑ ΑΡΧΕΙΟ ΕΙΔΟΔΟΥ */
%option noyywrap
%option case-insensitive
 /* ΜΕΤΡΗΤΗΣ ΓΡΑΜΜΩΝ ΤΟΥ flex*/
%option yylineno 

 /* ΔΙΑΣΤΗΜΑΤΑ-ΜΕΤΑΒΛΗΤΕΣ ΠΟΥ ΘΑ ΧΡΗΣΙΜΟΠΟΙΗΘΟΥΝ ΓΙΑ ΤΟ "ΧΤΙΣΙΜΟ" ΤΩΝ ΚΑΝΟΝΩΝ */
letters       [A-Z]
letters_nums  [A-Z0-9]

idec        (0|[1-9][0-9]*)
fracdec     ([0-9]*[1-9][0-9]*)
exponent    (E[+-]?{idec})

ihex        ([A-F1-9][A-F0-9]*)
frachex     ([A-F0-9]*[A-F1-9][A-F0-9]*)

ioct        ([1-7][0-7]*)
fracoct     ([0-7]*[1-7][0-7]*)

ibin        (1[01]*)
fracbin     ([01]*1[01]*)

id_regex         ({letters}{letters_nums}*|_{letters}({letters_nums}|_{letters_nums})*_)
iconst_dec       {idec}
iconst_hex       0H{ihex}
iconst_oct       0O{ioct}
iconst_bin       0B{ibin}
rconst_dec       ({idec}?\.{fracdec}|{idec}\.){exponent}?|{idec}{exponent}
rconst_hex       0H({ihex}?\.{frachex}|{ihex}\.)
rconst_oct       0O({ioct}?\.{fracoct}|{ioct}\.)
rconst_bin       0B({ibin}?\.{fracbin}|{ibin}\.)
lconst_regex     (\.TRUE\.|\.FALSE\.)
cconst_regex     \'([^\\]|\\[nftrbv])\'
sconst_regex     \"([^\"\\]|\\.|\\\n)*\"
listfunc_regex   C(AD*|D+)R

 /* ΤΜΗΜΑ ΚΑΝΟΝΩΝ ΤΟΥ FLEX */
%% 

 /* ΑΓΝΟΝΟΥΝΤΑΙ ΚΕΝΑ, ΑΛΛΑΓΕΣ ΓΡΑΜΜΗΣ ΚΑΙ ΣΧΟΛΙΑ */ 
[ \t]+                  {}
\n                      {}
\$[^\n]*                {}

"FUNCTION"              { print_token(FUNCTION); return FUNCTION; }
"SUBROUTINE"            { print_token(SUBROUTINE); return SUBROUTINE; }
"END"                   { print_token(END); return END; }
 /* ΑΠΟΘΗΚΕΥΣΗ ΑΡΙθΜΟΥ ΓΡΑΜΜΗΣ ΑΝΑΓΝΩΡΙΣΗΣ ΤΟΥ token ΤΗΝ ΣΤΙΓΜΗ ΠΟΥ ΑΝΑΓΝΩΡΙΖΕΤΑΙ 
 ΓΙΑ ΝΑ ΜΗΝ ΕΠΗΡΕΑΣΤΕΙ Ο ΑΡΙΘΜΟΣ ΑΠΟ ΤΟ look ahead ΤΟΥ bison ΣΤΗΝ ΣΥΝΕΧΕΙΑ */
"COMMON"                { yylval.s_attrs.line_counter = yylineno; print_token(COMMON); return COMMON; }
"INTEGER"               { yylval.s_attrs.line_counter = yylineno; print_token(INTEGER); return INTEGER; }  
"REAL"                  { yylval.s_attrs.line_counter = yylineno; print_token(REAL); return REAL; }
"COMPLEX"               { yylval.s_attrs.line_counter = yylineno; print_token(COMPLEX); return COMPLEX; }
"LOGICAL"               { yylval.s_attrs.line_counter = yylineno; print_token(LOGICAL); return LOGICAL; }
"CHARACTER"             { yylval.s_attrs.line_counter = yylineno; print_token(CHARACTER); return CHARACTER; }
"STRING"                { yylval.s_attrs.line_counter = yylineno; print_token(STRING); return STRING; }
"LIST"                  { print_token(LIST); return LIST; }
"DATA"                  { yylval.s_attrs.line_counter = yylineno; print_token(DATA); return DATA; }
"CONTINUE"              { print_token(CONTINUE); return CONTINUE; }
"GOTO"                  { print_token(GOTO); return GOTO; }
"CALL"                  { print_token(CALL); return CALL; }
"READ"                  { print_token(READ); return READ; }
"WRITE"                 { print_token(WRITE); return WRITE; }
"LENGTH"                { print_token(LENGTH); return LENGTH; }
"IF"                    { print_token(IF); return IF; }
"THEN"                  { print_token(THEN); return THEN; }
"ELSE"                  { print_token(ELSE); return ELSE; }
"ENDIF"                 { print_token(ENDIF); return ENDIF; }
"DO"                    { print_token(DO); return DO; }
"ENDDO"                 { print_token(ENDDO); return ENDDO; }
"STOP"                  { print_token(STOP); return STOP; }
"RETURN"                { print_token(RETURN); return RETURN; }

{listfunc_regex}        { yylval.s_attrs.stringValue = strdup(yytext); 
                          print_token(LISTFUNC);  
                          yylval.s_attrs.line_counter = yylineno;
                          return LISTFUNC;
                        }

{id_regex}              { yylval.s_attrs.stringValue = strdup(yytext); 
                          print_token(ID); 
                          yylval.s_attrs.line_counter = yylineno;
                          return ID;
                        }

{iconst_dec}            { yylval.s_attrs.intValue = stringtoINT(yytext); 
                          print_token(ICONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return ICONST; 
                        }

{iconst_hex}            { yylval.s_attrs.intValue = stringtoINT(yytext); 
                          print_token(ICONST);
                          yylval.s_attrs.line_counter = yylineno; 
                          return ICONST; 
                        
                        }

{iconst_oct}            { yylval.s_attrs.intValue = stringtoINT(yytext); 
                          print_token(ICONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return ICONST; 
                        }

{iconst_bin}            { yylval.s_attrs.intValue = stringtoINT(yytext); 
                          print_token(ICONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return ICONST; 
                        }

{rconst_dec}            { yylval.s_attrs.realValue = stringtoREAL(yytext); 
                          print_token(RCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return RCONST; 
                        }

{rconst_hex}            { yylval.s_attrs.realValue = stringtoREAL(yytext); 
                          print_token(RCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return RCONST; 
                        }

{rconst_oct}            { yylval.s_attrs.realValue = stringtoREAL(yytext); 
                          print_token(RCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return RCONST; 
                        }

{rconst_bin}            { yylval.s_attrs.realValue = stringtoREAL(yytext); 
                          print_token(RCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return RCONST; 
                        }

{lconst_regex}          { yylval.s_attrs.intValue = (toupper(yytext[1]) == 'T') ? 1 : 0; 
                          print_token(LCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return LCONST; 
                        }

{cconst_regex}          { yylval.s_attrs.intValue = chartoASCII(yytext); 
                          print_token(CCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return CCONST; 
                        }

{sconst_regex}          { yylval.s_attrs.stringValue = clean_string(yytext, yyleng); 
                          print_token(SCONST); 
                          yylval.s_attrs.line_counter = yylineno;
                          return SCONST;
                        }

"\.OR\."                { yylval.s_attrs.line_counter = yylineno; print_token(OROP); return OROP; }
"\.AND\."               { yylval.s_attrs.line_counter = yylineno; print_token(ANDOP); return ANDOP; }
"\.NOT\."               { yylval.s_attrs.line_counter = yylineno; print_token(NOTOP); return NOTOP; }
"\.GT\."|"\.GE\."|"\.LT\."|"\.LE\."|"\.EQ\."|"\.NE\." { yylval.s_attrs.stringValue = strdup(yytext); 
                                                        yylval.s_attrs.line_counter = yylineno; 
                                                        print_token(RELOP); 
                                                        return RELOP; 
                                                      }
"\*\*"                  { yylval.s_attrs.line_counter = yylineno; print_token(POWEROP); return POWEROP; }
"\+"|"\-"               { yylval.s_attrs.stringValue = strdup(yytext); 
                          yylval.s_attrs.line_counter = yylineno; 
                          print_token(ADDOP); 
                          return ADDOP; 
                        }
"\*"                    { yylval.s_attrs.line_counter = yylineno; print_token(MULOP); return MULOP; }
"\/"                    { yylval.s_attrs.line_counter = yylineno; print_token(DIVOP); return DIVOP; }
"\("                    { yylval.s_attrs.line_counter = yylineno; print_token(LPAREN); return LPAREN; }
"\)"                    { yylval.s_attrs.line_counter = yylineno; print_token(RPAREN); return RPAREN; }
"\,"                    { print_token(COMMA); return COMMA; }
"="                     {  yylval.s_attrs.line_counter = yylineno; print_token(ASSIGN); return ASSIGN; }
":"                     { print_token(COLON); return COLON; }
"\["                    { yylval.s_attrs.line_counter = yylineno; print_token(LBRACK); return LBRACK; }
"\]"                    { print_token(RBRACK); return RBRACK; }

.                       { 
                          /* 
                          ΕΝΤΟΠΙΣΜΟΣ ΛΑΘΟΥΣ ΓΙΑ ΟΠΟΙΟΝΔΗΠΟΤΕ ΛΑΝΘΑΣΜΕΝΟ ΧΑΡΑΚΤΗΡΑ 
                          ΑΦΟΥ ΔΕΝ ΥΠΑΡΧΕΙ ΕΝΤΟΛΗ RETURN ΑΥΤΟΜΑΤΑ ΤΟ FLEX ΤΟΝ ΑΓΝΟΕΙ
                          ΔΗΛΑΔΗ ΤΟΝ ΔΙΑΓΡΑΦΕΙ ΚΑΙ ΣΥΝΕΧΙΖΕΙ ΤΗΝ ΑΝΑΛΥΣΗ 
                          */
                          printf("Lexical error found!\n");
                          printf("Unrecognized character %s at line %d.\n", yytext, yylineno);
                          printf("Line that contains the error: %s\n", line_buffer);
                          printf("-------------------------------------------------------------------\n");
                        }

%%
