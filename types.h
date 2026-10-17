#ifndef TYPES_H // ΓΙΑ ΝΑ ΜΗΝ ΔΙΑΒΑΣΤΟΥΝ ΤΑ ΠΕΡΙΕΧΟΜΕΝΑ ΠΑΝΩ ΑΠΟ ΜΙΑ ΦΟΡΕΣ
#define TYPES_H

// ΠΡΟΔΗΛΩΣΗ ΔΟΜΩΝ
struct symbol_node;
struct param_node;

// enum ΓΙΑ ΤΟΥΣ ΤΥΠΟΥΣ ΤΗΣ FORT
typedef enum {
    TYPE_UNKNOWN, // 0 
    TYPE_INTEGER, // 1
    TYPE_REAL, // 2
    TYPE_COMPLEX, // 3
    TYPE_LOGICAL, // 4
    TYPE_CHARACTER, // 5
    TYPE_STRING // 6
}fort_types;

// enum ΓΙΑ ΤΗΝ ΚΩΔΙΚΟΠΟΙΗΣΗ ΤΩΝ ΑΝΑΓΝΩΡΙΣΤΙΚΩΝ
typedef enum { 
    VAR, // VARIABLE 
    FUNC, // FUNCTION
    SUBR, // SUBROUTINE
    LABEL, 
    COMMON_BLOCK 
} id_category;

// enum ΓΙΑ ΤΗΝ ΜΕΘΟΔΟ ΠΕΡΑΣΜΑΤΟΣ ΤΩΝ ΠΑΡΑΜΕΤΡΩΝ
typedef enum { 
    PASS_BY_VALUE, // ΠΕΡΑΣΜΑ ΜΕ ΤΙΜΗ 
    PASS_BY_REF // ΠΕΡΑΣΜΑ ΜΕ ΑΝΑΦΟΡΑ
} pass_style;

// ΔΟΜΗ ΓΙΑ ΤΙΣ ΑΡΧΙΚΕΣ ΤΙΜΕΣ ΠΙΝΑΚΑ
typedef struct array_init_node {
    char* array_value;
    fort_types type;
    int repeat_count; // ΠΑΡΑΓΟΝΤΑΣ ΕΠΑΝΑΛΗΨΗΣ (Π.Χ 4 για '4*2'), ΑΝ ΕΙΝΑΙ 0 ΔΕΝ ΕΧΟΥΜΕ ΠΑΡΑΓΟΝΤΑ
    int plain_asterisk; // flag, 1 ΑΝ ΥΠΑΡΧΕΙ '*' ΧΩΡΙΣ ΠΑΡΑΓΟΝΤΑ ΕΠΑΝΑΛΗΨΗΣ (Π.Χ '*1'), 0 ΑΛΛΙΩΣ
    struct array_init_node* array_next;
} array_init_node;

