#ifndef AST_H
#define AST_H

#include "types.h"

ast_node* make_ast_node(ast_node_types ast_node_type, int line_number, char* node_value, int number_of_children, ...);
ast_node* append_child(ast_node* parent, ast_node* new_child);
void print_ast(ast_node* start_node, int depth);
ast_node* make_stmt_list(ast_node* stmt_list_head, ast_node* next_stmt);

#endif