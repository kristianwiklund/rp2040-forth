//	# -*- mode: asm -*-
	#include "macros.h"
	
	.global LIT, commahelper


	FHEADER "STATE",5,0,STATE
	.word LIT,mode,FETCH,0

	//
	// -- make a word placeholder


	
	HEADER "CREATE",6,0,CREATE
	KPOP	
	mov r1,r0 // length of the name
	KPOP
_lambo2:	
	mov r2,r0 // pointer of the name
	push {r1}
	
	// get "HERE"
	ldr r0,=freemem
	ldr r5,[r0]  // contains HERE
_lambo3:	
	// get the first word in the (current) list and link it to this word
	ldr r4,=firstword
	ldr r3,[r4]
	str r3,[r5]
_lambo:	
	// then set the first word to this word
	str r5,[r4]
	
	// bump the pointer and store 0 (the flags)
	ldr r3,=0
	add r5,#INTLEN
	str r3,[r5]
	
	// bump the pointer, and store the length of the word name
	add r5,#INTLEN
	str r1,[r5]

	// bump the pointer and store the pointer to executable code
	// by default, this should drop something on the stack or something like
	// that. We set the pointer to 0 as a start
	add r5,#INTLEN
	ldr r3,=0
	str r3,[r5]
	
	// bump the pointer and store the name itself
	add r5,#INTLEN

	// when we are here, we have the original string in r2, and the place where we want to copy it in r5
	// we need to move things around a bit, move r2 to r0, r5 to r1, then we call strcpy
	push {r0,r1}
	mov r0,r2
	mov r1,r5
	bl mystrcpy
	pop {r0,r1}
	
	
	pop {r1}
_cl2:	
	// bump the pointer to behind the word name
	add r5,r1
	add r5,#1
	// terminate the string with a 0
	ldr r3,=0
	strb r3,[r5]
	add r5, #1    // to not overwrite with filler (which we use for debugging...)
	
	// now the tricky part, align HERE to instruction boundary
	// r5 contains the address right behind the string
	mov r1,r5
	// move it to r1, and use the helper to adjust

	
	add r5,#15
	lsr r5,#4
	ldr r3,=16
	mul r5,r3
	ldr r0,=freemem
	str r5,[r0]
	
	cmp r1,r5
	beq _created // nothing to pad

	// and pad the end of the word up to the code place with a very visible filler
	ldr r3,=0xAA
	ldr r2,=0xFF
cloop:
	strb r3,[r1]
	eor r3,r2
	add r1,#1
	cmp r1,r5
	bne cloop
	
	

	// add a forth marker, increase the memory pointer
	// and we are good to go	
