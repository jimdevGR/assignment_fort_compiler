%{ // ΤΜΗΜΑ ΟΡΙΣΜΩΝ C

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "types.h"
#include "symbol_table.h"
#include "ast.h"

// ΣΥΝΑΡΤΗΣΕΙΣ ΚΑΙ ΜΕΤΑΒΛΗΤΕΣ ΠΟΥ ΘΑ ΧΡΗΣΙΜΟΠΟΙΗΘΟΥΝ
extern FILE* yyin;
extern int yylex();
extern char* yytext;
extern int yylineno;
extern char line_buffer[];
int error_counter = 0; // ΜΕΤΡΗΤΗΣ ΣΦΑΛΜΑΤΩΝ
void yyerror(const char* message);
void semantic_error(const char* message, int line_error_occured, char* variable_name);
int type_match(fort_types type1, fort_types type2);
char* type_conversion(char* src_value, fort_types src_type, fort_types dest_type);
array_init_node* array_initialization(symbol_node* sym_node, array_init_node* temp_list, int line);

// ΚΑΘΟΛΙΚΕΣ ΜΕΤΑΒΛΗΤΕΣ - ΜΥΝΗΜΑΤΑ ΠΟΥ ΤΥΠΩΝΕΙ Η semantic_error
const char* dup_msg = "-Duplicate id's in the same scope-";
const char* array_list_msg = "-Variable is both a list and array-";
const char* undefined_msg = "-Id's you use must be previously defined-";
const char* no_params_func_msg = "-Function cannnot be without parameters-";
const char* no_string_msg = "-Function return type cannot be a string-";
const char* type_string_list_msg = "-List cannot be of type STRING-";
const char* undefined_label_msg = "-Every label must be defined somewhere in the code-";
const char* dup_labels_msg = "-You cannot define the same label 2 times in the same scope-";
const char* no_label_msg = "-ID on a labeled statement must be of category label-";
const char* list_init_msg = "-Cannot assign initial value to a LIST variable-";
const char* type_mismatch_msg = "-Type mismatch in data initialization-";
const char* invalid_sign_msg = "-Sign (+/-) is only allowed for numeric types-";
const char* too_big_string_msg = "-String constant cannot be bigger than 255 characters-";
const char* scoped_data_common_decl_msg = "-You cannot assign valaue/s to variables or define a common block inside an inner scope-";
const char* multi_asterisk_use_msg = "-Only one '*' without repeat factor is allowed per array initialization-";
const char* no_virtual_dim_msg = "-Array that is declared as a variable cannot have virtual dimensions-";

%}

// ΤΜΗΜΑ ΡΥΘΜΙΣΕΩΝ-ΟΡΙΣΜΩΝ ΕΡΓΑΛΕΙΟΥ bison

// ΕΠΙΛΟΓΗ ΓΙΑ ΠΙΟ ΑΝΑΛΥΤΙΚΑ ΜΥΝΗΜΑΤΑ ΣΦΑΛΜΑΤΩΝ
%define parse.error verbose

/* 
ΟΡΙΣΜΟΣ ΚΑΘΟΛΙΚΗΣ ΜΕΤΑΒΛΗΤΗΣ yylval 
Union ΟΠΟΥ ΑΠΟΘΗΚΕΥΕΤΑΙ ΤΟ ΠΕΡΙΕΧΟΜΕΝΟ ΜΙΑΣ ΛΕΚΤΙΚΗΣ ΜΟΝΑΔΑΣ 
ΚΑΘΕ ΛΕΚΤΙΚΗ ΜΟΝΑΔΑ ΠΕΙΡΓΡΑΦΕΤΑΙ ΑΠΟ ΤΑ ΚΑΤΗΓΟΡΗΜΑΤΑ ΜΕΣΑ ΣΤΟ s_attrs struct
*/
%union {
    semantic_attributes s_attrs;
}

%token END_OF_FILE 0

%token FUNCTION 
%token SUBROUTINE 
%token END 
%token <s_attrs> COMMON 
%token <s_attrs> INTEGER 
%token <s_attrs> REAL 
%token <s_attrs> COMPLEX 
%token <s_attrs> LOGICAL 
%token <s_attrs> CHARACTER 
%token <s_attrs> STRING 
%token LIST 
%token <s_attrs> DATA 
%token <s_attrs> CONTINUE 
%token GOTO 
%token CALL 
%token READ 
%token WRITE 
%token LENGTH 
%token IF 
%token THEN 
%token ELSE 
%token ENDIF 
%token DO 
%token ENDDO 
%token <s_attrs> STOP 
%token <s_attrs> RETURN 

%token <s_attrs> ID 
%token <s_attrs> ICONST 
%token <s_attrs> RCONST 
%token <s_attrs> LCONST 
%token <s_attrs> CCONST 
%token <s_attrs> SCONST 
%token <s_attrs> LISTFUNC 

%token <s_attrs> OROP 
%token <s_attrs> ANDOP 
%token <s_attrs> NOTOP 
%token <s_attrs> RELOP 
%token <s_attrs> ADDOP 
%token <s_attrs> MULOP 
%token <s_attrs> DIVOP 
%token <s_attrs> POWEROP 

%token <s_attrs> LPAREN 
%token <s_attrs> RPAREN
%token COMMA 
%token <s_attrs> ASSIGN 
%token COLON 
%token <s_attrs> LBRACK
%token RBRACK

%type <s_attrs> program body declarations type vars undef_variable listspec dims dim cblock_list array_tail subroutine_params
%type <s_attrs> cblock id_list vals value_list values value repeat sign constant simple_constant complex_constant 
%type <s_attrs> statements labeled_statement label statement simple_statement assignment variable expressions expression listexpression 
%type <s_attrs> goto_statement labels if_statement subroutine_call io_statement read_list read_item iter_space step write_list write_item 
%type <s_attrs> compound_statement branch_statement tail loop_statement subprograms subprogram header formal_parameters 
%type <s_attrs> inner_body // ΜΗ ΤΕΡΜΑΤΙΚΟ ΣΥΜΒΟΛΟ ΠΟΥ ΚΑΤΑΣΚΕΥΑΣΤΗΚΕ ΓΙΑ ΤΙΣ ΑΝΑΓΚΕΣ ΤΟΥ ΜΕΤΑΓΛΩΤΤΙΣΤΗ ΚΑΙ ΔΕΝ ΥΠΗΡΧΕ ΣΤΗΝ ΕΚΦΩΝΙΣΗ

// ΑΡΧΙΚΟ ΣΥΜΒΟΛΟ ΓΡΑΜΜΑΤΙΚΗΣ
%start program

// ΟΡΙΣΜΟΣ ΠΡΟΤΕΡΑΙΟΤΗΤΑΣ - ΠΡΟΣΕΤΑΙΡΙΣΤΙΚΟΤΗΤΑΣ ΤΩΝ ΤΕΛΕΣΤΩΝ
%left OROP
%left ANDOP
%nonassoc NOTOP // ΚΑΜΙΑ ΠΡΟΣΕΤΑΙΡΙΣΤΙΚΟΤΗΤΑ, ΔΕΝ ΕΠΙΤΡΕΠΟΝΤΑΙ ΔΙΑΔΟΧΙΚΕΣ ΕΦΑΡΜΟΓΕΣ ΤΕΛΕΣΤΗ ΧΩΡΙΣ ΠΡΟΣΕΤΑΙΡΙΣΤΙΚΟΤΗΤΑ ΣΤΗΝ ΙΔΙΑ ΕΚΦΡΑΣΗ
%nonassoc RELOP
%left ADDOP
%left MULOP DIVOP
%right POWEROP
%nonassoc UMINUS // ΤΕΛΕΣΤΗΣ ΓΙΑ ΤΟ ΠΡΟΣΗΜΟ (-)

%% // ΤΜΗΜΑ ΣΥΝΤΑΚΤΙΚΩΝ ΚΑΝΟΝΩΝ ΚΑΙ ΕΝΕΡΓΕΙΩΝ

/* 
ΥΛΟΠΟΙΕΙΤΑΙ Η ΜΕΘΟΔΟΣ ΠΑΝΙΚΟΥ ΔΗΛΑΔΗ ΔΙΑΓΡΑΦΕΤΑΙ ΟΛΗ Η ΛΑΝΘΑΣΜΕΝΗ ΓΡΑΜΜΗ/ΜΠΛΟΚ ΚΑΙ Η ΑΝΑΛΥΣΗ ΣΥΝΕΧΙΖΕΙ ΑΠΟ ΤΟ ΣΥΜΒΟΛΟ ΣΥΓΧΡΟΝΙΣΜΟΥ 
ΥΛΟΠΟΙΗΘΗΚΑΝ ΚΑΙ ΜΕΡΙΚΑ ΠΑΡΑΔΕΙΓΜΑΤΑ (ΟΧΙ ΟΛΑ ΕΙΝΑΙ ΠΑΡΑ ΠΟΛΛΑ) ΚΑΝΟΝΩΝ ΠΑΡΑΓΩΓΗΣ ΚΟΙΝΟΥ ΣΦΑΛΜΑΤΟΣ ΣΤΑ ΟΠΟΙΑ ΑΓΝΟΕΙΤΑΙ ΑΠΛΑ 
Ο ΛΑΝΘΑΣΜΕΝΟΣ ΧΑΡΑΚΤΗΡΑΣ ΚΑΙ ΣΥΝΕΧΙΖΕΤΑΙ Η ΑΝΑΛΥΣΗ KANONIKA 
*/
                                                                                    // ΧΤΙΣΙΜΟ ΟΛΟΚΛΗΡΟΥ ΤΟΥ ΔΕΝΔΡΟΥ ΓΙΑ ΤΟ ΠΡΟΓΡΑΜΜΑ, ΕΧΕΙ 2 ΠΑΙΔΙΑ ΤΟ ΚΥΡΙΩΣ ΣΩΜΑ ΚΑΙ ΤΑ ΥΠΟΠΡΟΓΡΑΜΜΑΤΑ 
program:            body END subprograms                                           { $$.ast_node = make_ast_node(AST_PROGRAM, 1, NULL, 2, $1.ast_node, $3.ast_node);
                                                                                     exit_print_scope();   
                                                                                     printf("---------------------------------------------------\n");
                                                                                     printf("***************AST FOR MAIN PROGRAM****************\n");
                                                                                     printf("---------------------------------------------------\n");
                                                                                     print_ast($$.ast_node, 0); // ΤΥΠΩΝΟΥΜΕ ΤΟ ΔΕΝΔΡΟ ΓΙΑ ΟΛΟ ΤΟ ΠΡΟΓΡΑΜΜΑ 
                                                                                   }  

                    | error END                                                    { yyerrok; } // ΜΕΘΟΔΟΣ ΠΑΝΙΚΟΥ ΓΙΑ ΤΟ ΣΩΜΑ ΤΗΣ ΚΥΡΙΑΣ ΜΟΝΑΔΑΣ, ΚΑΛΥΠΤΕΙ ΑΠΛΑ ΛΑΝΘΑΣΜΕΝΑ statements
                    subprograms                                                    { exit_print_scope(); $$.ast_node = NULL; }                           
                    ;

