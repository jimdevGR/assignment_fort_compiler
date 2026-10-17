#include <stdio.h>
#include <stdlib.h>
#include <string.h> // ΠΕΡΙΕΧΕΙ strcasecmp
#include "symbol_table.h"

// ΑΠΟ ΤΟ bison
extern void semantic_error(const char* message, int line_error_occured, char* variable_name);
extern char* undefined_label_msg;

// ΠΣ, ΣΤΟΙΒΑ ΜΕ ΔΕΙΚΤΕΣ ΣΕ ΔΥΝΑΜΙΚΕΣ ΣΥΝΔΕΔΕΜΕΝΕΣ ΛΙΣΤΕΣ, ΚΑΘΕ ΕΠΙΠΕΔΟ ΤΗΣ ΣΤΟΙΒΑΣ ΚΑΙ ΜΙΑ ΝΕΑ ΕΜΒΕΛΕΙΑ
// ΟΙ ΕΜΒΕΛΕΙΕΣ ΑΥΞΑΝΟΝΤΑΙ ΑΠΟ ΚΑΤΩ ΠΡΟΣ ΤΑ ΠΑΝΩ ΣΤΗΝ ΣΤΟΙΒΑ
symbol_node* symbol_stack[STACK_SIZE]; 
int current_scope = 0;

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΑΡΧΙΚΟΠΟΙΗΣΗ ΤΟΥ ΠΣ
void init_symbol_table() {
    current_scope = 0;
    for (int i = current_scope; i < STACK_SIZE; i++) {
        symbol_stack[i] = NULL; // ΑΡΧΙΚΑ ΚΑΘΕ ΔΕΙΚΤΗΣ ΤΗΣ ΣΤΟΙΒΑΣ ΔΕΝ ΔΕΙΧΝΕΙ ΚΑΠΟΥ, ΑΔΕΙΟΣ ΠΣ
    }
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΠΡΟΣΘΗΚΗ ΝΕΑΣ ΕΜΒΕΛΕΙΑΣ ΣΤΟΝ ΠΣ
void create_new_scope() {
    if (current_scope < STACK_SIZE -1) {
        current_scope++;
        symbol_stack[current_scope] = NULL;
    }
    else {
        perror("Failed to create new scope in stack");
        exit(EXIT_FAILURE);
    }
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΑΝΑΖΗΤΗΣΗ ΑΝΑΓΝΩΡΙΣΤΙΚΟΥ ΜΕ ΒΑΣΗ ΤΟ ΟΝΟΜΑ ΣΤΗΝ ΤΩΡΙΝΗ ΕΜΒΕΛΕΙΑ
symbol_node* search_current_scope(const char* s) {
    if (s == NULL) return NULL;
    symbol_node* temp = symbol_stack[current_scope];
    while (temp != NULL) {
        if (strcasecmp(temp->id_name, s) == 0) return temp; // ΣΥΓΚΡΙΣΗ ΑΝΕΞΑΡΤΗΤΩΣ ΜΙΚΡΩΝ ΚΕΦΑΛΑΙΩΝ, Η fort ΕΙΝΑΙ case-insensitive
        else temp = temp->next;
    }
    return NULL;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΑΝΑΖΗΤΗΣΗ ΑΝΑΓΝΩΡΙΣΤΙΚΟΥ ΜΕ ΒΑΣΗ ΤΟ ΟΝΟΜΑ ΣΕ ΟΛΕΣ ΤΙΣ ΕΜΒΕΛΕΙΕΣ
symbol_node* search_all_scopes(const char* s) {
    if (s == NULL) return NULL;
    for (int i = current_scope; i >= 0; i--) {
        symbol_node* temp = symbol_stack[i];
        while (temp != NULL) {
            if (strcasecmp(temp->id_name, s) == 0) return temp;
            else temp = temp->next;
        }
    }
    return NULL;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΤΟΠΟΘΕΤΗΣΗ ΝΕΟΥ ΑΝΑΓΝΩΡΙΣΤΙΚΟΥ ΣΕ ΛΙΣΤΑ ΤΗΣ ΣΤΟΙΒΑΣ
symbol_node* insert_new_symbol(const char* s, int line) {
    if (s == NULL) return NULL;
    symbol_node* new_symbol_node = (symbol_node*)malloc(sizeof(symbol_node));
    if (new_symbol_node == NULL) {
        perror("Failed to allocate memory for new node");
        exit(EXIT_FAILURE);
    }
    new_symbol_node->id_name = strdup(s);
    new_symbol_node->symbol_scope = current_scope;

    // ΑΡΧΙΚΟΠΟΙΗΣΗ ΠΕΔΙΩΝ ΣΥΜΒΟΛΟΥ
    new_symbol_node->category = VAR;
    new_symbol_node->id_type = TYPE_UNKNOWN; // 0
    new_symbol_node->is_list = 0;
    new_symbol_node->is_array = 0;
    new_symbol_node->param_total = 0;
    new_symbol_node->params = NULL;
    new_symbol_node->init_value = NULL;
    new_symbol_node->is_label_defined = 0;
    new_symbol_node->is_assigned = 0;
    new_symbol_node->line_number = line;

    // ΤΟΠΟΘΕΤΗΣΗ ΝΕΟΥ ΚΟΜΒΟΥ ΣΤΗΝ ΑΡΧΗ ΤΗΣ ΛΙΣΤΑΣ
    new_symbol_node->next = symbol_stack[current_scope];
    symbol_stack[current_scope] = new_symbol_node;

    return new_symbol_node;
}

// ΣΥΝΑΡΤΗΣΗ ΓΙΑ ΤΗΝ ΕΞΟΔΟ ΑΠΟ ΕΜΒΕΛΕΙΑ ΚΑΙ ΤΗΝ ΕΚΤΥΠΩΣΗ ΤΩΝ ΠΕΡΙΕΧΟΜΕΝΩΝ ΑΥΤΗΣ
void exit_print_scope() {
    printf("  ---SCOPED CLOSED!---  \n");
    printf("Scope (%d) closed, below you can see the identifiers of this scope: \n", current_scope);
    symbol_node* temp = symbol_stack[current_scope];
    if (temp == NULL) printf("This scope does not contain any new identifiers...\n");
    else printf("%-14s | %-13s | %-11s | %-s\n", "Name", "Category", "Type", "More Details");
    const char* category_strings[] = {"VARIABLE", "FUNCTION", "SUBROUTINE", "LABEL", "COMMON BLOCK"};
    const char* type_strings[] = {"UNKNOWN", "INTEGER", "REAL", "COMPLEX", "LOGICAL", "CHARACTER", "STRING"};
    while (temp != NULL) {
        // ΣΤΟ ΚΛΕΙΣΙΜΟ ΤΗΣ ΕΜΒΕΛΕΙΑΣ ΕΛΕΓΧΟΣ ΑΝ ΕΜΕΙΝΑΝ ΕΤΙΚΕΤΕΣ ΠΟΥ ΧΡΗΣΙΜΟΠΟΙΗΘΗΚΑΝ ΑΛΛΑ ΔΕΝ ΟΡΙΣΤΗΚΑΝ ΠΟΥΘΕΝΑ ΣΕ ΑΥΤΗΝ
        if (temp->category == LABEL && temp->is_label_defined == 0) semantic_error(undefined_label_msg, temp->line_number, temp->id_name); 
        else printf("%-14s | %-13s | %-11s | ",temp->id_name, category_strings[temp->category], type_strings[temp->id_type]);
        if (temp->category == VAR) {
            if (temp->is_array == 1) { // ΠΙΝΑΚΕΣ
                printf("ARRAY ");
                array_init_node* temp_val = temp->array_init_values;
                if (temp_val != NULL) printf("with Values: ");
                while (temp_val != NULL) {
                    printf("%s", temp_val->array_value);
                    if (temp_val->array_next != NULL) printf(", ");
                    temp_val = temp_val->array_next;
                }
            }
            if (temp->is_list == 1) printf("LIST ");
            if (temp->init_value != NULL) printf("Value: %s", temp->init_value); // ΒΑΘΜΩΤΕΣ ΜΕΤΑΒΛΗΤΕΣ
        }
        else if (temp->category == SUBR || temp->category == FUNC) {
            param_node* p_node = temp->params;
            printf("Params: %d - (", temp->param_total);
            while(p_node != NULL) {
                printf("%s:%s:%s", p_node->p_name, type_strings[p_node->param_type], p_node->param_pass_style == PASS_BY_REF ? "REF" : "VALUE");
                if (p_node->next != NULL) printf(", ");
                p_node = p_node->next;
            }
            printf(")");
        }
        else if (temp->category == LABEL) {
            printf("%s", temp->is_label_defined == 1 ? "DEFINED" : "REFERENCED ONLY");
        }
        printf("\n");

        symbol_node* del = temp;
        temp = temp->next;
        free(del->id_name); // ΑΠΕΛΕΥΘΕΡΩΣΗ ΤΟΥ COPY ΠΟΥ ΕΓΙΝΕ ΜΕ ΤΗΝ strdup ΣΤΗΝ insert
        if (del->init_value != NULL) free(del->init_value);
        param_node* p_node = del->params;
        while (p_node != NULL) { // ΑΠΕΛΕΥΘΕΡΩΣΗ ΚΟΜΒΩΝ ΠΑΡΑΜΕΤΡΩΝ
            param_node* p_del = p_node;
            p_node = p_node->next;
            free(p_del->p_name);
            free(p_del);
        }
        free(del); // ΑΠΕΛΕΥΘΕΡΩΣΗ ΤΟΥ ΥΠΟΛΟΙΠΟΥ ΚΟΜΒΟΥ Η ΠΛΗΡΟΦΟΡΙΑ ΤΟΥ ΟΠΟΙΟΥ ΕΚΤΥΠΩΘΗΚΕ
    }
    printf("******************************************************************************\n");
    symbol_stack[current_scope] = NULL;
    current_scope--;
}

