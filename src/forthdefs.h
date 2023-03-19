// https://github.com/carlk3/no-OS-FatFS-SD-SPI-RPi-Pico

// ascii definitions of forth words that run on startup
// final word must end with 0 (hence asciz)
// intermediate must have a space at the end to get the parser working

// compilation
.ascii ": POSTPONE WORD FIND , ; IMMEDIATE "
.ascii ": RECURSE UNHIDE ; IMMEDIATE "


// stack manipulation
//.ascii ": OFF ; "
.ascii ": DUP HERE ! HERE @ HERE @ ; "
.ascii ": ROT >R >R HERE ! R> R> HERE @ ; "
.ascii ": SWAP >R HERE ! R> HERE @ ; "
.ascii ": OVER SWAP DUP ROT SWAP ; "
.ascii ": 2DUP OVER OVER ; "

// conditionals
.ascii ": BEGIN HERE ; IMMEDIATE "
.ascii ": UNTIL LIT ' 0BRANCH , , ; IMMEDIATE "
.ascii ": IF LIT ' 0BRANCH , HERE 0 , ; IMMEDIATE "
.ascii ": THEN HERE SWAP ! ; IMMEDIATE "
.ascii ": ELSE LIT ' BRANCH , HERE 0 , SWAP HERE SWAP ! ; IMMEDIATE "

// incomplete
.ascii ": ?DO POSTPONE >R POSTPONE >R HERE ; IMMEDIATE "
.ascii ": LOOP >R 1 + ; IMMEDIATE "

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
.ascii ": 1- 1 - ; "

// output and input

.ascii ": CR 10 EMIT ; "
.ascii ": SPACE 32 EMIT ; "
.ascii ": CHAR WORD DROP C@ ; "
.ascii ": [CHAR] LIT ' LIT , CHAR , ; IMMEDIATE "



// stack calculations that require / must come after /
.ascii ": DEPTH SP0 SP@ - 4 / ; "
.ascii ": .S DEPTH DUP 0 > IF BEGIN DUP 4 * SP0 SWAP - @ . 1- DUP 0< UNTIL THEN DROP ; "



// "Variable" creates a placeholder to a memory location that we can read and write
// create a named, normal word. add functionality to return the address to the storage
// reserve storage space behind the final marker (which is a zero)

.ascii ": VARIABLE WORD CREATE LIT ' LIT , HERE 8 + , 0 , 0 , ; IMMEDIATE "

// Similar mechanism for constant. Create a word, but instead of
// reserving memory, we compile the constant from the top of the heap, into the word itself
.ascii ": CONSTANT WORD CREATE LIT ' LIT , , 0 , ; IMMEDIATE "

// number handling
.ascii ": HEX 16 BASE ! ; "
.ascii ": DEC 10 BASE ! ; "

// this will fail for literals atm (since execute doesn't handle it well)
.ascii ": BASE-EXECUTE BASE @ >R BASE ! EXECUTE R> BASE ! ; "


// ." have two different behaviors. If in exec mode, it prints the string, if in compile mode, it compiles code to print the string
.ascii ": .\" STATE 0= IF BEGIN KEY DUP DUP 34 <> IF EMIT ELSE DROP THEN 34 = UNTIL " // this is the interpreting behavior
.ascii " ELSE S\" LIT TYPE , "   // and this is the compiling behavior
.ascii "THEN ; IMMEDIATE " // word end

// comments
.ascii ": ( BEGIN KEY [CHAR] ) = UNTIL ; IMMEDIATE "
//.ascii "1 DEBUG ! "

// test words - this must end the file
//.ascii ": FAC1 ( factorial x -- x! ) RECURSE DUP 0> IF DUP 1- FAC1 * ELSE DROP 1 THEN ; " // for reasons yet to be found, RECURSE freezes the system when running on a nucleo
.ascii ": B IF 1000 . ELSE 2000 . THEN ; "
.asciz ": A 10 BEGIN DUP . 1 - DUP 0 < UNTIL ; A "

endofforthdefs:

