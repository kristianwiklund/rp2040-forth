	.thumb_func
	.global alignhelper, commahelper
	.global mystrcpy
	.global mymemcpy
	
	#include "themacros.h"

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
mystrcpy:
	push {r2-r4,lr}

_scl:
	ldrb r2,[r0]
	strb r2,[r1]
	add r0,#1
	add r1,#1
	cmp r2,#0
	bne _scl
	
	pop {r2-r4,pc}

	// copy r2 bytes from r0 to r1
	// does not work if the areas are overlapping
mymemcpy:
	push {r2,r3,lr}
_mmcl:
	ldrb r3,[r0,r2]
	strb r3,[r1,r2]
	sub r2,#1
	cmp r2,#0
	bge _mmcl
	
	pop {r2,r3,pc}
	
