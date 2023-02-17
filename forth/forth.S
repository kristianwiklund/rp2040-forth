#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
	
	.thumb_func
	.global main
	.cpu cortex-m0
	
	.macro DONE
	b done
	.ltorg  // allow a literal pool here
	.endm

#// to create the built in words

	// flags are not used yet
	
	.set link,0
	
	.macro HEADER word, wordlen, flags, label
	.align 4
next_\label:
	.int link
	.set link, next_\label
header_\label:		
	.int \wordlen+\flags
word_\label:
	.asciz "\word"
	.align 4
\label:
//	ldr r0, =debugstring
//	ldr r1, =word_\label
//	bl printf
	.endm

	.macro FHEADER word, wordlen, flags, label
	HEADER \word, \wordlen, \flags, \label
	bl forthword
	.endm
	
	#define	OFFSET_FLAGS (header_WORDS-next_WORDS)
	#define OFFSET_CODE  (WORDS-next_WORDS)
	#define OFFSET_NAME  (word_WORDS-next_WORDS)
	
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

	add r1,#4   // increase the pointer one step
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

	###
	##	strings
	
hellogoodmorning:	
	.asciz "\n\n\nWelcome!\n\n"
donemsg:
	.asciz "\nDone!\n"
numberstring:
	.asciz "%d"
debugstring:
	.asciz "<%s>"
	
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
	bl _kpush
	
	.endm
	
	HEADER WORDS, 5, 0 , WORDS
	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
wordsloop:
	push {r0}
	push {r0}
	pop {r0}

	add r0,#OFFSET_NAME	   
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
	mov r1,r0
	ldr r0,=numberstring
	bl printf
	DONE

	# print a char from ascii on the stack
	HEADER EMIT,4,0,EMIT
	KPOP
	bl putchar
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
	add r2,#1        // bump the memory pointer
	str r2,[r1]      // and store it back to freemem
	// increment the counter at memstart
	add r5,#1
	// debug, print the character
	//	push {r0}
	//mov r0,r4
	//bl putchar
	//ldr r0,=' '
	//bl putchar
	//pop {r0}
	b wc1
wcend:
	ldr r0,=wordbuf
	KPUSH	
	mov r0,r5	
	KPUSH
	DONE
	
	

hexnumber:
	.asciz "%x\n"
	
	
	// called if a word is written in forth
forthword:
	// r14 contains the pointer to the list of pointers to words
	ldr r0,=wordptr
	ldr r1,[r0]
	push {r1}
	mov r1, r14
	sub r1, #1     // because $REASONS
	str r1,[r0]
	DONE
		
	.align 4		
list:
	.word WORDS, WORD // after calling "word" we have an item in the beginning of the buffer.
	.word DOT,SPACE,DOT,CR
	
	.word 0

_kpush:	
        push {r1,r2,lr}
        ldr r1, =stackptr               // get the pointer to the bottom of the stack
        ldr r2,[r1]
        str r0,[r2]                     // store the value on the stack
        sub r2,#endstack-stacktop       // update the stack pointer
        str r2,[r1]
        pop {r1,r2,pc}


	###
	## variables
	
	.data
	.align 4
wordptr:
	.word 0
dbw:
	.word 0
input:
	.word buffer
buffer:
	.asciz "XYZZY 10 5 DIV DOT"
	.align 4
freemem:
	.word endstack
	
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
