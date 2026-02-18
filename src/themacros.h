//	# -*- mode: asm -*-
#ifndef MACROS_H
#define MACROS_H

// utility macros to move things on and off the value stack
// both operate on r0

	// r6 = DSP (data stack pointer), grows down; r6 >= stacktop means empty
	.macro KPOP
	push {r1}
	ldr  r1,=stacktop
	cmp  r6,r1
	pop  {r1}
	bhs  _kpop_uflow_\@
	add  r6,#4
	ldr  r0,[r6]
	b    _kpop_done_\@
_kpop_uflow_\@:
	ldr  r0,=underflow_msg
	bl   printf
	bl   _stack_restart
_kpop_done_\@:
	.endm

	// r6 <= stackbottom means no room
	.macro KPUSH
	push {r1}
	ldr  r1,=stackbottom
	cmp  r6,r1
	pop  {r1}
	bls  _kpush_oflow_\@
	str  r0,[r6]
	sub  r6,#4
	b    _kpush_done_\@
_kpush_oflow_\@:
	ldr  r0,=overflow_msg
	bl   printf
	bl   _stack_restart
_kpush_done_\@:
	.endm

	// r7 = RSP (return/frame stack pointer), grows down; r7 >= forthframestackend means empty
	.macro CFPOP reg
	push {r1}
	ldr  r1,=forthframestackend
	cmp  r7,r1
	pop  {r1}
	bhs  _cfpop_uflow_\@
	add  r7,#4
	ldr  \reg,[r7]
	b    _cfpop_done_\@
_cfpop_uflow_\@:
	ldr  r0,=frame_underflow_msg
	bl   printf
	bl   _stack_restart
_cfpop_done_\@:
	.endm

	// r7 <= forthframestackstart means full
	.macro CFPUSH reg
	push {r1}
	ldr  r1,=forthframestackstart
	cmp  r7,r1
	pop  {r1}
	bls  _cfpush_oflow_\@
	str  \reg,[r7]
	sub  r7,#4
	b    _cfpush_done_\@
_cfpush_oflow_\@:
	ldr  r0,=frame_overflow_msg
	bl   printf
	bl   _stack_restart
_cfpush_done_\@:
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
exec_\label:
	.int code_\label
word_\label:
	.asciz "\word"
	.align 4
code_\label:
	.endm

	#define INTLEN 	              4
	#define FIXED_HEADER_LENGTH   (INTLEN*4) // next + flags + length + exec
	
	
	#define	OFFSET_FLAGS  (INTLEN  )
	#define OFFSET_LENGTH (INTLEN*2)
	#define OFFSET_EXEC   (INTLEN*3)
	#define OFFSET_NAME   (INTLEN*4)
	
	.macro HEADER word, wordlen, flags, label
	RAWHEADER "\word", \wordlen, \flags, \label
//	ldr r1,=\label
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

	.macro VARIABLE word, wordlen, label, assemblerlabel
	HEADER "\word",\wordlen,0,\label
	ldr r0,=\assemblerlabel
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