// ΜΕΤΑΦΟΡΑ ΣΗΜΑΙΑΣ ΚΑΙ ΓΡΑΜΜΗΣ ΣΤΟ body, ΕΤΣΙ ΓΝΩΡΙΖΕΙ ΠΛΕΟΝ ΑΝ ΠΕΡΙΕΧΕΙ ΚΑΠΟΥ ΜΕΣΑ ΤΟΥ ΔΗΛΩΣΗ ΤΥΠΟΥ DATA Ή ΔΗΛΩΣΗ ΚΟΙΝΗΣ ΠΕΡΙΟΧΗΣ                              
body:               declarations statements                                        { $$.dataORcommon_declaration = $1.dataORcommon_declaration; 
                                                                                     $$.line_counter = $1.line_counter;
                                                                                     $$.ast_node = $2.ast_node;
                                                                                   }
                    ;

// -ΝΕΟΣ- ΚΑΝΟΝΑΣ ΓΙΑ ΤΙΣ ΔΟΜΗΜΕΝΕΣ ΕΝΤΟΛΕΣ, ΜΕ ΣΚΟΠΟ ΝΑ ΣΤΑΜΑΤΑΕΙ Η ΕΚΤΕΛΕΣΗ ΟΤΑΝ ΤΕΛΕΙΩΣΟΥΝ ΤΑ declarations KAI ΕΜΦΑΝΙΣΤΕΙ ΑΠΟΔΟΣΗ ΤΙΜΩΝ Ή ΑΡΧΙΚΟΠΟΙΗΣΗ ΚΟΙΝΩΝ ΠΕΡΙΟΧΩΝ ΣΕ ΑΥΤΕΣ
inner_body:         declarations                                                   { if ($1.dataORcommon_declaration == 1) 
                                                                                        semantic_error(scoped_data_common_decl_msg, $1.line_counter, NULL);
                                                                                   }
                    statements                                                     { $$.ast_node = $3.ast_node; }
                    | error                                                        { yyerrok; $$.ast_node = NULL;}
                    ;
                                                                                   // ΤΕΛΙΚΕΣ ΤΡΟΠΟΠΟΙΗΣΕΙΣ ID ΚΑΤΗΓΟΡΙΑΣ VARIABLE
declarations:       declarations type vars                                         { symbol_node* temp = $3.sym_node_list;
                                                                                     while (temp != NULL) {
                                                                                       // ΛΙΣΤΕΣ ΔΕΝ ΕΠΙΤΡΕΠΕΤΑΙ ΝΑ ΕΙΝΑΙ ΤΥΠΟΥ string
                                                                                       if (temp->is_list == 1 && $2.id_type == TYPE_STRING) {
                                                                                          char* false_type = "STRING";
                                                                                          semantic_error(type_string_list_msg, $2.line_counter, false_type);
                                                                                       }
                                                                                       else if (temp->is_array == 1 && temp->virtual_dim == 1) { // ΔΕΝ ΕΠΙΤΡΕΠΟΝΤΑΙ ΜΕΤΑΒΛΗΤΕΣ ΠΙΝΑΚΕΣ ΜΕ ΕΙΚΟΝΙΚΕΣ ΔΙΑΣΤΑΣΕΙΣ
                                                                                        semantic_error(no_virtual_dim_msg, $2.line_counter, NULL);
                                                                                       }
                                                                                       else {
                                                                                         temp->id_type = $2.id_type;
                                                                                         temp->category = VAR;
                                                                                         temp = temp->temp_next;
                                                                                       }                                                                                                                                         
                                                                                     }
                                                                                     $$.dataORcommon_declaration = $1.dataORcommon_declaration; 
                                                                                     $$.line_counter = $1.line_counter;
                                                                                   }

                    | declarations type error                                      { yyerrok; 
                                                                                     $$.dataORcommon_declaration = $1.dataORcommon_declaration; 
                                                                                     $$.line_counter = $1.line_counter;
                                                                                   }
                                                                                   
                    | declarations COMMON cblock_list                              { if ($1.dataORcommon_declaration == 0) {
                                                                                        $1.dataORcommon_declaration = 1;
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $2.line_counter;
                                                                                     } 
                                                                                     else {
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $1.line_counter;
                                                                                     }
                                                                                   }

                    | declarations COMMON error                                    { yyerrok;
                                                                                     if ($1.dataORcommon_declaration == 0) {
                                                                                        $1.dataORcommon_declaration = 1;
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $2.line_counter;
                                                                                     } 
                                                                                     else {
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $1.line_counter;
                                                                                     }
                                                                                   }                        

                                                                                   // ΑΝ ΣΥΝΑΝΤΑΤΑΙ ΠΡΩΤΗ ΦΟΡΑ ΔΗΛΩΣΗ ΑΠΟΔΟΣΗΣ ΤΙΜΩΝ ΓΙΑ ΤΗΝ ΤΩΡΙΝΗ ΕΜΒΕΛΕΙΑ ΚΑΝΟΥΜΕ ΤΗΝ ΣΗΜΑΙΑ 1 ΚΑΙ ΑΠΟΘΗΚΕΥΟΥΜΕ ΚΑΙ ΤΗΝ ΓΡΑΜΜΗ ΕΜΦΑΝΙΣΗΣ
                    | declarations DATA vals                                       { if ($1.dataORcommon_declaration == 0) {
                                                                                        $1.dataORcommon_declaration = 1;
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $2.line_counter;
                                                                                     }
                                                                                     else { // Η ΣΗΜΑΙΑ ΕΙΝΑΙ ΗΔΗ 1
                                                                                      $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                      $$.line_counter = $1.line_counter; // ΠΕΡΝΑΜΕ ΑΡΙΣΤΕΡΑ ΤΗΝ ΓΡΑΜΜΗ ΤΗΣ ΠΡΩΤΗΣ ΕΜΦΑΝΙΣΗΣ ΑΠΟΔΟΣΗΣ ΑΡΧΙΚΩΝ ΤΙΜΩΝ Ή ΔΗΛΩΣΗΣ ΚΟΙΝΗΣ ΠΕΡΙΟΧΗΣ
                                                                                     }
                                                                                   }

                    | declarations DATA error                                      { yyerrok;
                                                                                     if ($1.dataORcommon_declaration == 0) {
                                                                                        $1.dataORcommon_declaration = 1;
                                                                                        $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                        $$.line_counter = $2.line_counter;
                                                                                     }
                                                                                     else { 
                                                                                      $$.dataORcommon_declaration = $1.dataORcommon_declaration;
                                                                                      $$.line_counter = $1.line_counter; 
                                                                                     }
                                                                                   }                                     

                    | %empty                                                       { $$ = (semantic_attributes){0}; } // ΑΡΧΙΚΟΠΟΙΗΣΗ struct ΚΑΤΗΓΟΡΗΜΑΤΩΝ ΜΕ Ο ΚΑΙ NULL
                    ;

type:               INTEGER                                                        { $$.id_type = TYPE_INTEGER; $$.line_counter = $1.line_counter; }
                    | REAL                                                         { $$.id_type = TYPE_REAL; $$.line_counter = $1.line_counter; }
                    | COMPLEX                                                      { $$.id_type = TYPE_COMPLEX; $$.line_counter = $1.line_counter; }
                    | LOGICAL                                                      { $$.id_type = TYPE_LOGICAL; $$.line_counter = $1.line_counter; }
                    | CHARACTER                                                    { $$.id_type = TYPE_CHARACTER; $$.line_counter = $1.line_counter; }
                    | STRING                                                       { $$.id_type = TYPE_STRING; $$.line_counter = $1.line_counter; }
                    ;

vars:                vars COMMA undef_variable                                     { // ΕΝΩΣΗ ΤΩΝ ΜΕΤΑΒΛΗΤΩΝ ΣΕ ΜΙΑ ΕΝΝΙΑΙΑ ΑΛΥΣΙΔΑ
                                                                                     symbol_node* temp = $1.sym_node_list; // ΠΑΙΡΝΟΥΜΕ ΤΗΝ ΜΕΧΡΙ ΤΩΡΑ ΑΛΥΣΙΔΑ
                                                                                     // ΨΑΧΝΟΥΜΕ ΤΟ ΤΕΛΟΣ ΤΗΣ ΑΛΥΣΙΔΑΣ
                                                                                     while(temp != NULL && temp->temp_next != NULL) temp = temp->temp_next;
                                                                                     temp->temp_next = $3.sym_node_list; // ΕΙΣΟΔΟΣ ΝΕΟΥ ΚΟΜΒΟΥ ΣΤΟ ΤΕΛΟ ΤΗΣ ΛΙΣΤΑΣ
                                                                                     $$.sym_node_list = $1.sym_node_list; // ΜΕΤΑΦΟΡΑ ΕΝΑ ΕΠΙΠΕΔΟ ΠΑΝΩ
                                                                                   }

                    | undef_variable                                               { $$.sym_node_list = $1.sym_node_list; }
                    ;
                                                                                    // ΑΝ ΔΕΝ ΕΠΙΣΤΡΑΦΕΙ NULL, ΔΙΠΛΟΤΥΠΟ, ΣΗΜΑΣΙΟΛΟΓΙΚΟ ΣΦΑΛΜΑ
undef_variable:     listspec ID array_tail                                         { symbol_node* sym_node = search_current_scope($2.stringValue);
                                                                                     if (sym_node == NULL) {
                                                                                        // ΕΛΕΓΧΟΣ ΑΝ Η ΜΕΤΑΒΛΗΤΗ ΕΧΕΙ ΔΗΛΩΘΕΙ ΚΑΙ ΩΣ ΛΙΣΤΑ ΚΑΙ ΩΣ ΠΙΝΑΚΑΣ
                                                                                        if ($1.is_list == 1 && $3.dim_count > 0) semantic_error(array_list_msg, $2.line_counter, $2.stringValue);
                                                                                        sym_node = insert_new_symbol($2.stringValue, $2.line_counter);
                                                                                        // ΕΝΗΜΕΡΩΣΗ ΤΩΝ flags
                                                                                        sym_node->is_list = $1.is_list;
                                                                                        sym_node->is_array = ($3.dim_count) > 0 ? 1 : 0;
                                                                                        sym_node->virtual_dim = $3.virtual_dim;
                                                                                        // ΠΕΡΝΑΜΕ ΤΟΝ ΚΟΜΒΟ "ΠΑΝΩ" ΣΤΟ undef_variable
                                                                                        $$.sym_node_list = sym_node;
                                                                                        sym_node->temp_next = NULL; // ΓΙΑ ΤΗΝ ΣΥΝΔΕΣΗ ΣΤΗΝ ΠΡΟΣΩΡΙΝΗ ΛΙΣΤΑ
                                                                                     }
                                                                                     else semantic_error(dup_msg, $2.line_counter, $2.stringValue);
                                                                                   }                                                                                                                                                                                                                             
                    ; 

