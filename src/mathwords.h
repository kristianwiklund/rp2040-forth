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

	// divide...
	// using the rp2040 hardware divider if PICO_BOARD is defined
	// change this to call the divide subroutine instead to
	// handle portability issues in one place only
	
	HEADER "/MOD",4,0,DIVMOD
	KPOP
	mov r1,r0
	KPOP

	// r0 - dividend
	// r1 - divisor
	// r3 - remainder
	// r4 - quotient

	bl divide
	// remainder	
	mov r0,r3
	KPUSH
	// quotient last
	mov r0,r4
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



