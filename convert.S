	// convert ascii to number
	// handle any base
	// check that we are not b0rking with the wrong characters

	.global myatoi
	.thumb_func

	// in: r0 - string pointer to null-terminated string
	// in: r1 - radix
	// out: r2 - value
	// out: V flag true - error

myatoi:
	push {r3-r7,lr}
	
	// sanity check the base

	// negative or zero base, failure
	cmp r1,#0
	ble _myatoierror

	// larger than 36
	cmp r1,#36
	bgt _myatoierror

	// nice, let's convert

	push {r0}
	
	// check if we have a negative number or not
	ldrb r3,[r0]
	cmp r3,#'-'
	bne _notnegative

	// we ignore the negativity in conversion, we will take care of that later...
	add r0,#1

	// following here, we should never encounter anything that is out of range (since we have eliminated the - if present)

_notnegative:

	ldr r2,=0
	
	// check if the base is less than or equal to 10 (meaning that we do it with normal digits)
	cmp r1,#10
	ble _bc1
	// it isn't
	ldr r4,='9'

	ldr r5,=96
	add r5,r1
	sub r5,#10
	b _convloop

	// base 10 or less
_bc1:
	ldr r4,='9'
	ldr r5,=96
	
_convloop:	
	ldrb r3,[r0]

	// check for zero termination
	cmp r3,#0
	beq _endconv

	// shift up one step, since we are getting a new digit
	mul r2,r1
	
	// if the digit is less than "0", it is a bad digit
	cmp r3,#'0'
	blt _myatoierrorpop

	// less than or equal to the limit specified by r4
	// we can continue with the conversion
	cmp r3,r4
	ble _convcont

	// check if the digit is A or more. if we get here, and it is, it is a bad digit
	cmp r3,#'a'
	blt _myatoierrorpop

	// check if the digit is less than or equal to the limit specified by r5. if it is not, it is a bad digit
	cmp r3,r5
	bgt _myatoierrorpop

	// we can continue the conversion
	
_convcont:
	// increase the pointer for next iteration
	add r0,#1
	
	ldr r6,='0'
	sub r3,r6
	cmp r3,#10
	bge _convhighdigit
	add r2,r3
	b _convloop

_convhighdigit:
	
	ldr r6,=('a'-'0'-10)
	sub r3,r6
	add r2,r3
	b _convloop
_endconv:
	pop {r0}

	// add code to negate the number here, if negative
	
	pop {r3-r7,pc}	

_myatoierrorpop:
	pop {r0}
_myatoierror:
	// set the overflow flag
	mrs r2,apsr
	ldr r3,=(1<<28)
	orr r2,r3
	msr apsr,r2
_x:	
	pop {r3-r7,pc}

digits:

	// because.
	.ascii "0123456789abcdefghijklmnopqrstuvwxyz"
	