array_tail:         LPAREN dims RPAREN                                             { $$.dim_count = $2.dim_count; 
                                                                                     $$.virtual_dim = $2.virtual_dim; 
                                                                                   }
                                                                                   
                    | LPAREN dims error RPAREN                                     { yyerrok; // ΑΠΛΑ ΑΓΝΟΕΙΤΑΙ Ο ΛΑΝΘΑΣΜΕΝΟΣ ΧΑΡΑΚΤΗΡΑΣ ΚΑΙ ΣΥΝΕΧΙΖΕΤΑΙ Η ΑΝΑΛΥΣΗ
                                                                                     $$.dim_count = $2.dim_count; 
                                                                                     $$.virtual_dim = $2.virtual_dim; 
                                                                                   }

                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ;

listspec:           LIST                                                           { $$.is_list = 1; }
                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ;
 
dims:               dims COMMA dim                                                 { $$.dim_count = $1.dim_count + 1; $$.virtual_dim = $1.virtual_dim || $3.virtual_dim; }
                    | dim                                                          { $$.dim_count = 1; $$.virtual_dim = $1.virtual_dim; }
                    ;  

dim:                ICONST                                                         { $$.virtual_dim = 0; }
                    | ID                                                           { $$.virtual_dim = 1; }
                    ;

cblock_list:        cblock_list cblock 
                    | cblock                                                      
                    ;

cblock:             DIVOP ID DIVOP id_list                                         { symbol_node* sym_node = search_current_scope($2.stringValue);
                                                                                     if (sym_node == NULL) {
                                                                                        sym_node = insert_new_symbol($2.stringValue, $2.line_counter); 
                                                                                        sym_node->category = COMMON_BLOCK;
                                                                                     }
                                                                                     else semantic_error(dup_msg, $2.line_counter, $2.stringValue);
                                                                                   } 

                    | DIVOP ID error id_list                                       { yyerrok;
                                                                                     symbol_node* sym_node = search_current_scope($2.stringValue);
                                                                                     if (sym_node == NULL) {
                                                                                        sym_node = insert_new_symbol($2.stringValue, $2.line_counter); 
                                                                                        sym_node->category = COMMON_BLOCK;
                                                                                     }
                                                                                     else semantic_error(dup_msg, $2.line_counter, $2.stringValue);
                                                                                   }                                                                     
                    ;
                                                                                   // ΕΛΕΓΧΟΣ ΑΝ ΕΧΟΥΝΝ ΔΗΛΩΘΕΙ ΝΩΡΙΤΕΡΑ ΤΑ ΑΝΑΓΝΩΡΙΣΤΙΚΑ ΤΟΥ COMMON BLOCK
id_list:            id_list COMMA ID                                               { symbol_node* sym_node = search_current_scope($3.stringValue);
                                                                                     if (sym_node == NULL) semantic_error(undefined_msg, $3.line_counter, $3.stringValue);
                                                                                   }          

                    | ID                                                           { symbol_node* sym_node = search_current_scope($1.stringValue);
                                                                                     if (sym_node == NULL) semantic_error(undefined_msg, $1.line_counter, $1.stringValue);
                                                                                   }
                    ;
                                                                                   // ΤΑ ΑΝΑΓΝΩΡΙΣΤΙΚΑ ΣΕ ΔΗΛΩΣΗ ΑΠΟΔΟΣΗΣ ΑΡΧΙΚΩΝ ΤΙΜΩΝ ΠΡΕΠΕΙ ΝΩΡΙΤΕΡΑ ΝΑ ΕΧΟΥΝ ΔΗΛΩΘΕΙ
vals:               vals COMMA ID value_list                                       { symbol_node* sym_node = search_current_scope($3.stringValue);
                                                                                     if (sym_node == NULL) semantic_error(undefined_msg, $3.line_counter, $3.stringValue);
                                                                                     if (sym_node->is_list == 1) semantic_error(list_init_msg, $3.line_counter, $3.stringValue); // ΔΕΝ ΕΠΙΤΡΕΠΕΤΑΙ ΑΝΑΘΕΣΗ ΣΕ ΛΙΣΤΑ
                                                                                     if (sym_node->is_array == 0) { // ΑΝ ΔΕΝ ΕΙΝΑΙ ΠΙΝΑΚΑΣ ΚΑΤΑ ΤΗΝ ΑΝΑΘΕΣΗ
                                                                                        if (type_match(sym_node->id_type, $4.temp_array_val_list->type) == 0) semantic_error(type_mismatch_msg, $3.line_counter, $4.temp_array_val_list->array_value); 
                                                                                        else sym_node->init_value = type_conversion($4.temp_array_val_list->array_value, $4.temp_array_val_list->type, sym_node->id_type);
                                                                                        array_init_node* curr = $4.temp_array_val_list->array_next;
                                                                                        while (curr != NULL) { // ΑΠΟΔΕΥΜΕΥΣΗ ΥΠΟΛΟΙΠΩΝ ΚΟΜΒΩΝ ΠΡΟΣΩΡΙΝΗΣ ΛΙΣΤΑΣ, ΣΕ ΒΑΘΜΩΤΕΣ ΜΕΤΑΒΛΗΤΕΣ ΜΑΣ ΝΟΙΑΖΕΙ ΜΟΝΟ Η ΠΡΩΤΗ ΤΙΜΗ
                                                                                          array_init_node* del = curr;
                                                                                          curr = curr->array_next;
                                                                                          free(del->array_value);
                                                                                          free(del);
                                                                                        }
                                                                                        free($4.temp_array_val_list); // ΑΠΟΔΕΥΜΕΥΣΗ ΑΡΧΙΚΟΥ ΣΤΟΙΧΕΙΟΥ ΛΙΣΤΑΣ
                                                                                     }
                                                                                     // ΑΝ ΕΙΝΑΙ ΠΙΝΑΚΑΣ ΚΑΛΟΥΜΕ ΤΗΝ ΑΝΑΛΟΓΗ ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΑΝΑΘΕΣΗ
                                                                                     else sym_node->array_init_values = array_initialization(sym_node, $4.temp_array_val_list, $3.line_counter);
                                                                                   }
                    
                    | ID value_list                                                { symbol_node* sym_node = search_current_scope($1.stringValue);
                                                                                     if (sym_node == NULL) semantic_error(undefined_msg, $1.line_counter, $1.stringValue);
                                                                                     if (sym_node->is_list == 1) semantic_error(list_init_msg, $1.line_counter, $1.stringValue); 
                                                                                     if (sym_node->is_array == 0) { // ΑΝ ΔΕΝ ΕΙΝΑΙ ΠΙΝΑΚΑΣ ΚΑΤΑ ΤΗΝ ΑΝΑΘΕΣΗ
                                                                                        if (type_match(sym_node->id_type, $2.temp_array_val_list->type) == 0) semantic_error(type_mismatch_msg, $1.line_counter, $2.temp_array_val_list->array_value); 
                                                                                        else sym_node->init_value = type_conversion($2.temp_array_val_list->array_value, $2.temp_array_val_list->type, sym_node->id_type);
                                                                                        array_init_node* curr = $2.temp_array_val_list->array_next;
                                                                                        while (curr != NULL) { // ΑΠΟΔΕΥΜΕΥΣΗ ΥΠΟΛΟΙΠΩΝ ΚΟΜΒΩΝ ΠΡΟΣΩΡΙΝΗΣ ΛΙΣΤΑΣ, ΣΕ ΒΑΘΜΩΤΕΣ ΜΕΤΑΒΛΗΤΕΣ ΜΑΣ ΝΟΙΑΖΕΙ ΜΟΝΟ Η ΠΡΩΤΗ ΤΙΜΗ
                                                                                          array_init_node* del = curr;
                                                                                          curr = curr->array_next;
                                                                                          free(del->array_value);
                                                                                          free(del);
                                                                                        }
                                                                                        free($2.temp_array_val_list);
                                                                                     }
                                                                                     // ΑΝ ΕΙΝΑΙ ΠΙΝΑΚΑΣ ΚΑΛΟΥΜΕ ΤΗΝ ΑΝΑΛΟΓΗ ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΑΝΑΘΕΣΗ
                                                                                     else sym_node->array_init_values = array_initialization(sym_node, $2.temp_array_val_list, $1.line_counter);                              
                                                                                   }                           
                    ;

value_list:         DIVOP values DIVOP                                             { $$.temp_array_val_list = $2.temp_array_val_list; }
                    | error values DIVOP                                           { yyerrok; $$.temp_array_val_list = $2.temp_array_val_list; } 
                    ;

// ΧΤΙΖΟΥΜΕ ΤΗΝ ΠΡΟΣΩΡΙΝΗ ΛΙΣΤΑ ΤΩΝ ΑΡΧΙΚΩΝ ΤΙΜΩΝ
values:             values COMMA value                                             { array_init_node* temp_node = (array_init_node*)malloc(sizeof(array_init_node));
                                                                                     temp_node->array_value = $3.stringValue;
                                                                                     temp_node->type = $3.id_type;
                                                                                     temp_node->repeat_count = $3.repeat_count;
                                                                                     temp_node->plain_asterisk = $3.plain_asterisk;
                                                                                     temp_node->array_next = NULL;
                                                                                     array_init_node* temp_list = $1.temp_array_val_list;
                                                                                     while (temp_list->array_next != NULL) temp_list = temp_list->array_next; // ΕΥΡΕΣΗ ΤΗΣ ΟΥΡΑΣ ΤΗΣ ΠΡΟΣΩΡΙΝΗΣ ΛΙΣΤΑΣ
                                                                                     temp_list->array_next = temp_node; // ΤΟΠΟΘΕΤΗΣΗ ΝΕΟΥ ΚΟΜΒΟΥ ΣΤΟ ΤΕΛΟΣ
                                                                                     $$.temp_array_val_list = $1.temp_array_val_list; // ΕΠΙΣΤΡΕΦΟΥΜΕ ΤΗΝ ΚΕΦΑΛΗ ΤΗΣ ΛΙΣΤΑΣ                                  
                                                                                   }
                                                                                   
                                                                                   // ΚΑΤΑΣΚΕΥΗ ΚΟΜΒΟΥ ΠΡΟΣΩΡΙΝΗΣ ΛΙΣΤΑΣ ΤΙΜΩΝ ΚΑΙ ΠΕΡΑΣΜΑ ΑΡΙΣΤΕΡΑ
                    | value                                                        { array_init_node* temp_node = (array_init_node*)malloc(sizeof(array_init_node));
                                                                                     temp_node->array_value = $1.stringValue;
                                                                                     temp_node->type = $1.id_type;
                                                                                     temp_node->repeat_count = $1.repeat_count;
                                                                                     temp_node->plain_asterisk = $1.plain_asterisk;
                                                                                     temp_node->array_next = NULL;
                                                                                     $$.temp_array_val_list = temp_node;
                                                                                   }
                    ;

