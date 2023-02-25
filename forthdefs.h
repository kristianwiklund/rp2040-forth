// ascii definitions of forth words that run on startup
// final word must end with 0 (hence asciz)
// intermediate must have a space at the end to get the parser working

// math
.ascii ": / /MOD SWAP DROP ; "
.ascii ": MOD /MOD DROP  ; "
.ascii ": 0= 0 = ; "
.ascii ": NOT 0= ; "
.ascii ": <= > NOT ; "
.ascii ": >= < NOT ; "
.ascii ": <> = NOT ; "
.ascii ": 0< 0 < ; "
.ascii ": 0<= 0 <= ; "
.ascii ": 0<> 0 <> ; "
.ascii ": 0> 0 > ; "
.ascii ": 0>= 0 >= ; "

// stack manipulation
.ascii ": OVER SWAP DUP ROT SWAP ; "

// conditionals and compilation
.ascii ": BEGIN HERE ; IMMEDIATE "
.ascii ": LITERAL ' LIT , , ; IMMEDIATE"

// "Variable" creates a placeholder to a memory location that we can read and write
// create a named, normal word. add functionality to return the address to the storage
// reserve storage space behind the final marker (which is a zero) 
.ascii ": VARIABLE WORD CREATE ' LIT , HERE 8 + , 0 , 0 , ; IMMEDIATE "

// Similar mechanism for constant. Create a word, but instead of
// reserving memory, we compile the constant from the top of the heap, into the word itself
.ascii ": CONSTANT WORD CREATE ' LIT , , 0 , ; IMMEDIATE "

// output
.ascii ": CR 10 EMIT ; "
.ascii ": SPACE 32 EMIT ; "

// test word
.asciz ": A 10 BEGIN DUP . 1 - DUP 0 < UNTIL ;"




