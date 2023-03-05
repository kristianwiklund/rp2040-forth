	.thumb_func
	.global alignhelper, commahelper


	// find the next aligned word boundary
	// In: r1 is an address we want to align
	// Out: r1 - aligned address
alignhelper:	
	push {r3,lr}
	
	add r1,#3
	lsr r1,#2
	ldr r3,=4
	mul r1,r3
	pop {r3,pc}


	// take the first item from the value stack and compile it to HERE
	// then increase HERE
commahelper:
	push {lr}
	ldr r1,=freemem
	ldr r1,[r1]
	KPOP
	str r0,[r1]
	add r1,#INTLEN
	ldr r0,=freemem
	str r1,[r0]
	pop {pc}

	
	// copy zero-terminated string r0 to address r1
strcpy:
	push {r2-r4,lr}

_scl:
	ldr r2,[r0]
	str r2,[r1]
	cmp r2,#0
	bne _scl
	
	pop {r2-r4,pc}