value:              repeat sign constant                                           { if ($2.stringValue != NULL && ($3.id_type == TYPE_LOGICAL || $3.id_type == TYPE_CHARACTER || $3.id_type == TYPE_STRING)) {
                                                                                        semantic_error(invalid_sign_msg, $3.line_counter, $3.stringValue);
                                                                                     }
                                                                                     if ($2.stringValue != NULL) { // ΑΝ ΕΧΟΥΜΕ ΠΡΟΣΗΜΟ
                                                                                        char str_temp[128];
                                                                                        sprintf(str_temp, "%s%s", $2.stringValue, $3.stringValue); // ΔΗΜΙΟΥΡΓΙΑ ΝΕΟΥ string 
                                                                                        $$.stringValue = strdup(str_temp);
                                                                                        free($2.stringValue); // ΑΠΕΛΕΥΘΕΡΩΣΗ ΤΩΝ ΠΑΛΙΩΝ string, ΔΕΝ ΧΡΕΙΑΖΟΝΤΑΙ ΠΛΕΟΝ
                                                                                        free($3.stringValue);
                                                                                     }
                                                                                     else $$.stringValue = $3.stringValue;
                                                                                     $$.id_type = $3.id_type;
                                                                                     // ΕΝΣΩΜΑΤΩΣΗ ΤΙΜΩΝ ΕΠΑΝΑΛΗΨΗΣ
                                                                                     $$.repeat_count = $1.repeat_count;
                                                                                     $$.plain_asterisk = $1.plain_asterisk;
                                                                                   }

                    | ADDOP constant                                               { // ΔΕΝ ΕΠΙΤΡΕΠΕΤΑΙ ΠΡΟΣΗΜΟ ΣΕ ΜΗ ΑΡΙΘΜΗΤΙΚΕΣ ΣΤΑΘΕΡΕΣ
                                                                                     if ($1.stringValue != NULL && ($2.id_type == TYPE_LOGICAL || $2.id_type == TYPE_CHARACTER || $2.id_type == TYPE_STRING)) {
                                                                                        semantic_error(invalid_sign_msg, $1.line_counter, $1.stringValue);
                                                                                     }
                                                                                     char str_temp[128];
                                                                                     sprintf(str_temp, "%s%s", $1.stringValue, $2.stringValue); // ΠΡΟΣΘΕΤΟΥΜΕ ΚΑΙ ΤΟ ΠΡΟΣΗΜΟ ΣΤΟ string
                                                                                     $$.stringValue = strdup(str_temp);
                                                                                     $$.id_type = $2.id_type;
                                                                                     $$.repeat_count = 0;
                                                                                     $$.plain_asterisk = 0;
                                                                                     free($2.stringValue); // ΔΙΑΓΡΑΦΟΥΜΕ ΤΟ ΠΑΛΙΟ ΑΝΤΙΓΡΑΦΟ ΓΙΑΤΙ ΦΤΙΑΞΑΜΕ ΝΕΟ
                                                                                   }
                                                
                    | constant                                                     { $$.stringValue = $1.stringValue; 
                                                                                     $$.id_type = $1.id_type; 
                                                                                     $$.repeat_count = 0;
                                                                                     $$.plain_asterisk = 0;
                                                                                   }
                    ;
                                                                                   // ΕΝΗΜΕΡΩΝΟΥΜΕ ΤΑ ΠΕΔΙΑ ΕΠΑΝΑΛΗΨΗΣ ΚΑΙ ΤΑ ΠΕΡΝΑΜΕ ΑΡΙΣΤΕΡΑ
repeat:             ICONST MULOP                                                   { $$.repeat_count = $1.intValue; $$.plain_asterisk = 0; }
                    | MULOP                                                        { $$.repeat_count = 0; $$.plain_asterisk = 1; }
                    ;

sign:               ADDOP                                                          { $$.stringValue = $1.stringValue; }
                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ;
                                                                                   // ΠΕΡΝΑΜΕ ΑΚΟΜΑ ΠΙΟ ΠΑΝΩ ΤΙΜΕΣ ΚΑΙ ΤΥΠΟΥΣ
constant:           simple_constant                                                { $$.stringValue = $1.stringValue; $$.id_type = $1.id_type; }
                    | complex_constant                                             { $$.stringValue = $1.stringValue; $$.id_type = $1.id_type; }
                    ;

// ΠΕΡΝΑΜΕ ΤΙΜΕΣ ΚΑΙ ΤΥΠΟΥΣ ΠΙΟ "ΠΑΝΩ" ΓΙΑ ΝΑ ΕΛΕΓΞΟΥΜΕ ΤΗΝ ΣΥΜΒΑΤΟΤΗΤΑ ΤΩΝ ΤΥΠΩΝ ΚΑΤΑ ΤΗΝ ΑΝΑΘΕΣΗ ΑΡΧΙΚΩΝ ΤΙΜΩΝ
simple_constant:    ICONST                                                         { char str_temp[64]; // ΠΙΝΑΚΑΣ ΟΠΟΥ ΘΑ ΑΠΟΘΗΚΕΥΤΕΙ ΠΡΟΣΩΡΙΝΑ Η ΤΙΜΗ, ΠΑΝΤΑ ΣΕ ΜΟΡΦΗ string
                                                                                     sprintf(str_temp, "%d", $1.intValue); // ΜΕΤΑΤΡΟΠΗ ΑΚΕΡΑΙΟΥ ΣΕ ΟΡΜΑΘΟ
                                                                                     $$.stringValue = strdup(str_temp); // ΔΗΜΙΟΥΡΓΙΑ ΜΟΝΙΜΟΥ ΑΝΤΙΓΡΑΦΟΥ ΤΗΣ ΤΙΜΗΣ ΓΙΑ ΝΑ ΔΙΑΤΗΡΗΘΕΙ Η ΤΙΜΗ 
                                                                                     $$.id_type = TYPE_INTEGER; // ΕΠΙΣΤΡΟΦΗ ΤΟΥ ΤΥΠΟΥ ΠΙΟ "ΠΑΝΩ"
                                                                                     $$.ast_node = make_ast_node(AST_CONST, $1.line_counter, $$.stringValue, 0); // ΚΟΜΒΟΣ ΦΥΛΛΟ
                                                                                   }

                    | RCONST                                                       { char str_temp[64];
                                                                                     sprintf(str_temp, "%f", $1.realValue);
                                                                                     $$.stringValue = strdup(str_temp); 
                                                                                     $$.id_type = TYPE_REAL;
                                                                                     $$.ast_node = make_ast_node(AST_CONST, $1.line_counter, $$.stringValue, 0); // ΚΟΜΒΟΣ ΦΥΛΛΟ
                                                                                   }

                    | LCONST                                                       { char str_temp[64];
                                                                                     sprintf(str_temp, "%d", $1.intValue); 
                                                                                     $$.stringValue = strdup(str_temp); 
                                                                                     $$.id_type = TYPE_LOGICAL;
                                                                                     $$.ast_node = make_ast_node(AST_CONST, $1.line_counter, $$.stringValue, 0); // ΚΟΜΒΟΣ ΦΥΛΛΟ
                                                                                   }

                    | CCONST                                                       { char str_temp[64];
                                                                                     sprintf(str_temp, "%d", $1.intValue); 
                                                                                     $$.stringValue = strdup(str_temp); 
                                                                                     $$.id_type = TYPE_CHARACTER; 
                                                                                     $$.ast_node = make_ast_node(AST_CONST, $1.line_counter, $$.stringValue, 0); // ΚΟΜΒΟΣ ΦΥΛΛΟ
                                                                                   }
                                                                                     
                                                                                     // ΔΕΝ ΕΠΙΤΡΕΠΕΤΑΙ Ο ΟΡΜΑΘΟΣ ΝΑ ΞΕΠΕΡΝΑΕΙ ΤΟΥΣ 255 ΧΑΡΑΚΤΗΡΕΣ
                    | SCONST                                                       { if (strlen($1.stringValue) > 255) semantic_error(too_big_string_msg, $1.line_counter, $1.stringValue);
                                                                                     $$.stringValue = $1.stringValue; 
                                                                                     $$.id_type = TYPE_STRING; 
                                                                                     $$.ast_node = make_ast_node(AST_CONST, $1.line_counter, $$.stringValue, 0); // ΚΟΜΒΟΣ ΦΥΛΛΟ
                                                                                   }
                    ;

// ΚΑΝΟΥΜΕ ΠΑΡΟΜΟΙΑ ΔΟΥΛΕΙΑ ΜΕ ΑΥΤΗΝ ΤΟΥ ΠΑΝΩ ΚΑΝΟΝΑ
complex_constant:    LPAREN RCONST COLON sign RCONST RPAREN                        { char* temp_s = ($4.stringValue != NULL) ? $4.stringValue : ""; // ΕΛΕΓΧΟΣ ΑΝ ΕΧΟΥΜΕ ΠΡΟΣΗΜΟ
                                                                                     char str_temp[128];
                                                                                     sprintf(str_temp, "(%f:%s%f)", $2.realValue, temp_s, $5.realValue);
                                                                                     $$.stringValue = strdup(str_temp);
                                                                                     $$.id_type = TYPE_COMPLEX;
                                                                                   }

                    | LPAREN RCONST error sign RCONST RPAREN                       { yyerrok; 
                                                                                     char* temp_s = ($4.stringValue != NULL) ? $4.stringValue : ""; 
                                                                                     char str_temp[128];
                                                                                     sprintf(str_temp, "(%f:%s%f)", $2.realValue, temp_s, $5.realValue);
                                                                                     $$.stringValue = strdup(str_temp);
                                                                                     $$.id_type = TYPE_COMPLEX;                                                                   
                                                                                   }
                    ;