_created:
	ldr r0,=freemem
	ldr r1,[r0]
	ldr r2,=0xabadbeef
	str r2,[r1]
	add r1,#INTLEN
	str r1,[r0]
	
	DONE
	
	
	# toggles the HIDDEN word flag
	HEADER "HIDDEN",6,0,HIDDEN
	KPOP
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_HIDDEN
	eor r1,r2
	str r1,[r0,#OFFSET_FLAGS]
	DONE

	# sets the HIDDEN word flag
	HEADER "HIDE",4,FLAG_INVISIBLE,HIDE
	KPOP
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_HIDDEN
	orr r1,r2
	str r1,[r0,#OFFSET_FLAGS]
	DONE

	# toggles the HIDDEN word flag
	HEADER "UNHIDE",6,FLAG_INVISIBLE,UNHIDE
	KPOP
	ldr r2,=FLAG_HIDDEN
	ldr r1,=255
	eor r2,r1
	ldr r1,[r0,#OFFSET_FLAGS]
	and r1,r2
	str r1,[r0,#OFFSET_FLAGS]
	DONE
	

	HEADER "'",1,FLAG_IMMEDIATE,TICK
	ldr r0,=mode
	ldr r0,[r0]

	// two different behaviors if we are in compiling or executing mode
	cmp r0,#0
	beq _tickrun
	
	// compiling mode
	bl newwordhelper
	bl findhelper
	bl commahelper
	DONE
	
_tickrun:
	// executing mode
	bl newwordhelper
	bl findhelper
	DONE
	
//	HEADER "OVER",4,0,OVER
//	ldr r0,=vstackptr
//	ldr r0,[r0]
//	ldr r0,[r0,#8]
//	KPUSH
//	DONE
	
	
	FHEADER ":",1,0,COLON
	.int WORD //, OVER, TYPE, LIT, 32, EMIT // if we need to debug word creation
	.int CREATE                 // creates a header for a forth word including the marker
	.int LATEST, FETCH, HIDE  // LATEST provides the address to the varible containing the latest word link, fetch fetches its content, HIDDEN hides it from searches
	.int RBRAC			// go to compile mode
	.int END

	FHEADER ";",1,FLAG_IMMEDIATE,SEMICOLON
	.int LIT,0,COMMA	// add end of word marker
	.int LBRAC		// end compile mode
	.int LATEST, FETCH, UNHIDE // remove hidden flag
	.int END
	
	# ---- COMMA
	
	# push integer to HERE, increase HERE with integer length
	
	HEADER ",",1,0,COMMA
	bl commahelper
	DONE

	VARIABLE "LATEST",6,LATEST,firstword

	// same as comma, but for characters. causes "freemem" to become unaligned
	HEADER "c,",2,0,CCOMMA
	ldr r1,=freemem
	ldr r1,[r1]
	KPOP
	strb r0,[r1]
	add r1,#1
	ldr r0,=freemem
	str r1,[r0]
	DONE

	// align the free space pointer
	HEADER "ALIGN",5,0,ALIGN
	ldr r0,=freemem
	ldr r1,[r0]
	
	bl alignhelper
	str r1,[r0]

	DONE

	# --------------
	# read a constant from the list of function calls
	
	HEADER "LIT",3,0,LIT
	ldr r0, =wordptr  	// grab the next thing in the function list
	ldr r1,[r0]
	mov r2,r1

	add r1,#4		// then increase the function list pointer and store it 
	str r1,[r0]		// store wordptr
	ldr r0,[r2]		// r0 now contains the value we want to store on the stack
	KPUSH			// and push it on the value stack
	DONE

	# ------ memory manipulation ---------

	CONSTANT "HERE",4,HERE,freemem
//	HEADER "HERE",4,0,HERE
//	ldr r0,=freemem
//	ldr r0,[r0]
//	KPUSH
//	DONE

	HEADER "@",1,0,FETCH
	KPOP
	ldr r0,[r0]
	KPUSH
	DONE

	HEADER "!",1,0,STORE
	KPOP
	mov r1,r0
	KPOP
	str r0,[r1]
	DONE

	HEADER "C@",2,0,CFETCH
	KPOP
	ldrb r0,[r0]
	KPUSH
	DONE

	HEADER "C!",2,0,CSTORE
	KPOP
	mov r1,r0
	KPOP
	strb r0,[r1]
	DONE

	#

	// ##########################
	// loops and conditionals	

	
	// pulls thing from stack. if thing is zero, jumps to
	// the address in the next word in the list - otherwise, it discards it
	HEADER "0BRANCH",7,FLAG_ONLYCOMPILE,ZBRANCH
	// get the next word and bump the pointer
	ldr r0,=wordptr
	ldr r1,[r0] // where it points
	ldr r2,[r1] // the next word
	add r1,#4
	str r1,[r0]

	
	KPOP
	cmp r0,#0
	bne _zb1

	ldr r0,=wordptr
	str r2,[r0] // change where it points
//	ldr r0,=hexnumber
//	mov r1,r2
//	bl printf
_zb1:	
	DONE

	HEADER "BRANCH",6,FLAG_ONLYCOMPILE,BRANCH
	ldr r0,=wordptr
	ldr r1,[r0] // where it points
	ldr r2,[r1] // the next word
	str r2,[r0]
	DONE

	// locate a word and decompile it
	HEADER "SEE",3,FLAG_IMMEDIATE,SEE // cannot be compiled
	bl newwordhelper
	bl findhelper

	KPOP
	cmp r0,#0
	bne _seeword
	DONE // circulate, nothing to see
_seeword:

	// check the flags
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r3,=FLAG_IMMEDIATE
	and r1,r3
	beq _see2
	
	push {r0}
	ldr r0,=immediatedecompilemsg
	bl printf
	pop {r0}
_see2:	
	
	// find the start of the code
	mov r1,r0
	bl get_code_offset
	ldr r0,[r1]
	ldr r2,=0xabadbeef 
	cmp r0,r2
	beq _disasmb
	// assembler word
	ldr r0,=asmmsg
	bl printf
	DONE
_disasmb:
	push {r1}
	ldr r0,=forthmsg
	bl printf
	pop {r1}
_disasm:
	// run through the word until we find a zero
	add r1,#INTLEN
	ldr r0,[r1]
	cmp r0,#0
	beq _disasmend
_tt1:	
	// r0 contains the pointer to the word
	// add the name offset, then print it
	push {r0,r1}
	add r0,#OFFSET_NAME
	mov r2,r0
	ldr r0,=codemsg
	bl printf
	pop {r0,r1}

	// there are a  few special names

	ldr r2,=ZBRANCH
	cmp r0,r2
	beq _printarg
	
	ldr r2,=LIT
	cmp r0,r2
	beq _printarg

	ldr r2,=BRANCH
	cmp r0,r2
	beq _printarg

	ldr r2,=SKIPSTRING
	cmp r0,r2
	beq _printstring
	
	b _disasm
	
_printarg:
	add r1,#INTLEN
	push {r0,r1}
	ldr r0,[r1]
	mov r1,r0
	ldr r0,=argstr
	bl printf
	pop {r0,r1}
	b _disasm

_printstring:
	add r1,#INTLEN
	push {r0,r1}
	ldr r0,[r1]
	mov r1,r0
	ldr r0,=argstr
	bl printf
	pop {r0,r1}
	push {r0,r1}
	add r1,#INTLEN
	ldr r0,=argstrstr
_psb1:	
	bl printf
	pop {r0,r1}
	ldr r1,[r1] // new pointer (skip the string)
	sub r1,#INTLEN
	
	b _disasm
	
_disasmend:	
	DONE
	
	// set the immediate flag
	HEADER "IMMEDIATE",9,FLAG_IMMEDIATE,IMMEDIATE
	ldr r0,=firstword
	ldr r0,[r0]
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_IMMEDIATE
	orr r1,r2
	str r1,[r0,#OFFSET_FLAGS]	
	DONE	

	HEADER "]",1,FLAG_IMMEDIATE,RBRAC
	ldr r1,=1
	ldr r0,=mode
	str r1,[r0]
	DONE

	HEADER "[",1,FLAG_IMMEDIATE,LBRAC
	ldr r1,=0
	ldr r0,=mode
	str r1,[r0]
	DONE

	// not for general use, set to invisible
	HEADER "SKIPSTRING",10,FLAG_INVISIBLE,SKIPSTRING
	ldr r0, =wordptr  	// grab the next thing in the function list
	ldr r1,[r0]
	ldr r1,[r1]		// and move the pointer to it
	str r1,[r0]
	DONE

	
	
