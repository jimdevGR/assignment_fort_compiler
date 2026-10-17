#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include "types.h"

#define STACK_SIZE 100

// struct ΓΙΑ ΚΟΜΒΟ ΠΑΡΑΜΕΤΡΟΥ
typedef struct param_node{
    fort_types param_type; // ΤΥΠΟΣ ΠΑΡΑΜΕΤΡΟΥ
    pass_style param_pass_style; // ΜΕΘΟΔΟΣ ΠΕΡΑΣΜΑΤΟΣ
    char* p_name; // ΟΝΟΜΑ ΠΑΡΑΜΕΤΡΟΥ
    struct param_node* next;
} param_node;

// struct ΓΙΑ ΚΟΜΒΟ ΠΣ
typedef struct symbol_node{
    char* id_name;
    int symbol_scope;
    struct symbol_node* next; // ΓΙΑ ΕΣΩΤΕΡΙΚΗ ΧΡΗΣΗ ΣΤΟΝ ΠΣ
    struct symbol_node* temp_next; // ΓΙΑ ΤΗΝ ΔΗΜΙΟΥΡΓΙΑ ΠΡΟΣΩΡΙΝΩΝ ΛΙΣΤΩΝ ΣΤΟ bison ΓΙΑ ΤΗΝ ΔΙΑΤΗΡΗΣΗ ΜΕΤΑΒΛΗΤΩΝ ΙΔΙΟΥ ΤΥΠΟΥ
    id_category category;
    fort_types id_type;
    int is_list; // flag ΓΙΑ ΕΛΕΓΧΟ ΑΝ ΕΙΝΑΙ ΛΙΣΤΑ
    int is_array; // flag ΓΙΑ ΕΛΕΓΧΟ ΑΝ ΕΙΝΑΙ ΠΙΝΑΚΑΣ
    int param_total;
    param_node* params; // ΔΕΙΚΤΗΣ ΣΕ ΛΙΣΤΑ ΠΑΡΑΜΕΤΡΩΝ ΓΙΑ ΠΕΡΙΠΤΩΣΗ SUBROUTINE/FUNCTION
    char* init_value; // ΑΡΧΙΚΗ ΤΙΜΗ ΓΙΑ ΒΑΘΜΩΤΕΣ ΜΕΤΑΒΛΗΤΕΣ
    struct array_init_node* array_init_values; // ΑΡΧΙΚΕΣ ΤΙΜΕΣ - ΛΙΣΤΑ (ΓΙΑ ΠΙΝΑΚΕΣ)
    int is_label_defined; // flag ΓΙΑ ΕΛΕΓΧΟ ΟΡΙΣΜΟΥ LABEL
    int is_assigned; // flag ΓΙΑ ΕΛΕΓΧΟ ΑΝ ΥΠΗΡΞΕ ΑΝΑΘΕΣΗ ΤΙΜΗΣ
    int line_number; // ΠΕΔΙΟ ΓΙΑ ΤΗΝ ΚΑΤΑΓΡΑΦΗ ΤΗΣ ΓΡΑΜΜΗΣ ΠΟΥ ΣΥΝΑΝΤΗΘΗΚΕ ΤΟ ΑΝΑΓΝΩΡΙΣΤΙΚΟ
    int virtual_dim; // flag ΓΙΑ ΕΛΕΓΧΟ ΑΝ Ο ΠΙΝΑΚΑΣ ΕΧΕΙ ΔΗΛΩΘΕΙ ΜΕ ΕΙΚΟΝΙΚΗ ΔΙΑΣΤΑΣΗ
}symbol_node;

// ΣΥΝΑΡΤΗΣΕΙΣ ΠΣ
void init_symbol_table();
void create_new_scope();
symbol_node* search_current_scope(const char* s);
symbol_node* search_all_scopes(const char* s);
symbol_node* insert_new_symbol(const char* s, int line);
void exit_print_scope();

#endif