statements:         statements labeled_statement                                   { $$.ast_node = make_stmt_list($1.ast_node, $2.ast_node); } // "ΚΟΛΛΑΜΕ" ΤΗΝ ΝΕΑ ΕΝΤΟΛΗ ΣΤΟ ΤΕΛΟΣ ΤΗΣ ΤΡΕΧΟΥΣΑΣ ΛΙΣΤΑΣ
                    | labeled_statement                                            { $$.ast_node = $1.ast_node; } // ΔΕΙΚΤΗΣ ΣΤΗΝ ΑΡΧΗ ΤΗΣ ΛΙΣΤΑΣ ΕΝΤΟΛΩΝ
                    ;
 
labeled_statement:  label statement                                                { symbol_node* sym_node = search_current_scope($1.stringValue);
                                                                                     if (sym_node != NULL && sym_node->category == LABEL) {
                                                                                        // ΑΝ ΕΧΕΙ ΒΡΕΘΕΙ ΗΔΗ ΟΡΙΣΜΟΣ ΓΙΑ ΑΥΤΟ ΤΟ label
                                                                                        if (sym_node->is_label_defined == 1) semantic_error(dup_labels_msg, $1.line_counter, $1.stringValue);
                                                                                        else sym_node->is_label_defined = 1; // ΒΡΕΘΗΚΕ ΧΡΗΣΗ ΤΗΣ ΕΤΙΚΕΤΑΣ
                                                                                     }
                                                                                     else semantic_error(no_label_msg, sym_node->line_number, $1.stringValue); // ΑΝ ΔΟΘΗΚΕ ΑΝΑΓΝΩΡΙΣΤΙΚΟ ΠΟΥ ΔΕΝ ΑΝΗΚΕΙ ΣΕ ΕΤΙΚΕΤΑ
                                                                                     // ΔΗΜΙΟΥΡΓΙΑ ΚΟΜΒΟΥ ΕΝΤΟΛΗΣ ΜΕ ΕΤΙΚΕΤΑ
                                                                                     $$.ast_node = make_ast_node(AST_LABELED_STMT, sym_node->line_number, $1.stringValue, 1, $2.ast_node);
                                                                                   }
                    | statement                                                    { $$.ast_node = $1.ast_node; }
                    ;
                                                                                   // label ΑΡΧΙΚΑ ΜΠΑΙΝΕΙ ΜΕ flag 0 (referenced only)
label:              ID                                                             { symbol_node* sym_node = search_current_scope($1.stringValue);
                                                                                     if (sym_node == NULL) {
                                                                                        sym_node = insert_new_symbol($1.stringValue, $1.line_counter); 
                                                                                        sym_node->category = LABEL;
                                                                                        sym_node->is_label_defined = 0;
                                                                                        // ΠΕΡΝΑΜΕ ΠΡΟΣ ΤΑ "ΠΑΝΩ" ΤΟ ΟΝΟΜΑ
                                                                                        $$.stringValue = $1.stringValue;
                                                                                        $$.ast_node = make_ast_node(AST_LABEL, $1.line_counter, $1.stringValue, 0);
                                                                                     }
                                                                                     else if (sym_node != NULL && sym_node->category != LABEL) semantic_error(dup_msg, $1.line_counter, $1.stringValue);
                                                                                   }
                    ;

statement:          simple_statement                                               { $$.ast_node = $1.ast_node; }
                    | compound_statement                                           { $$.ast_node = $1.ast_node; }
                    ;

simple_statement:   assignment                                                     { $$.ast_node = $1.ast_node; }              
                    | goto_statement                                               { $$.ast_node = $1.ast_node; }
                    | if_statement                                                 { $$.ast_node = $1.ast_node; }
                    | subroutine_call                                              { $$.ast_node = $1.ast_node; }
                    | io_statement                                                 { $$.ast_node = $1.ast_node; }
                    | CONTINUE                                                     { $$.ast_node = make_ast_node(AST_CONTINUE, $1.line_counter, NULL, 0); }
                    | RETURN                                                       { $$.ast_node = make_ast_node(AST_RETURN, $1.line_counter, NULL, 0); }
                    | STOP                                                         { $$.ast_node = make_ast_node(AST_STOP, $1.line_counter, NULL, 0); }
                    ;

// ΕΛΕΓΧΟΥΜΕ ΑΝ ΥΠΗΡΞΕ ΑΝΑΘΕΣΗ ΣΕ ΠΑΡΑΜΕΤΡΟ ΓΙΑ ΝΑ ΤΗΣ ΑΛΛΑΞΟΥΜΕ ΤΟΝ ΤΡΟΠΟ ΠΕΡΑΣΜΑΤΟΣ,
// ΠΙΝΑΚΕΣ, ΛΙΣΤΕΣ ΚΑΙ strings ΠΕΡΝΑΝΕ ΚΑΤ' ΑΝΑΦΟΡΑ ΕΞΑΡΧΗΣ 
// ΕΛΕΓΧΟΥΜΕ ΚΑΙ ΑΝ ΤΟ ΑΝΑΓΝΩΡΙΣΤΙΚΟ ΠΟΥ ΣΥΜΜΕΤΕΧΕΙ ΣΤΗΝ ΑΝΑΘΕΣΗ ΕΧΕΙ ΠΡΟΗΓΟΥΜΕΝΩΣ ΔΗΛΩΘΕΙ                                                                           
assignment:         variable ASSIGN expression                                     { if ($1.stringValue != NULL) {
                                                                                        // ΓΙΑ ΑΝΑΘΕΣΕΙΣ ΨΑΧΝΟΥΜΕ ΓΙΑ ΔΗΛΩΣΕΙΣ ΤΩΝ ΑΝΑΓΝΩΡΙΣΤΙΚΩΝ ΑΠΟ ΕΣΩΤΕΡΙΚΕΣ ΠΡΟΣ ΕΞΩΤΕΡΙΚΕΣ ΕΜΒΕΛΕΙΕΣ
                                                                                        symbol_node* sym_node = search_all_scopes($1.stringValue);
                                                                                        if (sym_node != NULL) {
                                                                                          if (sym_node->is_array == 0 && sym_node->id_type != TYPE_STRING) sym_node->is_assigned = 1;
                                                                                        }
                                                                                        else semantic_error(undefined_msg, $1.line_counter, $1.stringValue);
                                                                                     }
                                                                                     $$.ast_node = make_ast_node(AST_ASSIGN, $2.line_counter, "=", 2, $1.ast_node, $3.ast_node);
                                                                                   }
                    ;
                    
// ΛΕΙΠΕΙ ΕΛΕΓΧΟΣ ΓΙΑ ΤΟΥΣ ΔΕΙΚΤΕΣ ΤΟΥ ΠΙΝΑΚΑ                                      // ΜΕΤΑΒΛΗΤΗ ΠΙΝΑΚΑΣ Ή ΚΛΗΣΗ ΣΥΝΑΡΤΗΣΗΣ 
variable:           ID LPAREN expressions RPAREN                                   { $$.stringValue = $1.stringValue; 
                                                                                     $$.line_counter = $1.line_counter; 
                                                                                     ast_node* var = make_ast_node(AST_VAR, $1.line_counter, $1.stringValue, 0);
                                                                                     $$.ast_node = make_ast_node(AST_ARRAY_OR_FUNC, $1.line_counter, "()", 2, var, $3.ast_node);
                                                                                   }                                                   
                    // ΕΙΔΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ ΛΙΣΤΑΣ
                    | LISTFUNC LPAREN expression RPAREN                            { $$.stringValue = NULL; 
                                                                                     $$.ast_node = make_ast_node(AST_LISTFUNC, $1.line_counter, $1.stringValue, 1, $3.ast_node);
                                                                                   }

                                                                                   // ΑΠΛΗ ΜΕΤΑΒΛΗΤΗ
                    | ID                                                           { $$.stringValue = $1.stringValue; 
                                                                                     $$.line_counter = $1.line_counter; 
                                                                                     // ΚΑΤΑΣΚΕΥΗ ΚΟΜΒΟΥ-ΦΥΛΛΟΥ ΓΙΑ ΑΝΑΓΝΩΡΙΣΤΙΚΟ, ΠΕΡΝΙΕΤΑΙ ΑΡΙΣΤΕΡΑ Ο ΔΕΙΚΤΗΣ ΣΕ ΑΥΤΟΝ
                                                                                     $$.ast_node = make_ast_node(AST_VAR, $1.line_counter, $1.stringValue, 0);
                                                                                   }
                    ;
                                                                                   // "ΚΟΛΛΑΜΕ" ΤΟ ΝΕΟ ΠΑΙΔΙ ΣΤΟΝ ΚΟΜΒΟ ΛΙΣΤΑΣ, ΤΟ $1 ΕΙΝΑΙ ΗΔΗ ΚΟΜΒΟΣ ΛΙΣΤΑΣ
expressions:        expressions COMMA expression                                   { $$.ast_node = append_child($1.ast_node, $3.ast_node); }
                                                                                   // ΦΤΙΑΧΝΟΥΜΕ ΕΝΑΝ ΝΕΟ ΚΟΜΒΟ ΛΙΣΤΑΣ ΕΚΦΡΑΣΕΩΝ ΜΕ ΕΝΑ ΜΟΝΟ ΠΑΙΔΙ
                    | expression                                                   { $$.ast_node = make_ast_node(AST_EXPR_LIST, $1.ast_node->line, "ARGS", 1, $1.ast_node); }
                    ;

expression:         expression OROP expression                                     { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, ".OR.", 2, $1.ast_node, $3.ast_node); }
                    | expression ANDOP expression                                  { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, ".AND.", 2, $1.ast_node, $3.ast_node); }           
                    | expression RELOP expression                                  { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, $2.stringValue, 2, $1.ast_node, $3.ast_node); }
                    | expression ADDOP expression                                  { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, $2.stringValue, 2, $1.ast_node, $3.ast_node); }
                    | expression MULOP expression                                  { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, "*", 2, $1.ast_node, $3.ast_node); }
                    | expression DIVOP expression                                  { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, "/", 2, $1.ast_node, $3.ast_node); }
                    | expression POWEROP expression                                { $$.ast_node = make_ast_node(AST_BINOP, $1.line_counter, "**", 2, $1.ast_node, $3.ast_node); }
                    | NOTOP expression                                             { $$.ast_node = make_ast_node(AST_UNOP, $1.line_counter, ".NOT.", 1, $2.ast_node); }
