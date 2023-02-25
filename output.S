	#include "macros.h"

	.global DOT,EMIT,TYPE,CR,SPACE
	# ------ output -------	

	HEADER ".",1,0,DOT
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
	HEADER "EMIT",4,0,EMIT
	KPOP
	bl putchar
	DONE

	# print a string from ascii pointed to by an item on the stack
	HEADER "TYPE",4,0,TYPE
	KPOP
	bl printf
	DONE
	
	FHEADER "CR",2,0,CR
	.word LIT,10,EMIT,0

	FHEADER "SPACE",5,0,SPACE
	.word LIT,32,EMIT,0

	FHEADER "BASE",4,0,BASE
	.int LIT,base
	.int END


	// base only supports 16 and "not 16" at this time. "not 16" defaults to 10
base:
	.word 10

	
