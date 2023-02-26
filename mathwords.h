	# -*- mode: asm -*-
	# ---- math ----
	
	# multiply two numbers on the stack
	
	HEADER "*",1,0,STAR
	KPOP
	mov r1,r0
	KPOP
	MUL r0,r1
	KPUSH
	DONE

	# add...

	HEADER "+",1,0,PLUS
	KPOP
	mov r1,r0
	KPOP
	add r0,r1
	KPUSH
	DONE

	# subtract...

	HEADER "-",1,0,MINUS
	KPOP
	mov r1,r0
	KPOP
	sub r0,r1
	KPUSH
	DONE

	# divide...
	# using the rp2040 hardware divider
	HEADER "/MOD",4,0,DIVMOD
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

	HEADER "<",1,0,LESSTHAN
	KPOP
	mov r1,r0
	KPOP
	cmp r0,r1
	blt _lt
	ldr r0,=0
	KPUSH
	DONE
_lt:	
	ldr r0,=1
	KPUSH
	DONE

	HEADER ">",1,0,GREATERTHAN
	KPOP
	mov r1,r0
	KPOP
	cmp r0,r1
	bgt _lt
	ldr r0,=0
	KPUSH
	DONE
_gt:	
	ldr r0,=1
	KPUSH
	DONE

	HEADER "=",1,0,EQUAL
	KPOP
	mov r1,r0
	KPOP
	cmp r1,r0
	beq _eq
	ldr r0,=0
	KPUSH
	DONE
_eq:
	ldr r0,=1
	KPUSH
	DONE

	  
	# -------- end math -------