// ΟΡΙΜΟΣ ΠΡΟΤΕΡΑΙΟΤΗΤΑΣ ΚΑΝΟΝΑ ΣΤΗΝ ΠΡΟΤΕΡΑΙΟΤΗΤΑ ΤΟΥ UMINUS ΓΙΑ ΣΩΣΤΗ ΕΦΑΡΜΟΓΗ ΠΡΟΣΗΜΟΥ
                    | ADDOP expression %prec UMINUS                                { $$.ast_node = make_ast_node(AST_UNOP, $1.line_counter, $1.stringValue, 1, $2.ast_node); }
                    | variable                                                     { $$.ast_node = $1.ast_node; }
                    | simple_constant                                              { $$.ast_node = $1.ast_node; }
                    | LENGTH LPAREN expression RPAREN                              { $$.ast_node = make_ast_node(AST_LENGTH, $4.line_counter, "LENGTH", 1, $3.ast_node); }
                    | LENGTH error expression RPAREN                               { yyerrok; $$.ast_node = make_ast_node(AST_LENGTH, $4.line_counter, "LENGTH", 1, $3.ast_node); }
                    | LPAREN expression RPAREN                                     { $$.ast_node = $2.ast_node; } // ΔΕΝ ΦΤΙΑΧΝΟΥΜΕ ΚΟΜΒΟ ΓΙΑ ΤΙΣ ΠΑΡΕΝΘΕΣΕΙΣ, ΠΕΡΝΑΜΕ ΑΥΤΟΝ ΠΟΥ ΕΧΕΙ ΦΤΙΑΧΤΕΙ ΕΣΩΤΕΡΙΚΑ ΑΡΙΣΤΕΡΑ
                    | LPAREN expression COLON expression RPAREN                    { $$.ast_node = make_ast_node(AST_COMPLEX_MAKE, $5.line_counter, ":", 2, $2.ast_node, $4.ast_node); }
                    | listexpression                                               { $$.ast_node = $1.ast_node; }
                    ;

listexpression:     LBRACK expressions RBRACK                                      { $$.ast_node = make_ast_node(AST_LIST_MAKE, $1.line_counter, "[]", 1, $2.ast_node); }
                    | LBRACK RBRACK                                                { $$.ast_node = make_ast_node(AST_LIST_MAKE, $1.line_counter, "[]", 0); }
                    ;  
  
goto_statement:     GOTO label                                                     { $$.ast_node = make_ast_node(AST_GOTO, $2.ast_node->line, NULL, 1, $2.ast_node); }
                    | GOTO ID COMMA LPAREN labels RPAREN                           { ast_node* var = make_ast_node(AST_VAR, $2.line_counter, $2.stringValue, 0); 
                                                                                     $$.ast_node = make_ast_node(AST_COMPUTED_GOTO, var->line, NULL, 2, var, $5.ast_node);
                                                                                   }
                    | GOTO ID COMMA error labels RPAREN                           { yyerrok; 
                                                                                     ast_node* var = make_ast_node(AST_VAR, $2.line_counter, $2.stringValue, 0); 
                                                                                     $$.ast_node = make_ast_node(AST_COMPUTED_GOTO, var->line, NULL, 2, var, $5.ast_node);
                                                                                   }
                    ;
                                                                                 
labels:             labels COMMA label                                             { $$.ast_node = append_child($1.ast_node, $3.ast_node); }  // ΠΡΟΣΘΗΚΗ ΝΕΑΣ ΕΤΙΚΕΤΑΣ ΣΤΗΝ ΤΡΕΧΟΥΣΑ ΛΙΣΤΑ
                                                                                   // ΑΡΧΗ ΤΗΣ ΛΙΣΤΑΣ ΕΤΙΚΕΤΩΝ
                    | label                                                        { $$.ast_node = make_ast_node(AST_LABEL_LIST, $1.ast_node->line, NULL, 1, $1.ast_node); }
                    ;

if_statement:       IF LPAREN expression RPAREN label COMMA label COMMA label      { $$.ast_node = make_ast_node(AST_ARTM_IF, $4.line_counter, NULL, 4, $3.ast_node, $5.ast_node, $7.ast_node, $9.ast_node); } // ΑΡΙΜΘΗΤΙΚΟ IF
                    | IF LPAREN expression RPAREN simple_statement                 { $$.ast_node = make_ast_node(AST_LOG_IF, $4.line_counter, NULL, 2, $3.ast_node, $5.ast_node); } // ΛΟΓΙΚΟ IF
                    ;
                                                                                   
subroutine_call:    CALL variable                                                  { $$.ast_node = make_ast_node(AST_CALL, $2.ast_node->line, NULL, 1, $2.ast_node); }
                    ;

io_statement:       READ read_list                                                 { $$.ast_node = make_ast_node(AST_READ, $2.ast_node->line, NULL, 1, $2.ast_node); }
                    | WRITE write_list                                             { $$.ast_node = make_ast_node(AST_WRITE, $2.ast_node->line, NULL, 1, $2.ast_node); }
                    ;
                                                                                   // ΔΗΜΙΟΥΡΓΙΑ ΛΙΣΤΑΣ ΜΕΤΑΒΛΗΤΩΝ
read_list:          read_list COMMA read_item                                      { $$.ast_node = append_child($1.ast_node, $3.ast_node); }
                    | read_item                                                    { $$.ast_node = make_ast_node(AST_IO_LIST, $1.ast_node->line, NULL, 1, $1.ast_node); }
                    ;

read_item:          variable                                                       { $$.ast_node = $1.ast_node; }
                    | LPAREN read_list COMMA ID ASSIGN iter_space RPAREN           { ast_node* var = make_ast_node(AST_VAR, $4.line_counter, $4.stringValue, 0); 
                                                                                    $$.ast_node = make_ast_node(AST_IMPLIED_LOOP, var->line, NULL, 3, $2.ast_node, var, $6.ast_node);
                                                                                   }
                    | LPAREN read_list COMMA ID error iter_space RPAREN            { yyerrok;
                                                                                    ast_node* var = make_ast_node(AST_VAR, $4.line_counter, $4.stringValue, 0); 
                                                                                    $$.ast_node = make_ast_node(AST_IMPLIED_LOOP, var->line, NULL, 3, $2.ast_node, var, $6.ast_node); 
                                                                                   }
                    ;
                                                                                   
iter_space:         expression COMMA expression step                               { $$.ast_node = make_ast_node(AST_ITER_SPACE, $1.ast_node->line, NULL, 3, $1.ast_node, $3.ast_node, $4.ast_node); }
                    ;

step:               COMMA expression                                               { $$.ast_node = $2.ast_node; }
                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ;
                                                                                   // ΔΗΜΙΟΥΡΓΙΑ ΛΙΣΤΑΣ ΕΚΦΡΑΣΕΩΝ
write_list:         write_list COMMA write_item                                    { $$.ast_node = append_child($1.ast_node, $3.ast_node); }
                    | write_item                                                   { $$.ast_node = make_ast_node(AST_IO_LIST, $1.ast_node->line, NULL, 1, $1.ast_node); }
                    ;

write_item:         expression                                                     { $$.ast_node = $1.ast_node; }
                    | LPAREN write_list COMMA ID ASSIGN iter_space RPAREN          { ast_node* var = make_ast_node(AST_VAR, $4.line_counter, $4.stringValue, 0);
                                                                                     $$.ast_node = make_ast_node(AST_IMPLIED_LOOP, var->line, NULL, 3, $2.ast_node, var, $6.ast_node);
                                                                                   }
                    
                    | LPAREN write_list COMMA ID error iter_space RPAREN           { yyerrok; ast_node* var = make_ast_node(AST_VAR, $4.line_counter, $4.stringValue, 0);
                                                                                     $$.ast_node = make_ast_node(AST_IMPLIED_LOOP, var->line, NULL, 3, $2.ast_node, var, $6.ast_node);
                                                                                   }
                    ;

compound_statement: branch_statement                                               { $$.ast_node = $1.ast_node; }
                    | loop_statement                                               { $$.ast_node = $1.ast_node; }
                    ;

branch_statement:   IF LPAREN expression RPAREN THEN                               { create_new_scope(); }
                    inner_body                                                     { exit_print_scope(); }
                                                                                   // ΚΟΜΒΟΣ ΓΙΑ ΤΗΝ ΔΙΑΚΛΑΔΩΣΗ, 3 ΠΑΙΔΙΑ, Η ΕΚΦΡΑΣΗ ΑΠΟΤΙΜΗΣΗΣ, ΤΟ ΣΩΜΑ ΕΝΤΟΛΩΝ ΚΑΙ ΤΟ ΣΩΜΑ ΕΝΤΟΛΩΝ ΤΟΥ ELSE ΑΝ ΥΠΑΡΧΕΙ
                    tail                                                           { $$.ast_node = make_ast_node(AST_BRANCH, $4.line_counter, NULL, 3, $3.ast_node, $7.ast_node, $9.ast_node); }
                    
                    | IF error ENDIF                                               { yyerrok; // ΣΦΑΛΜΑ ΣΤΗΝ ΣΥΝΘΗΚΗ, ΜΕΘΟΔΟΣ ΠΑΝΙΚΟΥ
                                                                                     $$.ast_node = NULL;
                                                                                   }
                    ;

tail:               ELSE                                                           { create_new_scope(); }
                    inner_body ENDIF                                               { exit_print_scope(); $$.ast_node = $3.ast_node; }                                                     
                    | ENDIF                                                        { $$.ast_node = NULL; }                         
                    ;

loop_statement:     DO ID ASSIGN iter_space                                        { create_new_scope(); }                                                     
                    inner_body ENDDO                                               { exit_print_scope(); 
                                                                                     ast_node* var = make_ast_node(AST_VAR, $2.line_counter, $2.stringValue, 0);
                                                                                     $$.ast_node = make_ast_node(AST_LOOP, var->line, NULL, 3, var, $4.ast_node, $6.ast_node); 
                                                                                   } 
                    
                    | DO error ENDDO                                               { yyerrok; // ΣΦΑΛΜΑ ΣΤΗΝ "ΕΠΙΚΕΦΑΛΙΔΑ" ΤΟΥ loop, ΜΕΘΟΔΟΣ ΠΑΝΙΚΟΥ
                                                                                     $$.ast_node = NULL;
                                                                                   }                                                                                                 
                    ;
                                                                                   // ΣΥΛΛΕΓΟΥΜΕ ΤΑ ΥΠΟΠΡΟΓΡΑΜΜΑΤΑ ΣΕ ΜΙΑ ΑΠΛΗ ΓΡΑΜΜΙΚΗ ΛΙΣΤΑ
subprograms:        subprograms subprogram                                         { $$.ast_node = make_stmt_list($1.ast_node, $2.ast_node); }
                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ;
                                                                                   // ΑΛΛΑΓΗ ΤΡΟΠΟΥ ΠΕΡΑΣΜΑΤΟΣ ΠΑΡΑΜΕΤΡΟΥ ΠΟΥ ΣΥΜΜΕΤΕΙΧΕ ΣΕ ΑΝΑΘΕΣΗ
