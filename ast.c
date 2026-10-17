// ΑΡΧΕΙΟ ΓΙΑ ΤΗΝ ΔΙΑΧΕΙΡΙΣΗ ΤΟΥ ΑΣΔ 

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h> // ΒΙΒΛΙΟΘΗΚΗ ΓΙΑ ΤΙΣ ΣΥΝΑΡΤΗΣΕΙΣ ΜΕ ΜΕΤΑΒΛΗΤΟ ΑΡΙΘΜΟ ΟΡΙΣΜΑΤΩΝ
#include "ast.h"

// ΣΥΝΑΡΤΗΣΗ ΜΕ ΜΕΤΑΒΛΗΤΟ ΑΡΙΘΜΟ ΟΡΙΣΜΑΤΩΝ ΓΙΑ ΤΗΝ ΚΑΤΑΣΚΕΥΗ ΚΟΜΒΩΝ ΤΟΥ ΔΕΝΔΡΟΥ
ast_node* make_ast_node(ast_node_types ast_node_type, int line_number, char* node_value, int number_of_children, ...) {
    ast_node* new_node = (ast_node*)malloc(sizeof(ast_node)); // ΔΕΥΜΕΥΣΗ ΜΝΗΜΗΣ ΓΙΑ ΚΑΙΝΟΥΡΓΙΟ ΚΟΜΒΟ
    new_node->ast_node_type = ast_node_type;
    new_node->line = line_number;
    new_node->number_of_children = number_of_children;
    new_node->expression_type = TYPE_UNKNOWN; // ΑΡΧΙΚΑ ΔΕΝ ΞΕΡΟΥΜΕ ΤΟΝ ΤΥΠΟ ΤΗΣ ΕΚΦΡΑΣΗΣ, ΘΑ ΒΡΕΘΕΙ ΑΠΟ ΣΗΜΑΣΙΟΛΟΓΙΚΗ ΑΝΑΛΥΣΗ
    new_node->stmt_next = NULL; // ΑΜΑ Ο ΚΟΜΒΟΣ ΕΙΝΑΙ ΕΚΦΡΑΣΗΣ ΤΑ ΠΕΔΙΑ ΑΥΤΑ ΠΑΡΑΜΕΝΟΥΝ null ΚΑΘΩΣ ΟΙ ΕΚΦΡΑΣΕΙΣ ΕΙΝΑΙ ΔΕΝΔΡΑ ΜΕ ΜΕΤΑΒΛΗΤΟ ΑΡΙΘΜΟ ΠΑΙΔΙΩΝ
    new_node->stmt_prev = NULL;
    if (node_value != NULL) new_node->node_value = strdup(node_value); // ΑΝ ΕΧΕΙ ΔΩΘΕΙ ΚΑΠΟΙΑ ΤΙΜΗ ΓΙΑ ΤΟΝ ΚΟΜΒΟ ΤΗΝ ΑΠΟΘΗΚΕΥΟΥΜΕ
    else new_node->node_value = NULL;
    if (number_of_children != 0) { // ΑΝ Ο ΚΟΜΒΟΣ ΕΧΕΙ ΠΑΙΔΙΑ ΔΕΝ ΕΙΝΑΙ ΔΗΛΑΔΗ ΦΥΛΛΟ
        new_node->children = (ast_node**)malloc(number_of_children * sizeof(ast_node*)); // ΔΕΥΜΕΥΣΗ ΜΝΗΜΗΣ ΓΙΑ ΤΟΝ ΠΙΝΑΚΑ ΔΕΙΚΤΩΝ ΣΕ ΔΕΙΚΤΕΣ (ΠΑΙΔΙΑ)
        va_list childrens; // ΜΕΤΑΒΛΗΤΗ ΛΙΣΤΑΣ ΤΥΠΟΥ va_list (struct), ΧΡΗΣΙΜΟΠΟΙΕΙΤΑΙ ΓΙΑ ΝΑ ΜΠΟΡΕΣΟΥΜΕ ΝΑ ΕΧΟΥΜΕ ΠΡΟΣΒΑΣΗ ΣΤΙΣ ΠΑΡΑΜΕΤΡΟΥΣ ΠΟΥ ΟΡΙΖΟΝΤΑΙ ΣΤΟ ΠΕΔΙΟ (...)
        va_start(childrens, number_of_children); // ΞΕΚΙΝΑΜΕ ΝΑ ΔΙΑΒΑΖΟΥΜΕ ΤΑ ΟΡΙΣΜΑΤΑ ΠΟΥ ΞΕΚΙΝΑΝΕ ΜΕΤΑ ΑΠΟ ΤΟ number_of_children
        for (int i = 0; i < number_of_children; i++) { // ΒΡΟΓΧΟΣ ΓΙΑ Τ0 ΠΛΗΘΟΣ ΤΩΝ ΠΑΙΔΙΩΝ
            new_node->children[i] = va_arg(childrens, ast_node*); // ΠΑΙΡΝΟΥΜΕ ΤΟ ΕΠΟΜΕΝΟ ΠΑΙΔΙ ΤΥΠΟΥ ast_node* ΚΑΙ ΤΟ ΑΠΟΘΗΚΕΥΟΥΜΕ ΣΤΟΝ ΠΙΝΑΚΑ
        }
        va_end(childrens); // ΚΑΘΑΡΙΖΟΥΜΕ ΤΗΝ ΛΙΣΤΑ ΟΡΙΣΜΑΤΩΝ/ΠΑΙΔΙΩΝ ΩΣΤΕ ΣΤΗΝ ΕΠΟΜΕΝΗ ΚΛΗΣΗ ΝΑ ΞΕΚΙΝΑΕΙ ΠΑΛΙ ΑΠΟ ΤΟ ΠΡΩΤΟ ΠΑΙΔΙ
    }
    else new_node->children = NULL; // ΚΟΜΒΟΣ ΦΥΛΛΟ, ΔΕΝ ΕΧΕΙ ΠΑΙΔΙΑ
    return new_node;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΟ ΜΑΖΕΜΑ ΤΩΝ ΠΑΡΑΜΕΤΡΩΝ ΣΥΝΑΡΤΗΣΗΣ Ή ΤΩΝ ΔΕΙΚΤΩΝ ΠΙΝΑΚΑ ΣΕ ΛΙΣΤΑ ΩΣ ΑΔΕΡΦΙΑ ΚΑΤΩ ΑΠΟ ΕΝΑΝ ΚΟΜΒΟ
// ΓΙΑ ΑΠΛΟΥΣΤΕΡΗ ΕΦΑΡΜΟΓΗ ΣΗΜΑΣΙΟΛΟΓΙΚΩΝ ΚΑΝΟΝΩΝ ΚΑΙ ΜΕΓΑΛΥΤΕΡΗ ΑΝΑΓΝΩΣΙΜΟΤΗΤΑ ΣΤΟ ΑΣΔ
ast_node* append_child(ast_node* parent, ast_node* new_child){
    if (parent == NULL) return new_child;
    if (new_child == NULL) return parent;
    if (parent == NULL && new_child == NULL) return NULL;
    parent->number_of_children++;
    // ΕΠΑΝΑΔΕΥΜΕΥΣΗ ΜΝΗΜΗΣ ΩΣΤΕ ΝΑ ΧΩΡΕΣΕΙ ΤΟ ΝΕΟ ΠΑΙΔΙ
    parent->children = (ast_node**)realloc(parent->children, parent->number_of_children * sizeof(ast_node*));
    parent->children[parent->number_of_children - 1] = new_child; // ΤΟΠΟΘΕΤΗΣΗ ΠΑΙΔΙΟΥ ΣΤΟ ΤΕΛΟΣ ΤΗΣ ΛΙΣΤΑΣ, ΣΤΗΝ ΝΕΑ ΘΕΣΗ ΠΟΥ ΔΕΥΜΕΥΣΤΗΚΕ
    return parent;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΔΗΜΙΟΥΡΓΙΑ ΛΙΣΤΑΣ ΕΝΤΟΛΩΝ, ΕΠΙΣΤΡΕΦΕΙ ΤΗΝ ΚΟΡΥΦΗ ΤΗΣ ΛΙΣΤΑΣ  
ast_node* make_stmt_list(ast_node* stmt_list_head, ast_node* next_stmt){
    if (stmt_list_head == NULL) return next_stmt;
    if (next_stmt == NULL) return stmt_list_head;
    ast_node* list_temp = stmt_list_head;
    while(list_temp->stmt_next != NULL) {
      list_temp = list_temp->stmt_next; // ΒΡΙΣΚΟΥΜΕ ΤΟ ΤΕΛΟΣ ΤΗΣ ΛΙΣΤΑΣ ΕΝΤΟΛΩΝ
    }
    list_temp->stmt_next = next_stmt; // ΤΟΠΟΘΕΤΗΣΗ ΝΕΑΣ ΕΝΤΟΛΗΣ ΣΤΟ ΤΕΛΟΣ ΤΗΣ ΛΙΣΤΑΣ 
    next_stmt->stmt_prev = list_temp; // ΡΥΘΜΙΣΗ ΔΕΙΚΤΗ ΠΡΟΗΓΟΥΜΕΝΗΣ ΕΝΤΟΛΗΣ
    return stmt_list_head; // ΕΠΙΣΤΡΟΦΗ ΤΗΣ ΚΕΦΑΛΗΣ ΤΗΣ ΝΕΑΣ ΛΙΣΤΑΣ
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΕΚΤΥΠΩΣΗ ΤΟΥ ast ΣΕ ΠΡΟΔΙΑΤΕΤΑΓΜΕΝΗ ΣΕΙΡΑ depth-first-search (root->left->right)
void print_ast(ast_node* start_node, int depth){
    if (start_node == NULL) return;
    ast_node* curr = start_node;
    while (curr != NULL) { // ΔΙΑΣΧΙΖΟΥΜΕ ΤΗΝ ΛΙΣΤΑ ΕΝΤΟΛΩΝ ΟΡΙΖΟΝΤΙΑ
      for (int i = 0; i < depth; i++) printf("  "); // ΕΚΤΥΠΩΣΗ ΚΕΝΩΝ ΓΙΑ identantion ΑΝΑΛΟΓΑ ΜΕ ΤΟ ΒΑΘΟΣ, ΑΥΞΑΝΕΤΑΙ ΤΟ ΒΑΘΟΣ ΑΥΞΑΝΟΝΤΑΙ ΚΑΙ ΤΑ ΚΕΝΑ ΑΠΟ ΤΗΝ ΑΡΧΗ ΤΗΣ ΓΡΑΜΜΗΣ
      switch(curr->ast_node_type) {
        case AST_CONST: 
          printf("[CONST: %s]\n", curr->node_value);
          break;
        case AST_VAR:
          printf("[VAR: %s]\n", curr->node_value);
          break;
        case AST_BINOP:
          printf("[BINOP: %s]\n", curr->node_value);
          break;
        case AST_UNOP:
          printf("[UNOP: %s]\n", curr->node_value);
          break;
        case AST_LENGTH:
          printf("[%s]\n", curr->node_value);
          break;
        case AST_COMPLEX_MAKE:
          printf("[MAKE_COMPLEX: %s]\n", curr->node_value);
          break;
        case AST_LIST_MAKE:
          printf("[MAKE_LIST: %s]\n", curr->node_value);
          break;
        case AST_LISTFUNC:
          printf("[LISTFUNC: %s]\n", curr->node_value);
          break;
        case AST_ARRAY_OR_FUNC:
          printf("[ARRAYorFUNC: %s]\n", curr->node_value);
          break;
        case AST_EXPR_LIST:
          printf("[EXPR LIST: %s]\n", curr->node_value);
          break;
        case AST_ASSIGN:
          printf("[ASSIGN: %s]\n", curr->node_value);
          break;
        case AST_LABELED_STMT: 
          printf("[LABELED STMT: %s]\n", curr->node_value); 
          break;
        case AST_BRANCH:           
          printf("[BRANCH]\n"); 
          break;
        case AST_ARTM_IF:           
          printf("[IF ARTM STMT]\n"); 
          break;
        case AST_LOG_IF:           
          printf("[IF LOG STMT]\n"); 
          break;
        case AST_LOOP:           
          printf("[LOOP]\n"); 
          break;
        case AST_IMPLIED_LOOP:           
          printf("[IMPLIED LOOP]\n"); 
          break;
        case AST_GOTO:         
          printf("[GOTO STMT]\n"); 
          break;
        case AST_COMPUTED_GOTO:         
          printf("[CPT GOTO STMT]\n"); 
          break;
        case AST_CONTINUE:     
          printf("[CONTINUE STMT]\n"); 
          break;
        case AST_RETURN:       
          printf("[RETURN STMT]\n"); 
          break;
        case AST_STOP:         
          printf("[STOP STMT]\n"); 
          break;
        case AST_CALL:         
          printf("[CALL STMT]\n"); 
          break;
        case AST_READ:         
          printf("[READ STMT]\n"); 
          break;
        case AST_WRITE:         
          printf("[WRITE STMT]\n"); 
          break;
        case AST_IO_LIST:         
          printf("[IO LIST]\n"); 
          break;
        case AST_ITER_SPACE:         
          printf("[ITER SPACE]\n"); 
          break;
        case AST_LABEL:         
          printf("[LABEL: %s]\n", curr->node_value); 
          break;
        case AST_LABEL_LIST:         
          printf("[LABEL LIST]\n"); 
          break;
        case AST_PROGRAM:         
          printf("[PROGRAM]\n"); 
          break;
        case AST_SUBPROGRAM:         
          printf("[SUBPRG: %s]\n", curr->node_value); 
          break;
      }
      for (int i = 0; i < curr->number_of_children; i++) { // ΑΝΑΔΡΟΜΙΚΗ ΚΛΗΣΗ ΤΗΣ ΣΥΝΑΡΤΗΣΗΣ ΓΙΑ ΤΑ ΠΑΙΔΙΑ ΤΟΥ ΚΟΜΒΟΥ ΕΝΤΟΛΗΣ
        print_ast(curr->children[i], depth + 1);
      }
      curr = curr->stmt_next; // ΠΡΟΧΩΡΑΜΕ ΣΤΗΝ ΕΠΟΜΕΝΗ ΕΝΤΟΛΗ ΤΗΣ ΛΙΣΤΑΣ ΣΤΟ ΙΔΙΟ ΕΠΙΠΕΔΟ
    }
}

