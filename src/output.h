	# -*- mode: asm -*-
#include "themacros.h"

	.global DOT,EMIT,TYPE,CR,SPACE
	# ------ output -------	

	HEADER ".",1,0,DOT
	KPOP
	ldr r1,=base
	ldr r1,[r1]
	ldr r2,=numbuf
	bl myitoa

//	ldr r2,=base
//	ldr r2,[r2]
//	cmp r2,#16
//	beq _hex
//	mov r1,r0
	ldr r0,=numbuf
	bl printf

	ldr r0,=32
	bl putchar
	
	DONE
_hex:
	mov r1,r0
	ldr r0,=hexnumber
	bl printf
	DONE

	# print a char from ascii on the stack
	HEADER "EMIT",4,0,EMIT
	KPOP
	bl putchar
	DONE

	// ANS TYPE ( c-addr u -- ) ; print u characters from c-addr
	HEADER "TYPE",4,0,TYPE
	push {r4,r5}        // save r4 and Forth IP (r5 used as counter)
	KPOP                // r0 = u (length, TOS)
	mov r5,r0           // r5 = remaining count
	KPOP                // r0 = c-addr
	mov r4,r0           // r4 = current pointer
_type_loop:
	cmp r5,#0
	beq _type_done
	ldrb r0,[r4]
	bl putchar          // r4,r5 preserved (callee-saved)
	add r4,#1
	sub r5,#1
	b _type_loop
_type_done:
	pop {r4,r5}         // restore r4 and Forth IP
	DONE
	
	FHEADER "BASE",4,0,BASE
	.int LIT,base
	.int END

.data
numbuf: .space 32
.text



