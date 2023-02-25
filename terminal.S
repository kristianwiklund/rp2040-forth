	#include "macros.h"
	
	.global terminalprompt
	.global FLUSHSTDIN
	.global PROMPT, WORD
	

	# input handling

	HEADER "FLUSHSTDIN",10,0,FLUSHSTDIN
	ldr r0,=0	
_fss:			
	bl getchar_timeout_us
	cmp r0, #0
	bge _fss  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	DONE
	
	HEADER "PROMPT",6,0,PROMPT
	// read from terminal, put in input buffer
	// displays a prompt, reads text from stdin, puts it in "buffer"
terminalprompt:
	// we need to get rid of pre-existing garbage here
//	bl flushserial

	ldr r0,=0
_fsl:	
	bl getchar_timeout_us
	cmp r0, #0
	bge _fsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	
	ldr r0,='>'
	bl putchar
	ldr r0,=' '
	bl putchar

	// read from the terminal
	// (cheating, with rpi library code)

	ldr r1,=buffer
	ldr r2,=input
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
	ldr r0,=0
	strb r0,[r1]
	ldr r0,='\n'
	bl putchar
	// debug code
	//	ldr r0,=buffer
	//	bl printf
	// and return to whoever called us
_tpret:
	DONE

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

	input:
	.word buffer
buffer:
	.rept 200
	.byte 0
	.endr
endbuffer:




	
	
	
	