// enum ΓΙΑ ΤΟΥΣ ΤΥΠΟΥΣ ΤΩΝ ΚΟΜΒΩΝ ΤΟΥ ΑΣΔ
typedef enum {
    AST_CONST, // ΚΟΜΒΟΣ ΣΤΑΘΕΡΩΝ
    AST_VAR, // ΚΟΜΒΟΣ ΜΕΤΑΒΛΗΤΩΝ
    AST_BINOP, // ΚΟΜΒΟΣ ΔΥΑΔΙΚΩΝ ΠΡΑΞΕΩΝ
    AST_UNOP, // ΚΟΜΒΟΣ ΜΟΝΑΔΙΑΙΩΝ ΠΡΑΞΕΩΝ
    AST_LENGTH, // ΚΟΜΒΟΣ ΓΙΑ ΤΗΝ ΕΙΔΙΚΗ ΣΥΝΑΡΤΗΣΗ LENGTH
    AST_COMPLEX_MAKE, // ΚΟΜΒΟΣ ΓΙΑ ΤΟΝ ΤΕΛΕΣΤΗ ΔΗΜΙΟΥΡΓΙΑΣ ΜΙΓΑΔΙΚΟΥ ΑΡΙΘΜΟΥ
    AST_LIST_MAKE, // ΚΟΜΒΟΣ ΓΙΑ ΤΟΝ ΤΕΛΕΣΤΗ ΣΥΝΘΕΣΗΣ ΛΙΣΤΑΣ
    AST_LISTFUNC, // ΚΟΜΒΟΣ ΓΙΑ ΤΙΣ ΕΙΔΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ ΛΙΣΤΑΣ
    AST_ARRAY_OR_FUNC, // ΚΟΜΒΟΣ ΓΙΑ ΚΛΗΣΗ ΣΥΝΑΡΤΗΣΗΣ Η ΧΡΗΣΗ ΠΙΝΑΚΑ
    AST_EXPR_LIST, // ΚΟΜΒΟΣ ΠΟΥ ΚΡΑΤΑΕΙ ΤΙΣ ΕΚΦΡΑΣΕΙΣ ΣΕ ΔΥΝΑΜΙΚΗ ΛΙΣΤΑ
    AST_ASSIGN, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ assignment
    AST_LABELED_STMT, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ ΜΕ ΕΤΙΚΕΤΑ
    AST_BRANCH, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ IF, ΜΕ THEN/ELSE
    AST_ARTM_IF, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ IF ΑΠΛΗΣ ΑΡΙΘΜΗΤΙΚΗΣ
    AST_LOG_IF, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ IF ΑΠΛΗΣ ΛΟΓΙΚΗΣ
    AST_LOOP, // ΚΟΜΒΟΣ ΒΡΟΓΧΟΥ DO
    AST_IMPLIED_LOOP, // ΚΟΜΒΟΣ ΥΠΟΝΟΟΥΜΕΝΟ ΒΡΟΧΟΥ DO
    AST_GOTO, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ GOTO
    AST_COMPUTED_GOTO, // ΚΟΜΒΟΣ ΓΙΑ ΤΟ ΥΠΟΛΟΓΙΖΟΜΕΝΟ GOTO
    AST_CONTINUE, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ CONTINUE
    AST_RETURN, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ RETURN
    AST_STOP, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ STOP
    AST_CALL, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ CALL, ΚΛΗΣΗ ΥΠΟΡΟΥΤΙΝΑΣ 
    AST_READ, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ READ
    AST_WRITE, // ΚΟΜΒΟΣ ΕΝΤΟΛΗΣ WRITE
    AST_IO_LIST, // ΚΟΜΒΟΣ ΛΙΣΤΑΣ ΜΕΤΑΒΛΗΤΩΝ-ΕΚΦΡΑΣΕΩΝ ΠΡΟΣ ΑΝΑΓΝΩΣΗ-ΕΓΓΡΑΦΗ
    AST_ITER_SPACE, // ΚΟΜΒΟΣ ΓΙΑ ΤΟΝ ΧΩΡΟ ΕΠΑΝΑΛΗΨΗΣ ΜΙΑΣ ΛΟΥΠΑΣ
    AST_LABEL, // ΚΟΜΒΟΣ ΓΙΑ ΑΠΛΗ ΕΤΙΚΕΤΑ
    AST_LABEL_LIST, // ΚΟΜΒΟΣ ΠΟΥ ΚΡΑΤΑΕΙ ΤΙΣ ΕΤΙΚΕΤΕΣ ΣΕ ΛΙΣΤΑ
    AST_PROGRAM, // ΚΟΜΒΟΣ ΓΙΑ ΟΛΟ ΤΟ ΠΡΟΓΡΑΜΜΑ
    AST_SUBPROGRAM, // ΚΟΜΒΟΣ ΓΙΑ ΥΠΟΠΡΟΓΡΑΜΜΑ
}ast_node_types;

