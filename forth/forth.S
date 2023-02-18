#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
	
	.thumb_func
	.global main
	.cpu cortex-m0
	
	.macro DONE
	ldr r0,=done
	mov pc,r0
//	b done
	.ltorg  // allow a literal pool here
	.endm

# to create the built in words

	#define FLAG_HIDDEN    0x1
	#define FLAG_IMMEDIATE 0x2
	.set link,0
	
	.macro RAWHEADER word, wordlen, flags=0, label
	.align 4
\label:	
next_\label:
	.int link
	.set link, next_\label
flags_\label:
	.int \flags
length_\label:	
	.int \wordlen
word_\label:
	.asciz "\word"
	.align 4
code_\label:
	.endm

	.macro HEADER word, wordlen, flags, label
	RAWHEADER \word, \wordlen, \flags, \label
	ldr r0, =worddescstring
	ldr r1, =word_\label
	ldr r2, =flags_\label
	ldr r2, [r2]
	ldr r3, =length_\label
	ldr r3, [r3]
	
	bl printf
	.endm

//goff:	
//	blx main
	
	.macro FHEADER word, wordlen, flags, label
	RAWHEADER \word, \wordlen, \flags, \label
	.int 1 // signals that this is a forth-defined word
	.endm
	
	#define	OFFSET_FLAGS  (flags_WORDS-next_WORDS)
//	#define OFFSET_CODE   (WORDS-next_WORDS)         // this... does not work, since the size of the ascii is all different.
	#define OFFSET_NAME   (word_WORDS-next_WORDS)
	#define OFFSET_LENGTH (length_WORDS-next_WORDS)
	#define INTLEN 	      (word_WORDS-length_WORDS)
main:
	// reset things

	bl resetme
	
	mov r7, #0
	bl stdio_init_all
	ldr r0, =hellogoodmorning
	bl printf
		
	# execute the functions linked from "words"
	ldr r0,=wordptr
	ldr r1,=list
	str r1,[r0]

	ldr r0,=0
	push {r0} // end of input exec marker

