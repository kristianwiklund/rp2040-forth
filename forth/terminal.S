	.global terminalprompt


// displays a prompt, reads text from stdin, puts it in "buffer"
terminalprompt:
	push {lr}

	// we need to get rid of pre-existing garbage here
	bl flushserial
	
	ldr r0,='>'
	bl putchar
	ldr r0,=' '
	bl putchar

	// read from the terminal
	// (cheating, with rpi library code)

	ldr r1,=buffer

loopzor:
	push {r1}
	
	bl getchar
	bl putchar // echo

	cmp r0,#'\n'
	beq endloopzor

	pop {r1}
	strb r0,[r1]
	add r1,#1
	
	b loopzor

endloopzor:
	ldr r0,=0
	str r0,[r1]
	ldr r0,=buffer
	bl printf
	pop {pc}


flushserial:
	push {lr}
	ldr r0,=0
_fsl:	
	bl getchar_timeout_us
	cmp r0, #0
	bge _fsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	pop {pc}
	
	
	
	
