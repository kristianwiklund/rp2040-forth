	# -*- mode: asm -*-
	#include "macros.h"
	
	.global terminalprompt
	.global FLUSHSTDIN
	.global PROMPT, WORD
	.global newwordhelper

	# input handling

	HEADER "FLUSHSTDIN",10,0,FLUSHSTDIN
	ldr r0,=0	
_fss:			
	bl getchar_timeout_us
	cmp r0, #0
	bge _fss  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	DONE
	
	HEADER "READ-LINE",6,0,PROMPT
	// read from terminal, put in input buffer
	// displays a prompt, reads text from stdin, puts it in "buffer"
	bl readlinehelper
	DONE
	
readlinehelper:
	// we need to get rid of pre-existing garbage here
	//	bl flushserial

	push {lr}

	ldr r0,=0
	
	ldr r0,='o'
	bl putchar
	ldr r0,='k'
	bl putchar
	  ldr r0,='\n'
	  bl putchar
	  
	// read from the terminal
	// (cheating, with rpi library code)

	ldr r1,=buffer
	ldr r2,=inputptr
	str r1,[r2]

loopzor:
	push {r1}
	
	bl getchar
	bl putchar // echo

	pop {r1}

	cmp r0,#'\n'
	beq endloopzor
	cmp r0,#'\r'
	beq endloopzor
	
	strb r0,[r1]
	add r1,#1
	
	b loopzor

endloopzor:
	// get rid of junk - in particular, old line endings that we have not chomped... 
_fsl:
  push {r1}
	bl getchar_timeout_us
	cmp r0, #0
	bge _fsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens

    pop {r1}
	ldr r0,=0
	strb r0,[r1]
	ldr r0,='\n'
	bl putchar
	// debug code
	//	ldr r0,=buffer
	//	bl printf
	// and return to whoever called us
_tpret:
	pop {pc}

flushserial:
	push {lr}  // push FSL
	ldr r0,=0
_ofsl:	
	bl getchar_timeout_us
	cmp r0, #0
	bge _ofsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	pop {pc}  // pop FSL

	

	// rewrite this to read from the input instead of from a tokenized row
	
	HEADER "WORD",4,0,WORD
	// read from input buffer until space, enter, or zero is found.
	bl newwordhelper
	DONE

newwordhelper:

	push {lr}
	
	// start by discarding everything that is a newline, carriage return, space

_nww_l1:	
	bl mygetchar		
//	bl putchar // echo

	cmp r0,#0
	beq _nww_l1
	cmp r0, #' '
	beq _nww_l1
	cmp r0, #'\n'
	beq _nww_l1
	cmp r0, #'\r'
	beq _nww_l1

	ldr r1,=wordbuf
	
	// read until we get a char we don't want
_nww_l2:
	strb r0,[r1]
	add r1, #1
	
	push {r1}
	bl mygetchar		
//	bl putchar // echo
	pop {r1}
	
	cmp r0,#0
	beq _nww_l2_end
	cmp r0, #' '
	beq _nww_l2_end
	cmp r0, #'\n'
	beq _nww_l2_end
	cmp r0, #'\r'
	beq _nww_l2_end

ap:	
	b _nww_l2
	
_nww_l2_end:
	cmp r0,#'\r'
	bne _nww_l3
	push {r1}
	ldr r0,='\n'
//	bl putchar
	pop {r1}
_nww_l3:	
	ldr r0,=0
	strb r0,[r1]

	ldr r0,=wordbuf
	KPUSH
	sub r1,r0
	mov r0,r1
	KPUSH

//	ldr r0,=debugwordmsg
//	ldr r1,=wordbuf
//	bl printf
	
	pop {pc}

	// ---


	// return the next character from the input buffer ("buffer"), and increase the pointer
	// if the character in the buffer is 0, read a new line from stdin
	// yet another thing that should be possible to write in forth
	
mygetchar:
	push {r1,r2,r3,r4,lr}
_mgcretry:	
	ldr r1,=inputptr
	ldr r2,[r1]		// pointer to the next character

	ldr r3,=buffer		// check if the pointer is the start of
	cmp r2,r3		// the buffer.
	bne _mgc2		// no, we have something ongoing that we already work with

	// buffer is empty, read something to the buffer
	push {r1,r2}
	bl readlinehelper	
	pop {r1,r2}
_mgc2:	
	ldrb r0,[r2]		// the next character

	cmp r0,#0		// if it is not zero
	bne _mgc1		// continue feeding from the buffer

	ldr r2,=buffer		// it is zero, set inputptr to the start
	str r2,[r1]		// of the buffer. This will force a terminal read on the next call.
	pop {r1,r2,r3,r4,pc}	// Then return the zero to the caller
	
_mgc1:
	add r2,#1		// then increase the pointer
	str r2,[r1]		
	
	pop {r1,r2,r3,r4,pc}	// and return to the caller
	


	
	
	
	
