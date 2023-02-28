//	# -*- mode: asm -*-
#ifndef MACROS_H
#define MACROS_H

// utility macros to move things on and off the value stack
// both operate on r0

	.macro CFPUSH reg
	push {r6,r7}
	ldr r7,=forthframestackptr
	ldr r6,[r7]
	str \reg,[r6]
	add r6,#4
	str r6,[r7]
	pop {r6,r7}
	.endm

	.macro CFPOP reg
	push {r6,r7}
	ldr r7,=forthframestackptr
	ldr r6,[r7]	
	sub r6,#4
	ldr \reg,[r6]
	str r6,[r7]
	pop {r6,r7}
	.endm

	
	.macro KPOP
	bl _kpop
	.endm
		
	.macro KPUSH
	bl _kpush
	.endm

	.macro DONE
	ldr r0,=done
	mov pc,r0
	.ltorg  // allow a literal pool here
	.endm

	  // to create the built in words

	#define FLAG_HIDDEN      0x1
	#define FLAG_IMMEDIATE   0x2
	#define FLAG_ONLYCOMPILE 0x4
	#define FLAG_INVISIBLE   0x8 // not listed in WORDS listing
	#define END 0x0
	
	.set link,0  // magically increasing linked list pointer
	
	.macro RAWHEADER word, wordlen, flags=0, label
	.align 4
\label:	
next_\label:
	.int link
	.set link, next_\label
flags_\label:
	.int \flags
length_\label:	
	.int \wordlen
word_\label:
	.asciz "\word"
	.align 4
code_\label:
	.endm

	#define INTLEN 	      4

	#define	OFFSET_FLAGS  INTLEN
	#define OFFSET_NAME   (INTLEN*3)
	#define OFFSET_LENGTH (INTLEN*2)

	.macro HEADER word, wordlen, flags, label
	RAWHEADER "\word", \wordlen, \flags, \label
	ldr r1,=\label
//	bl pushforthcall
//	ldr r0,=debugflag
//	ldr r0, [r0]
//	cmp r0,#1
//	bne end_\label
//	ldr r0, =worddescstring
//	ldr r1, =word_\label
//	ldr r2, =flags_\label
//	ldr r2, [r2]
//	ldr r3, =length_\label
//	ldr r3, [r3]
//	ldr r4, =1
//	bl printf
end_\label:
	.endm

	// reads from address "assemblerlabel", and puts the data on the stack
	.macro CONSTANT word, wordlen, label, assemblerlabel
	HEADER "\word",\wordlen,0,\label
	ldr r0,=\assemblerlabel
	ldr r0,[r0]
	KPUSH
	DONE
	.endm
	
	
//goff:	
//	blx main
	
	.macro FHEADER word, wordlen, flags, label
	RAWHEADER "\word", \wordlen, \flags, \label
	.int 0xabadbeef // signals that this is a forth-defined word
	.endm
	
#endif