subprogram:         header body END                                                { symbol_node* sym_node = $1.temp_node; // ΠΑΙΡΝΟΥΜΕ ΤΟΝ ΚΟΜΒΟ ΤΟΥ ΥΠΟΠΡΟΓΡΑΜΜΑΤΟΣ
                                                                                     param_node* temp_param = sym_node->params; // ΠΑΙΡΝΟΥΜΕ ΤΗΝ ΛΙΣΤΑ ΠΑΡΑΜΕΤΡΩΝ
                                                                                     while (temp_param != NULL) {
                                                                                       symbol_node* p_node = search_current_scope(temp_param->p_name);
                                                                                       if (p_node->is_assigned == 1) temp_param->param_pass_style = PASS_BY_REF;
                                                                                       temp_param = temp_param->next;
                                                                                     }
                                                                                     // ΔΗΜΙΟΥΡΓΙΑ ΚΟΜΒΟΥ ΥΠΟΠΡΟΓΡΑΜΜΑΤΟΣ
                                                                                     $$.ast_node = make_ast_node(AST_SUBPROGRAM, sym_node->line_number, sym_node->id_name, 1, $2.ast_node);
                                                                                     exit_print_scope();   
                                                                                     printf("---------------------------------------------------\n");
                                                                                     printf("*********AST FOR SUBPROGRAM (%s)***********\n", sym_node->id_name);
                                                                                     printf("---------------------------------------------------\n");
                                                                                     print_ast($$.ast_node, 0); // ΕΚΤΥΠΩΝΟΥΜΕ ΤΟ ΔΕΝΔΡΟ ΓΙΑ ΤΟ ΣΩΜΑ ΤΟΥ ΥΠΟΠΡΟΓΡΑΜΜΑΤΟΣ                                                   
                                                                                   }
                    
                    | error END                                                    { yyerrok; // ΣΦΑΛΜΑ ΣΤΗΝ ΕΠΙΚΕΦΑΛΙΔΑ, ΜΕΘΟΔΟΣ ΠΑΝΙΚΟΥ, ΑΓΝΟΕΙΤΑΙ ΟΛΟ ΤΟ ΥΠΟΠΡΟΓΡΑΜΜΑ
                                                                                     exit_print_scope();
                                                                                     $$.ast_node = NULL;
                                                                                   }

                    | header error END                                             { yyerrok; // ΣΦΑΛΜΑ ΣΤΟ ΣΩΜΑ 
                                                                                     exit_print_scope();
                                                                                     $$.ast_node = NULL;
                                                                                   }              
                    ;
                                                                                   // mid rule action ΔΕΥΣΜΕΥΕΙ ΕΝΑΝ ΑΡΙΘΜΟ ΑΡΙΘΜΗΣΗΣ ΤΩΝ ΣΥΜΒΟΛΩΝ ΤΟΥ ΚΑΝΟΝΑ ΕΔΩ ΤΟ 5
header:             type listspec FUNCTION ID                                      { symbol_node* sym_node = search_current_scope($4.stringValue);
                                                                                     if (sym_node == NULL) {
                                                                                       // ΑΠΑΓΟΡΕΥΕΤΑΙ Η ΣΥΝΑΡΤΗΣΗ ΝΑ ΕΠΙΣΤΡΕΦΕΙ string
                                                                                        if ($1.id_type == TYPE_STRING) semantic_error(no_string_msg, $1.line_counter, $1.stringValue);
                                                                                        else {
                                                                                          sym_node = insert_new_symbol($4.stringValue, $4.line_counter);
                                                                                          sym_node->category = FUNC;
                                                                                          sym_node->id_type = $1.id_type;
                                                                                          sym_node->is_list = $2.is_list;
                                                                                          create_new_scope();
                                                                                        } 
                                                                                     }  
                                                                                     else semantic_error(dup_msg, $4.line_counter, $4.stringValue);
                                                                                   }

                                                                                     // ΕΛΕΓΧΟΣ ΑΝ Η ΣΥΝΑΡΤΗΣΗ ΕΧΕΙ ΠΑΡΑΜΕΤΡΟΥΣ
                    LPAREN formal_parameters RPAREN                                { if ($7.p_node_list != NULL) {
                                                                                        symbol_node* sym_node = search_all_scopes($4.stringValue); // ΤΟ ΑΝΑΓΝΩΡΙΣΤΙΚΟ ΤΗΣ ΣΥΝΑΡΤΗΣΗΣ ΑΝΗΚΕΙ ΣΤΗΝ ΕΜΒΕΛΕΙΑ ΤΗΣ ΚΥΡΙΑΣ ΜΟΝΑΔΑΣ 
                                                                                        sym_node->params = $7.p_node_list; // "ΕΝΩΣΗ" ID ME THN ΛΙΣΤΑ ΠΑΡΑΜΕΤΡΩΝ ΤΟΥ
                                                                                        int param_counter = 0;
                                                                                        param_node* p_temp = $7.p_node_list;
                                                                                        while (p_temp != NULL) {
                                                                                           p_temp = p_temp->next; 
                                                                                           param_counter++; 
                                                                                        }
                                                                                        sym_node->param_total = param_counter;
                                                                                        $$.temp_node = sym_node; // ΠΕΡΝΑΜΕ ΤΟΝ ΚΟΜΒΟ ΤΗΣ ΣΥΝΑΡΤΗΣΗΣ ΠΡΟΣ ΤΑ ΠΑΝΩ
                                                                                     } 
                                                                                     else semantic_error(no_params_func_msg, $8.line_counter, NULL);
                                                                                   }
                    
                    | SUBROUTINE ID                                                { symbol_node* sym_node = search_current_scope($2.stringValue); 
                                                                                     if (sym_node == NULL) {
                                                                                        sym_node = insert_new_symbol($2.stringValue, $2.line_counter); 
                                                                                        sym_node->category = SUBR;
                                                                                        create_new_scope();
                                                                                     } 
                                                                                     else semantic_error(dup_msg, $2.line_counter, $2.stringValue);
                                                                                   }
                                                                                   
                                                                                   // SUBROUTINE ΕΠΙΤΡΕΠΕΤΑΙ ΝΑ ΜΗΝ ΕΧΕΙ ΠΑΡΑΜΕΤΡΟΥΣ
                    subroutine_params                                              { symbol_node* sym_node = search_all_scopes($2.stringValue); 
                                                                                     sym_node->params = $4.p_node_list; // "ΕΝΩΣΗ" ID ME THN ΛΙΣΤΑ ΠΑΡΑΜΕΤΡΩΝ ΤΟΥ
                                                                                     int param_counter = 0;
                                                                                     param_node* p_temp = $4.p_node_list;
                                                                                     while (p_temp != NULL) {
                                                                                           param_counter++;
                                                                                           p_temp = p_temp->next;  
                                                                                        }
                                                                                     sym_node->param_total = param_counter;
                                                                                     $$.temp_node = sym_node; // ΠΕΡΝΑΜΕ ΤΟΝ ΚΟΜΒΟ ΤΗΣ ΥΠΟΡΟΥΤΙΝΑΣ ΠΡΟΣ ΤΑ ΠΑΝΩ
                                                                                   }
                    ;                       

subroutine_params:  LPAREN formal_parameters RPAREN                                { $$.p_node_list = $2.p_node_list; }
                    | %empty                                                       { $$ = (semantic_attributes){0}; }
                    ; 
                                                                                   // ΜΑΖΕΜΑ ΟΛΩΝ ΤΩΝ ΠΑΡΑΜΕΤΡΩΝ ΣΕ ΕΝΝΙΑΙΑ ΛΙΣΤΑ ΠΟΥ ΘΑ ΑΝΤΙΣΤΟΙΧΕΙ ΣΤΟ ID ΤΟΥ ΥΠΟΠΡΟΓΡΑΜΜΑΤΟΣ
formal_parameters:  type vars COMMA formal_parameters                              { symbol_node* sym_temp = $2.sym_node_list; // ΠΡΟΣΩΡΙΝΗ ΛΙΣΤΑ ΑΝΑΓΝΩΡΙΣΤΙΚΩΝ ΓΙΑ ΤΑ type vars, ΕΧΕΙ ΦΤΙΑΧΤΕΙ ΑΠΟ ΠΙΟ ΠΑΝΩ ΚΑΝΟΝΕΣ
                                                                                     param_node* p_node_head = NULL;
                                                                                     param_node* p_node_tail = NULL;
                                                                                     while (sym_temp != NULL) {
                                                                                        sym_temp->id_type = $1.id_type;
                                                                                        sym_temp->category = VAR;
                                                                                        param_node* p_node = (param_node*)malloc(sizeof(param_node));
                                                                                        p_node->param_type = $1.id_type;
                                                                                        p_node->p_name = strdup(sym_temp->id_name);
                                                                                        // ΕΛΕΓΧΟΣ ΤΡΟΠΟΥ ΠΕΡΑΣΜΑΤΟΣ
                                                                                        p_node->param_pass_style = (sym_temp->is_array || sym_temp->is_list || $1.id_type == TYPE_STRING) ? PASS_BY_REF : PASS_BY_VALUE;
                                                                                        p_node->next = NULL;
                                                                                        if(p_node_head == NULL) p_node_head = p_node; // ΤΟΠΟΘΕΤΗΣΗ ΣΤΗΝ ΑΡΧΗ ΤΗΣ ΛΙΣΤΑΣ
                                                                                        else p_node_tail->next = p_node; // ΤΟΠΟΘΕΤΗΣΗ ΣΤΟ ΤΕΛΟΣ
                                                                                        p_node_tail = p_node;
                                                                                        sym_temp = sym_temp->temp_next;
                                                                                     }
                                                                                     if (p_node_tail != NULL) p_node_tail->next = $4.p_node_list; // "ΚΟΛΛΑΜΕ" ΣΤΗΝ ΛΙΣΤΑ ΠΟΥ ΦΤΙΑΧΤΗΚΕ ΤΗΝ ΛΙΣΤΑ ΠΟΥ ΕΙΧΑΜΕ ΗΔΗ ΦΤΙΑΞΕΙ ΑΠΟ ΠΡΟΗΓΟΥΜΕΝΗ ΑΝΑΔΡΟΜΗ
                                                                                     $$.p_node_list = p_node_head != NULL ? p_node_head : $4.p_node_list;
                                                                                   } 
                    
                    | type vars                                                    { symbol_node* sym_temp = $2.sym_node_list; // ΛΙΣΤΑ ΑΝΑΓΝΩΡΙΣΤΙΚΩΝ ΓΙΑ ΤΑ type vars, ΕΧΕΙ ΦΤΙΑΧΤΕΙ ΑΠΟ ΠΙΟ ΠΑΝΩ ΚΑΝΟΝΕΣ
                                                                                     param_node* p_node_head = NULL;
                                                                                     param_node* p_node_tail = NULL;
                                                                                     while (sym_temp != NULL) {
                                                                                        sym_temp->id_type = $1.id_type;
                                                                                        sym_temp->category = VAR;
                                                                                        param_node* p_node = (param_node*)malloc(sizeof(param_node));
                                                                                        p_node->param_type = $1.id_type;
                                                                                        p_node->p_name = strdup(sym_temp->id_name); 
                                                                                        // ΕΛΕΓΧΟΣ ΤΡΟΠΟΥ ΠΕΡΑΣΜΑΤΟΣ
                                                                                        p_node->param_pass_style = (sym_temp->is_array || sym_temp->is_list || $1.id_type == TYPE_STRING) ? PASS_BY_REF : PASS_BY_VALUE;
                                                                                        p_node->next = NULL;
                                                                                        if (p_node_head == NULL) p_node_head = p_node; // ΤΟΠΟΘΕΤΗΣΗ ΣΤΗΝ ΑΡΧΗ ΤΗΣ ΛΙΣΤΑΣ
                                                                                        else p_node_tail->next = p_node; // ΤΟΠΟΘΕΤΗΣΗ ΣΤΟ ΤΕΛΟΣ
                                                                                        p_node_tail = p_node;
                                                                                        sym_temp = sym_temp->temp_next;
                                                                                     }
                                                                                     $$.p_node_list = p_node_head;
                                                                                   }
                    ;
 
