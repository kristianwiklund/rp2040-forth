#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
	
	.thumb_func
	.global main

	.macro DONE
	b done
	.endm

#// to create the built in words

	// flags are not used yet
	
	#define FLAG_ASSEMBLER 0	
	#define FLAG_INVISIBLE 1
	
	.set link,0
	
	.macro HEADER word, wordlen, flags, label
	.align 4
next_\label:
	.int link
	.set link, next_\label
header_\label:		
	.byte \flags
	.byte \wordlen
word_\label:
	.asciz "\word"
	.align 4
\label:
	.endm

	#define	OFFSET_FLAGS (header_WORDS-next_WORDS)
	
	#define OFFSET_CODE  (WORDS-next_WORDS)
	
main:
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

	add r1,#4
	str r1,[r0]
	ldr r1,[r2]
	cmp r1, #0
	beq loop // end of the list, simply freeze for now, later handle "up one" or "escape to prompt"

	mov pc,r1 // jump to the next word in the list
loop:
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

	# -------------
	# a couple of test words

	# -------------
	
	HEADER TICK, 4, 0, TICK
	ldr r0, =word_TICK
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
	push {r1}
	ldr r1,=stackptr
	ldr r0,[r1]
	add r0,#endstack-stacktop
	str r0,[r1]
	ldr r0,[r1]
	ldr r0,[r0]
	pop {r1}
	.endm
		
	.macro KPUSH 
	push {r1,r2}
	ldr r1, =stackptr      		// get the pointer to the bottom of the stack
	ldr r2,[r1]
	str r0,[r2]			// store the value on the stack
	sub r2,#endstack-stacktop	// update the stack pointer
	str r2,[r1]
	pop {r1,r2}
	.endm
	
	HEADER WORDS, 5, 0 , WORDS
	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
wordsloop:
	push {r0}
	push {r0}
	pop {r0}

	add r0,#6	   // the word name starts 6 bytes in
	bl printf	   // print the word
	
	ldr r0,=' '        // then print a space
	bl putchar
	
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
	HEADER /,1,0,SLASH
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
	ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET]
	KPUSH
	DONE

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

	HEADER OVER,4,0,OVER
	bl forthword
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
	mv r0,r2
	KPUSH
	mov r0,r1
	KPUSH
	mov r0,r3
	KPUSH
	DONE
	
	
	
	# ------ output -------	

	HEADER .,1,0,DOT
	KPOP
	mov r1,r0
	ldr r0,=numberstring
	bl printf
	DONE

	# print a char from ascii on the stack
	HEADER EMIT,4,0,EMIT
	KPOP
	bl putchar
	DONE

	# ---------------


	
	
	// called if a word is written in forth
forthword:	
	// r14 contains the pointer to the list of pointers to words
	ldr r0,=wordptr
	ldr r1,[r0]
	push {r1}
	mov r1, r14
	sub r1, #1     // because $REASONS
	str r1,[r0]
	str r1,[r0]
	
	DONE
	
	
	# demo word written in Forth
	HEADER DEMO,4,0,DEMO
	bl forthword				// this calls the forth word setup thing, and pushes "t" to r14
t:
	.word LIT, 15, LIT, 10, STAR, DUP, DOT, LIT, 5, SLASH, LIT, 32, EMIT, DOT
	.word LIT, 10, EMIT, WORDS
	.word 0
	
	.align 4		
list:
	.word DEMO
	.word LIT, 10, EMIT
	.word LIT, 7, LIT, 3,DUP,LIT,1,DOT,DOT,DOT,DOT,10,EMIT
	.word 0

	

	###
	##	strings
	
hellogoodmorning:	
	.asciz "\n\n\nWelcome!\n\n"
donemsg:
	.asciz "\nDone!\n"
numberstring:
	.asciz "%d"

	###
	## variables
	
	.data
	.align 4
wordptr:
	.word 0
dbw:
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
