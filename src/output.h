	# -*- mode: asm -*-
#include "themacros.h"

	.global DOT,EMIT,TYPE,CR,SPACE
	# ------ output -------	

	HEADER ".",1,0,DOT
	KPOP
	ldr r1,=base
	ldr r1,[r1]
	ldr r2,=wordbuf2
	bl myitoa

//	ldr r2,=base
//	ldr r2,[r2]
//	cmp r2,#16
//	beq _hex
//	mov r1,r0
	ldr r0,=wordbuf2
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

	# print a string from ascii pointed to by an item on the stack
	HEADER "TYPE",4,0,TYPE
	KPOP
	bl printf
	DONE
	
	FHEADER "BASE",4,0,BASE
	.int LIT,base
	.int END



	
