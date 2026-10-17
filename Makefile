CFLAGS = -Wall -g # FLAGS, ΓΙΑ DEBUGGING (-g) ΚΑΙ ΓΙΑ ΝΑ ΜΑΣ ΔΕΙΧΝΕΙ ΟΛΑ ΤΑ WARNINGS O gcc (-Wall)
EXECUTABLE = fort_compiler
# .ο ΑΡΧΕΙΑ ΓΙΑ ΝΑ ΜΗΝ ΧΡΕΙΑΖΕΤΑΙ ΤΟ make ΝΑ ΚΑΝΕΙ COMPILE ΟΛΑ ΤΑ .c ΚΑΘΕ ΦΟΡΑ ΠΟΥ ΤΡΕΧΟΥΜΕ ΤΗΝ 
# ΕΝΤΟΛΗ "make", ΑΛΛΑ ΜΟΝΟ ΑΥΤΑ ΠΟΥ ΕΧΟΥΝ ΑΛΛΑΞΕΙ
# ΜΕ ΤΗΝ ΠΑΡΑΚΑΤΩ ΕΝΤΟΛΗ ΠΡΑΓΜΑΤΟΠΟΙΕΙΤΑΙ ΑΠΛΑ LINKING ΤΩΝ ΑΡΧΕΙΩΝ
DEPENDENCIES = lex.yy.o fort_syntax_analyzer.tab.o symbol_table.o ast.o 

# ΕΚΤΕΛΕΙΤΑΙ ΟΤΑΝ ΤΡΕΧΟΥΜΕ ΤΗΝ ΕΝΤΟΛΗ "make" ΧΩΡΙΣ ΟΡΙΣΜΕΝΟ TARGET 
all: $(EXECUTABLE)

$(EXECUTABLE): $(DEPENDENCIES)
	gcc $(CFLAGS) $(DEPENDENCIES) -o $(EXECUTABLE) 

# -d ΓΙΑ ΝΑ ΠΑΡΟΥΜΕ ΤΟ .h ΚΑΙ -v ΓΙΑ ΝΑ ΠΑΡΟΥΜΕ ΤΟ .output
fort_syntax_analyzer.tab.c fort_syntax_analyzer.tab.h: fort_syntax_analyzer.y
	bison -d -v fort_syntax_analyzer.y 

lex.yy.c: fort_lexer.l
	flex fort_lexer.l

# ΤΟ ΕΡΓΑΛΕΙΟ make ΞΕΡΕΙ ΑΠΟ ΜΟΝΟ ΤΟΥ ΠΩΣ ΝΑ ΦΤΙΑΧΝΕΙ .o ΑΠΟ .c
# ΑΚΟΜΑ ΑΝΑΓΝΩΡΙΖΕΙ ΠΟΤΕ ΧΡΕΙΑΖΕΤΑΙ ΝΑ ΠΑΡΑΞΕΙ ΞΑΝΑ .o ΑΠΟ .c ΚΑΙ ΠΟΤΕ ΟΧΙ
# ΑΝΑΛΟΓΑ ΜΕ ΤΟ ΑΝ ΕΧΟΥΝ ΣΥΜΒΕΙ ΑΛΛΑΓΕΣ Η ΟΧΙ ΣΤΑ ΑΡΧΕΙΑ .c Η .h ΠΟΥ 
# ΕΙΝΑΙ ΑΝΑΓΚΑΙΑ ΓΙΑ ΤΗ ΔΗΜΙΟΥΡΓΙΑ ΤΟΥ .o

lex.yy.o: fort_syntax_analyzer.tab.h types.h
fort_syntax_analyzer.tab.o: fort_syntax_analyzer.tab.h symbol_table.h ast.h types.h
symbol_table.o: symbol_table.h types.h
ast.o: types.h ast.h

# ΕΚΤΕΛΕΙΤΑΙ ΟΤΑΝ ΤΡΕΧΟΥΜΕ ΤΗΝ ΕΝΤΟΛΗ "make clean_files"
clean_files:
	rm -f $(EXECUTABLE) $(DEPENDENCIES) lex.yy.c fort_syntax_analyzer.tab.c fort_syntax_analyzer.tab.h fort_syntax_analyzer.output