%%

// ΤΜΗΜΑ ΣΥΝΑΡΤΗΣΕΩΝ ΧΡΗΣΤΗ

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΕΚΤΥΠΩΣΗ ΣΦΑΛΜΑΤΩΝ ΚΑΙ ΤΗΝ ΔΙΑΧΕΡΙΣΗ ΤΟΥ error_counter ΚΑΛΕΙΤΑΙ ΑΥΤΟΜΑΤΑ ΑΠΟ ΤΟ bison
void yyerror(const char* message) {
    printf("Syntax error found!\n");
    printf("Error at line %d caused by %s\n", yylineno, message);
    printf("Line that contains the error: %s\n", line_buffer);
    printf("-------------------------------------------------------------------\n");
    error_counter++;
    if (error_counter > 5) {
        printf("Maximum number of errors (5) exceeded! Terminating parser.\n");
        exit(EXIT_FAILURE);
    }
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΕΚΤΥΠΩΣΗ ΣΗΜΑΣΙΟΛΟΓΙΚΩΝ ΣΦΑΛΜΑΤΩΝ ΚΑΙ ΤΕΡΜΑΤΙΣΜΟ ΤΗΣ ΑΝΑΛΥΣΗΣ
void semantic_error(const char* message, int line_error_occured, char* variable_name) {
    printf("Semantic error found!\n");
    if (variable_name != NULL) {
      printf("Error at line %d caused by '%s', semantic error: %s\n", line_error_occured, variable_name, message);
    }
    else {
      printf("Error at line %d, semantic error: %s\n", line_error_occured, message);
    }
    printf("Terminating parser immediately!\n");
    exit(EXIT_FAILURE);
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΕΛΕΓΧΟ ΣΥΜΒΑΤΟΤΗΤΑΣ ΤΥΠΩΝ ΚΑΤΑ ΤΗΝ ΑΝΑΘΕΣΗ ΑΡΧΙΚΩΝ ΤΙΜΩΝ
int type_match(fort_types type1, fort_types type2) {
    if (type1 == type2) return 1; // ΙΔΙΟΙ ΤΥΠΟΙ
    // ΣΥΜΒΑΤΟΤΗΤΑ ΜΕΤΑΞΥ ΑΚΕΡΑΙΩΝ - ΠΡΑΓΜΑΤΙΚΩΝ (ΜΕΤΑΤΡΕΠΟΝΤΑΙ Ο ΕΝΑΣ ΣΤΟΝ ΑΛΛΟΝ)
    else if ((type1 == TYPE_INTEGER && type2 == TYPE_REAL) || (type1 == TYPE_REAL && type2 == TYPE_INTEGER)) return 1;
    else return 0;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΜΕΤΑΤΡΟΠΗ ΤΙΜΩΝ ΑΠΟ int ΣΕ double ΚΑΙ ΑΠΟ double ΣΕ int ΚΑΙ ΓΙΑ ΤΗΝ ΔΙΑΧΕΙΡΙΣΗ ΤΩΝ strings 
char* type_conversion(char* src_value, fort_types src_type, fort_types dest_type) {
    if (src_type == dest_type) {
      if (src_type == TYPE_STRING) {
        char* string_buf = (char*)calloc(256, sizeof(char)); // ΔΥΝΑΜΙΚΗ ΔΕΥΜΕΥΣΗ 256 ΘΕΣΕΩΝ ΧΑΡΑΚΤΗΡΩΝ, ΑΡΧΙΚΟΠΟΙΟΥΝΤΑΙ ΜΕ ΜΗΔΕΝ (null terminator \0) 
        if (string_buf == NULL) return NULL; // ΑΠΟΤΥΧΙΑ ΔΕΥΜΕΥΣΗΣ
        else {
          strcpy(string_buf, src_value); // ΑΝΤΙΓΡΑΦΗ ΑΡΧΙΚΟΥ string ΣΤΟΝ ΔΕΥΜΕΥΣΜΕΝΟ ΧΩΡΟ
          free(src_value); // ΑΠΟΔΕΥΜΕΥΣΗ ΠΑΛΙΟΥ string, ΔΕΝ ΧΡΕΙΑΖΕΤΑΙ ΠΛΕΟΝ
          return string_buf;
        }
      }
      return src_value; // ΔΕΝ ΕΙΝΑΙ string, ΕΠΙΣΤΡΕΦΕΤΑΙ Η ΤΙΜΗ ΩΣ ΕΧΕΙ  
    }
    else {
      char str_temp[128]; // ΠΙΝΑΚΑΣ ΓΙΑ ΠΡΟΣΩΡΙΝΗ ΑΠΟΘΗΚΕΥΣΗ ΤΟΥ string ΤΗΣ ΤΙΜΗΣ
      if (src_type == TYPE_INTEGER && dest_type == TYPE_REAL) {
         sprintf(str_temp, "%f", (double)atoi(src_value)); // ΜΕΤΑΤΡΟΠΗ int ΣΕ double ΚΑΙ ΑΠΟΘΗΚΕΥΣΗ ΞΑΝΑ ΣΕ ΜΟΡΦΗ string 
      } 
      if (src_type == TYPE_REAL && dest_type == TYPE_INTEGER) {
         sprintf(str_temp, "%d", (int)atof(src_value)); // ΜΕΤΑΤΡΟΠΗ double ΣΕ int
      }
      free(src_value); // ΚΑΝΟΥΜΕ free ΤΟ ΑΡΧΙΚΟ string
      return strdup(str_temp);
    }
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΔΗΜΙΟΥΡΓΙΑ ΤΗΣ ΛΙΣΤΑΣ ΤΩΝ ΑΡΧΙΚΩΝ ΤΙΜΩΝ ΤΟΥ ΠΙΝΑΚΑ ΑΠΟ ΤΗΝ ΠΡΟΣΩΡΙΝΗ ΛΙΣΤΑ ΤΟΥ bison Η ΟΠΟΙΑ ΘΑ ΑΠΟΘΗΚΕΥΤΕΙ ΣΤΟΝ ΠΣ 
array_init_node* array_initialization(symbol_node* sym_node, array_init_node* temp_list, int line) {
    array_init_node* head = NULL;
    array_init_node* tail = NULL;
    int plain_asterisk = 0;
    array_init_node* temp = temp_list;
    
    // ΒΡΟΓΧΟΣ ΓΙΑ ΤΗΝ ΕΠΕΞΕΡΓΑΣΙΑ ΤΗΣ ΠΡΟΣΩΡΙΝΗΣ ΛΙΣΤΑΣ
    while (temp != NULL) {
      if (type_match(sym_node->id_type, temp->type) == 0) semantic_error(type_mismatch_msg, line, temp->array_value); // ΕΛΕΓΧΟΣ ΣΥΜΒΑΤΟΤΗΤΑΣ ΤΥΠΩΝ
      if (temp->plain_asterisk == 1) { // ΕΛΕΓΧΟΣ ΓΙΑ ΠΟΛΛΑΠΛΑ ΣΚΕΤΑ '*'
        if (plain_asterisk == 1) semantic_error(multi_asterisk_use_msg, line, sym_node->id_name);
        else plain_asterisk = 1;
      } 
      char* converted_value = type_conversion(temp->array_value, temp->type, sym_node->id_type);
      array_init_node* val_node = (array_init_node*)malloc(sizeof(array_init_node));
      val_node->array_value = converted_value;
      val_node->type = sym_node->id_type;
      val_node->repeat_count = temp->repeat_count;
      val_node->plain_asterisk = temp->plain_asterisk;
      val_node->array_next = NULL;
      
      // ΤΟΠΟΘΕΤΗΣΗ ΚΟΜΒΟΥ ΣΤΗΝ ΤΕΛΙΚΗ ΛΙΣΤΑ ΓΙΑ ΤΟΝ ΠΣ
      if (head == NULL) head = val_node;
      else tail->array_next = val_node;
      tail = val_node;
      
      // ΔΙΑΓΡΑΦΗ ΚΟΜΒΟΥ ΠΟΥ ΔΕΝ ΧΡΕΙΑΖΕΤΑΙ ΠΛΕΟΝ
      array_init_node* del = temp;
      temp = temp->array_next;
      free(del);
    }
    return head;
}

int main(int argc, char* argv[]) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            perror("Error opening file");
            return EXIT_FAILURE;
        }
    }

init_symbol_table(); // ΑΧΡΙΚΟΠΟΙΗΣΗ ΠΣ

yyparse(); // ΕΚΤΕΛΕΣΗ ΣΣΑ, ΚΑΛΕΙ ΛΕΚΤΙΚΟ (yylex) ΟΠΟΤΕ ΧΡΕΙΑΖΕΤΑΙ ΕΠΟΜΕΝΗ ΛΕΚΤΙΚΗ ΜΟΝΑΔΑ

// ΑΠΑΙΤΗΣΗ ΕΚΦΩΝΗΣΗΣ ΝΑ ΣΤΑΜΑΤΑΕΙ Η ΠΑΡΑΓΩΓΗ ΚΩΔΙΚΑ ΣΕ ΠΕΡΙΠΤΩΣΗ ΣΥΝΤΑΚΤΙΚΟΥ ΣΦΑΛΜΑΤΟΣ
if (error_counter != 0 ) {
  printf("Compilation ended unsuccesfully with %d syntax errors!\n", error_counter);
  printf("Final code will not be generated.\n");
  if (argc > 1) fclose(yyin);
  return EXIT_FAILURE;
}

if (argc > 1) fclose(yyin);
    return EXIT_SUCCESS;
}