done:
	// execute the next word in the list, unless we are done executing words in the list
	ldr r0, =wordptr
	ldr r1,[r0]
	mov r2,r1

	add r1,#4   // increase the pointer one step
	str r1,[r0]
	ldr r1,[r2]
	cmp r1, #0
	beq endoflist // end of the list handler

	// here, if we are in compile mode, we shall simply push the word to compile. Unless the word is in immediate mode, in which
	// case we always shall execute it
	// happily, we always get the code here... which means that we need to subtract an offset to check the flags

	// r1 now contains the pointer to a structure containing the word, not the code as such
	// hence, we can operate on r1 with offsets, BUT we also have to seek where the actual code is
	// when we intend to execute it
	
	ldr r2,[r1, #OFFSET_FLAGS]

//	push {r1}
//	ldr r0,=hexnumber
//	bl printf
//	pop {r1}
	
	ldr r3,=FLAG_IMMEDIATE
	tst r2,r3
	beq runthecode

	// check for compile time here

runthecode:
	// here we shall run the actual code.
	// the actual code is located at
	// word base + OFFSET_NAME + name length (OFFSET_LENGTH) + padding

	// r1 contains the word base
	// get the length

	ldr r3, [r1,#OFFSET_LENGTH]
	add r1, r3
	add r1, #OFFSET_NAME
	// pad the pointer to get to where the code is
	add r1,#7
	lsr r1,#3
	lsl r1,#3

	// now we have the pointer to the code list in r1

	// load the first word of whatever we are pointing at
	// if that is number 1, the word we intend to execute
	// is a forth-defined word
	ldr r2,[r1]	
	cmp r2,#1
	beq handleforthword
	
	mov pc,r1 // jump to the next word in the list
	
endoflist:
	// here we need to pop the old pointer, if the old pointer is zero, we go to prompt	
	pop {r0}
	cmp r0,#0
	beq reallydone

	ldr r1,=wordptr
	str r0,[r1]
	b done
	
reallydone:	
	ldr r0, =donemsg
	bl printf
bloop:	
	b bloop

	###
	##	strings

	// handle a word written in forth.
	
handleforthword:	
	// start by bumping the address to the next item in the list,
	// which is a pointer to an actual word
	add r1,#INTLEN
	mov r14,r1

	
	// old code that we called if a word is written in forth
	// due to the thumb architecture, this doesn't really work,
	// unless we do a lot of annoying math while creating the word

	
forthword:
	// r14 contains the pointer to the list of pointers to words
	ldr r0,=wordptr
	ldr r1,[r0]
	push {r1}
	mov r1, r14
	//sub r1, #1     // because $REASONS
	str r1,[r0]
	DONE
		

	
	# -------------
	# a couple of test words

	# -------------
	
	HEADER AAAAAAA, 7, 0, AAAAAAA
	ldr r0, =word_AAAAAAA
	bl printf
	DONE

	# -------------	
	
	HEADER TOCK, 4, 0, TOCK
	ldr r0, =word_TOCK
	bl printf
	DONE

	# utility macros to move things on and off the value stack
	# both operate on r0
	.macro KPOP
	bl _kpop
	.endm
		
	.macro KPUSH
	bl _kpush
	
	.endm
	
	HEADER WORDS, 5, 0 , WORDS
	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
wordsloop:
	push {r0}
	push {r0}
	pop {r0}

	// don't print hidden words
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_HIDDEN 
	cmp r1,r2
	beq skipprint
	
	add r0,#OFFSET_NAME	   
	bl printf	   // print the word
	
	ldr r0,=' '        // then print a space
	bl putchar
skipprint:	
	pop {r0}	   // recover the pointer to the next word
	ldr r0, [r0]       // (and fetch the value)
	cmp r0, #0         // continue until we reach the end of the list
	bne wordsloop
	
	ldr r0,='\n'       // then finish with newline and return
	bl putchar
	DONE

	# -------------		

	HEADER TACK, 4, 0, TACK
	ldr r0, =word_TACK
	bl printf
	DONE

	# --------------
	# read a constant from the list of function calls
	
	HEADER LIT,3,0,LIT
	ldr r0, =wordptr  	// grab the next thing in the function list
	ldr r1,[r0]
	mov r2,r1

	add r1,#4		// then increase the function list pointer and store it 
	str r1,[r0]
	ldr r0,[r2]		// r0 now contains the value we want to store on the stack
	KPUSH			// and push it on the value stack
	DONE

	# ---- arithmetics ----
	# multiply two numbers on the stack
	
	HEADER *,1,0,STAR
	KPOP
	mov r1,r0
	KPOP
	MUL r0,r1
	KPUSH
	DONE

	# add...

	HEADER +,1,0,PLUS
	KPOP
	mov r1,r0
	KPOP
	add r0,r1
	KPUSH
	DONE

	# subtract...

	HEADER -,1,0,MINUS
	KPOP
	mov r1,r0
	KPOP
	sub r0,r1
	KPUSH
	DONE

	# divide...
	# using the hardware divider
	HEADER /MOD,4,0,DIVMOD
	ldr r3,=SIO_BASE
	KPOP
	str r0, [r3, #SIO_DIV_SDIVISOR_OFFSET]
	KPOP
	str r0, [r3, #SIO_DIV_SDIVIDEND_OFFSET	]

	// delay 8 cycles

	b 1f
1: 	b 1f	
1: 	b 1f
1: 	b 1f
1:
	ldr r0, [r3, #SIO_DIV_REMAINDER_OFFSET]
	KPUSH
	ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET]
	KPUSH
	DONE

	FHEADER /,1,0,SLASH
	.word DIVMOD, SWAP, DROP, 0

	FHEADER MOD,3,0,MOD	
	.word DIVMOD, DROP, 0
	

	# -------- end arithmetics -------



	# ------- stack manipulation -------
	
	HEADER DUP,3,0,DUP
	KPOP
	KPUSH
	KPUSH
	DONE

	HEADER SWAP,4,0,SWAP
	KPOP
	mov r1,r0
	KPOP
	mov r2,r0
	mov r0,r1
	KPUSH
	mov r0,r2
	KPUSH
	DONE

	FHEADER OVER,4,0,OVER
	.word SWAP, DUP, ROT, SWAP
	.word 0
	
	HEADER DROP,4,0,DROP
	KPOP
	DONE

	HEADER ROT,3,0,ROT
	KPOP
	mov r1,r0
	KPOP
	mov r2,r0
	KPOP
	mov r3,r0
	mov r0 ,r2
	KPUSH
	mov r0,r1
	KPUSH
	mov r0,r3
	KPUSH
	DONE
	
	
	
	# ------ output -------	

	HEADER .,1,0,DOT
	KPOP
	ldr r2,=base
	ldr r2,[r2]
	cmp r2,#16
	beq _hex
	mov r1,r0
	ldr r0,=numberstring
	bl printf
	DONE
_hex:
	mov r1,r0
	ldr r0,=hexnumber
	bl printf
	DONE

	# print a char from ascii on the stack
	HEADER EMIT,4,0,EMIT
	KPOP
	bl putchar
	DONE

	# print a string from ascii pointed to by an item on the stack
	HEADER TYPE,4,0,TYPE
	KPOP
	bl printf
	DONE
	
	FHEADER CR,2,0,CR
	.word LIT,10,EMIT,0

	FHEADER SPACE,5,0,SPACE
	.word LIT,32,EMIT,0

	# ------ memory manipulation ---------

	HEADER HERE,4,0,HERE
	ldr r0,=freemem
	ldr r0,[r0]
	KPUSH
	DONE

	# input handling

	HEADER WORD,4,0,WORD
	// read from input buffer until space, enter, or zero is found.
	// store the data at "HERE", leading with an integer (4 bytes) containing the number of bytes in the word
	// this does not ensure that we are at an aligned boundary. Write a helper that secures that "freemem"
	// is bumped to an aligned space
	// load the pointer to the buffer
	// r3 - input buffer pointer
	// r5 - input length counter
	// r1 - word buffer storage
	
	ldr r3,=input
	ldr r0,[r3]
	// for debugging
	ldr r0,=buffer

	// check for NULL pointer, return if we are NULL
	cmp r0,#0
	bne wc0
	KPUSH
	KPUSH
	DONE
wc0:	
	ldr r1,=wordbuf  // get the address to the start of the wordbuf
	ldr r5,=0	// zero length
wc1:
	ldrb r4,[r0]     // read the input character (a byte) from the buffer
	add r0, #1	// increase the pointer
	str r0, [r3]	// and store it back to memory to indicate that we have moved the buffer pointer
	// then check if we are at the end of the word or not
	cmp r4,#0
	beq wcend
	cmp r4, #' '
	beq wcend
	cmp r4, #'\n'
	beq wcend

wc2:
	// save the retrieved character somewhere

	strb r4,[r1,r5]      // store the character in the word buffer
	// increment the counter at memstart
	add r5,#1
	// debug, print the character
	//		push {r0,r1,r2,r4,r5}
	//		mov r0,r4
	//	bl putchar
	//	ldr r0,='-'
	//	bl putchar
	//	pop {r0,r1,r2,r4,r5}	
	b wc1
wcend:
	add r5,#1
	ldr r4,=0
	strb r4,[r1,r5]
	ldr r0,=wordbuf
	KPUSH	
	mov r0,r5	
	KPUSH
	DONE
	
	# --------------------
	# --- FIND ------------
	
	HEADER FIND,4,0,FIND
	// traverse the word linked list and see if we match what we have on the stack
	// consume the length and the address of the word on the stack
	KPOP
	mov r1,r0 // length
	KPOP
	mov r2,r0 // pointer

	// drop the address to the word header on the stack on match, zero on no match

	// start at the end of the list

	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
findloop:
	// go through the words		
	push {r0}
	ldr r4,[r0,#OFFSET_LENGTH]

	// match the length	
	cmp r4,r1  // then compare to the word we have on the stack
_roggens:			
	bne _nextfl // jump to the next part if it doesn't match


_roggens5:	    
	// if r5 is zero when we are done, we have a match
	ldr r5,=0
	mov r4,r1
	// r4 contains the length of the string in the word we are checking against

	mov r3,r2 // pointer to the word on stack
	mov r6,r0 // contains the pointer to the word we compare
	add r6, #OFFSET_NAME // transpose to the string part

_findtestloop:	
	ldrb r7,[r3,r4]
	ldrb r0,[r6,r4]
_roggens4:	
	// compare strings
	sub r7,r0
	add r5,r7
	
	sub r4,#1
	cmp r4,#0
_roggens3:	
	bne _findtestloop

	// not a match
	cmp r5,#0
	bne _nextfl

	// match
	//ldr r0,='*'        
	//bl putchar

	// cleanup and return
	pop {r0}
	KPUSH
	DONE

_nextfl:
	pop {r0}	   // recover the pointer to the next word
	ldr r0, [r0]       // (and fetch the value)
	cmp r0, #0         // continue until we reach the end of the list
_roggens2:	
	bne findloop
	ldr r0,=0
	KPUSH		   // nothing found, push 0
	DONE

	

	# -- run a word pointed to by the topmost item on the stack
	
	HEADER EXECUTE,7,0,EXECUTE
	KPOP
	mov pc,r0

	# -- make a word placeholder
	
	HEADER CREATE,6,0,CREATE
	KPOP	
	mov r1,r0 // length of the name
	KPOP
_lambo2:	
	mov r2,r0 // pointer of the name
	push {r1}
	
	// get "HERE"
	ldr r0,=freemem
	ldr r5,[r0]  // contains HERE
_lambo3:	
	// get the first word in the (current) list and link it to this word
	ldr r4,=firstword
	ldr r3,[r4]
	str r3,[r5]
_lambo:	
	// then set the first word to this word
	str r5,[r4]

	// bump the pointer and store 0 (the flags)
	ldr r3,=0
	add r5,#INTLEN
	str r3,[r5]
	
	// bump the pointer, and store the length of the word name
	add r5,#INTLEN
	str r1,[r5]



	// bump the pointer and store the name itself
	add r5,#INTLEN

_cl1:
	ldrb r3,[r2,r1]
	strb r3,[r5,r1]
	sub r1,#1
	cmp r1,#0
	bne _cl1
	ldrb r3,[r2,r1] // store last letter
	strb r3,[r5,r1]
	pop {r1}
_cl2:	
	// bump the pointer to behind the word name
	add r5,r1
	add r5,#1
	// terminate the string with a 0
	ldr r3,=0
	strb r3,[r5]
	// now the tricky part, align HERE to instruction boundary

	add r5,#7
	lsr r5,#3
	lsl r5,#3
	ldr r0,=freemem
	str r5,[r0]
_created:			
	DONE
	
	

	HEADER HIDDEN,6,0,HIDDEN
	KPOP
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_HIDDEN
_o1:	
	orr r1,r2
_o2:	
	str r1,[r0,#OFFSET_FLAGS]

	DONE

	FHEADER \:,1,0,COLON
	.int LIT, 1, COMMA          // this compiles a "1" into the word which indicates to the system that it is defined in forth, not assembler
	.int LATEST, FETCH  , HIDDEN  // LATEST provides the address to the varible containing the latest word link, fetch fetches its content, HIDDEN hides it from searches
	.int 0
	
	# ---- COMMA
	
	# push integer to HERE, increase HERE with integer length
	
	RAWHEADER ",",1,0,COMMA
	ldr r1,=freemem
	ldr r1,[r1]
	KPOP
	str r0,[r1]
	add r1,#INTLEN
	ldr r0,=freemem
	str r1,[r0]
	DONE

	HEADER LATEST,6,0,LATEST
	ldr r0,=firstword
	KPUSH
	DONE

	HEADER \@,1,0,FETCH
	KPOP
	ldr r0,[r0]
	KPUSH
	DONE

	FHEADER DEMO,4,0,DEMO
	.int LIT,7,LIT,3,DUP,LIT,1
	.int DOT,DOT,DOT,DOT
	.int 0
	
	FHEADER BASE,4,0,BASE
	.int LIT,base
	.int 0

	HEADER ],1,FLAG_IMMEDIATE,RBRAC
	ldr r1,=0
	ldr r0,=mode
	str r1,[r0]
	DONE

	HEADER [,1,FLAG_IMMEDIATE,LBRAC
	ldr r1,=1
	ldr r0,=mode
	str r1,[r0]
	DONE

	

hexnumber:
	.asciz "%x"
	
	
	
	.align 4		
list:
	.word WORDS,CR
	.int LBRAC,LATEST, DUP, DOT, CR, FETCH, DOT, CR
	.int WORD, CREATE           // fetch a word from the input buffer, create a dictionary entry for it
	.int WORDS, CR
	.int LATEST, FETCH  , HIDDEN  // LATEST provides the address to the varible containing the latest word link, fetch fetches its content, HIDDEN hides it from searches
	.int LATEST, DUP, DOT, CR, FETCH, DOT, CR
	.int WORDS
	.int HERE, DOT, CR
	.word 0

_kpush:	
        push {r1,r2,lr}
        ldr r1, =stackptr               // get the pointer to the bottom of the stack
        ldr r2,[r1]
        str r0,[r2]                     // store the value on the stack
        sub r2,#endstack-stacktop       // update the stack pointer
        str r2,[r1]
        pop {r1,r2,pc}


_kpop:	
	push {r1,lr}
	ldr r1,=stackptr
	ldr r0,[r1]
	add r0,#endstack-stacktop
	str r0,[r1]
	ldr r0,[r1]
	ldr r0,[r0]
	pop {r1,pc}


resetme:
	push {lr}
	ldr r0,=freemem
	ldr r1,=heap
	str r1,[r0]

	ldr r0,=link
	ldr r1,=firstword
	str r0,[r1]
	pop {pc}
	
	###
	## variables

	.data

hellogoodmorning:	
	.asciz "\n\n\nWelcome!\n\n"
donemsg:
	.asciz "\nDone!\n"
numberstring:
	.asciz "%d"
debugstring:
	.asciz "<%s>\n"
worddescstring:	
	.asciz "<%s, flags=%x, length=%d>\n"
debugnumber:
	.asciz "[%d]"
	

	.align 4
wordptr:
	.word 0
dbw:
	.word 0
input:
	.word buffer
buffer:
	.asciz "ABCDEF 10 5 DIV DOT"
	.align 4
freemem:
	.word endstack

	// base only supports 16 and "not 16" at this time. "not 16" defaults to 10
base:
	.word 16

	// compile or interpretation mode
mode:
	.word 0
	
firstword:
	.word link

	.align 4
stackptr:
	.word stacktop
	
stackbottom:
	.rept 200
	.int 0
	.endr
stacktop:
	.int 0
endstack:
	.align 4
wordbuf:
	.rept 32
	.byte 0
	.endr
heap:
	.rept 2000
	.int 0
	.endr