// struct ΓΙΑ ΤΟΥΣ ΚΟΜΒΟΥΣ ΤΟΥ AST ΜΕ ΤΗΝ ΑΠΑΡΑΙΤΗΤΗ ΠΛΗΡΟΦΟΡΙΑ
typedef struct ast_node{
    ast_node_types ast_node_type;
    int line; // ΚΡΑΤΑΜΕ ΤΗΝ ΓΡΑΜΜΗ ΤΟΥ ΚΟΜΒΟΥ ΣΤΟΝ ΠΗΓΑΙΑΟ ΚΩΔΙΚΑ ΓΙΑ ΕΚΤΥΠΩΣΗ ΣΦΑΛΜΑΤΩΝ
    char* node_value;
    fort_types expression_type; // ΤΥΠΟΣ ΤΗΣ ΕΚΦΡΑΣΗΣ (ΕΓΓΡΑΦΕΤΑΙ ΚΑΤΑ ΤΗΝ ΣΗΜΑΣΙΟΛΟΓΙΚΗ ΑΝΑΛΥΣΗ)

    // ΚΑΘΕΤΗ ΔΙΑΣΤΑΣΗ ΔΕΝΔΡΟΥ, ΓΙΑ ΕΚΦΡΑΣΕΙΣ (ΔΕΝΔΡΟ ΜΕ ΜΕΤΑΒΛΗΤΟ ΑΡΙΘΜΟ ΠΑΙΔΙΩΝ)
    int number_of_children;
    struct ast_node** children; // ΔΥΝΑΜΙΚΟΣ ΠΙΝΑΚΑΣ ΜΕ ΔΕΙΚΤΕΣ ΣΕ ΔΕΙΚΤΕΣ (ΣΤΑ ΠΑΙΔΙΑ ΤΟΥ ΚΟΜΒΟΥ)
    
    // ΟΡΙΖΟΝΤΙΑ ΔΙΑΣΤΑΣΗ ΔΕΝΔΡΟΥ, ΓΙΑ ΕΝΤΟΛΕΣ (ΛΙΣΤΑ ΕΝΤΟΛΩΝ)
    struct ast_node* stmt_next; // ΔΕΙΚΤΗΣ ΣΤΗΝ ΕΠΟΜΕΝΗ ΕΝΤΟΛΗ ΣΤΟ ΙΔΙΟ ΕΠΙΠΕΔΟ
    struct ast_node* stmt_prev; // ΔΕΙΚΤΗΣ ΣΤΗΝ ΠΡΟΗΓΟΥΜΕΝΗ ΕΝΤΟΛΗ ΣΤΟ ΙΔΙΟ ΕΠΙΠΕΔΟ
}ast_node;

// struct ΓΙΑ ΤΑ ΚΑΤΗΓΟΡΗΜΑΤΑ ΚΑΘΕ ΣΥΜΒΟΛΟΥ
typedef struct {
    char* stringValue;
    int intValue;
    double realValue;
    fort_types id_type;
    int is_list; // flag ΑΝ ΕΙΝΑΙ ΛΙΣΤΑ
    int dim_count; // ΜΕΤΡΗΤΗΣ ΠΛΗΘΟΥΣ ΔΙΑΣΤΑΣΕΩΝ ΠΙΝΑΚΑ 
    struct symbol_node* sym_node_list; // ΛΙΣΤΑ ΚΟΜΒΩΝ ΓΙΑ ΝΑ ΠΕΡΝΑΜΕ ΠΟΛΛΑΠΛΑ ΑΝΑΓΝΩΡΙΣΤΙΚΑ ΑΠΟ "ΚΑΤΩ" ΚΑΝΟΝΕΣ ΣΕ "ΠΑΝΩ"
    struct param_node* p_node_list; // ΛΙΣΤΑ ΠΑΡΑΜΕΤΡΩΝ
    struct symbol_node* temp_node; // ΔΕΙΚΤΗΣ ΓΙΑ ΤΗΝ ΜΕΤΑΦΟΡΑ ΚΟΜΒΟΥ ΜΕΣΑ ΣΤΟ bison Π.Χ ΥΠΟΡΟΥΤΙΝΑΣ
    array_init_node* temp_array_val_list; // ΔΕΙΚΤΗΣ ΣΕ ΠΡΟΣΩΡΙΝΗ ΛΙΣΤΑ ΑΡΧΙΚΩΝ ΤΙΜΩΝ ΠΙΝΑΚΑ
    int repeat_count; // ΒΛΕΠΕ ΔΟΜΗ array_init_node
    int plain_asterisk; // ΒΛΕΠΕ ΔΟΜΗ array_init_node
    ast_node* ast_node;
    int line_counter;
    int dataORcommon_declaration; // flag ΓΙΑ ΕΛΕΓΧΟ ΥΠΑΡΞΗΣ ΔΗΛΩΣΗΣ ΑΠΟΔΟΣΗΣ ΑΡΧΙΚΩΝ ΤΙΜΩΝ Ή ΔΗΛΩΣΗΣ ΚΟΙΝΗΣ ΠΕΡΙΟΧΗΣ
    int virtual_dim; // flag ΓΙΑ ΕΛΕΓΧΟ ΑΝ Ο ΠΙΝΑΚΑΣ ΕΧΕΙ ΔΗΛΩΘΕΙ ΜΕ ΕΙΚΟΝΙΚΗ ΔΙΑΣΤΑΣΗ
}semantic_attributes;

#endif