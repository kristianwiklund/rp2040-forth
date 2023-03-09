// MIT License

// Copyright (c) 2023 Kristian Wiklund

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

	
	// convert ascii to number, or number to ascii
	// handle any base 1-36 (1 will break horribly)
	// itoa requires rp2040 hardware divider

#ifdef PICO_BOARD
#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"	
#endif
	
	
	// check that we are not b0rking with the wrong characters

	.global myatoi, myitoa
	.thumb_func
	//	.thumb-2
	#ifdef NUCLEO_F103
	.cpu cortex-m3
	#endif
	
	// in: r0 - string pointer to null-terminated string
	// in: r1 - radix
	// out: r2 - value
	// out: V flag set --> error

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
	ldr r5,=96 // character before 'a' in the ascii table
	
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
	ldrb r3,[r0]
	cmp r3,#'-'
	bne _endendconv
	neg r2,r2
	
_endendconv:	
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

	.ltorg
	
	// convert number to digits
	// in: r0 - number to convert
	// in: r1 - radix
	// in: r2 - pointer to string storage
myitoa:
	push {r3-r5,lr}
	mov r7,r2		// save for later
	
	// iterate over the number and get the number % radix and number / radix

	ldr r5,=digits
	push {r0}    // save for sign check

	cmp r0,#0
	bge _itoa_loop

	neg r0,r0	// if negative, convert to positive before creating the string

	
_itoa_loop:
	
	bl divide // get remainder and quotient between the number and the radix

	// r3 contains the remainder. 
	ldrb r3,[r5, r3] // do a lookup in the digits table to get the character to store
	strb r3,[r2]     // store it
	add r2, #1       // and increment the pointer

	// r4 contains the quotient
	mov r0,r4
	cmp r0, #0
	bne _itoa_loop

	pop {r0} 	// restore number
	cmp r0,#0
	bge _not_negative_itoa

	ldr r4,='-'
	strb r4,[r2]
	add r2, #1
	

_not_negative_itoa:	

	ldr r4,=0		// zero terminate
	strb r4,[r2]

	// here we need to reverse the string.
	// r2-1 contains the last digit
	// r7 contains the first digit

	sub r2, #1

_reverseloop:
	ldrb r3,[r2]
	ldrb r4,[r7]
	strb r3,[r7]
	strb r4,[r2]

	sub r2,#1
	add r7,#1

	cmp r2,r7
	bgt _reverseloop
	
	
	
	pop {r3-r5,pc}
	

divide:
	push {r5,lr}

	#ifdef PICO_BOARD
	ldr r5,=SIO_BASE
	str r0, [r5, #SIO_DIV_SDIVIDEND_OFFSET] // number we want to divide
	str r1, [r5, #SIO_DIV_SDIVISOR_OFFSET]  // with this number

	// delay 8 cycles

	b 1f
1: 	b 1f	
1: 	b 1f
1: 	b 1f
1:
	ldr r3, [r5, #SIO_DIV_REMAINDER_OFFSET]
	ldr r4, [r5, #SIO_DIV_QUOTIENT_OFFSET]
	#endif

	#ifdef NUCLEO_F103
	// do something with numbers
	#endif

	
	pop {r5,pc}
	
	
digits:

	// because.
	.ascii "0123456789abcdefghijklmnopqrstuvwxyz"
	
