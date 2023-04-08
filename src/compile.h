//	# -*- mode: asm -*-
	#include "themacros.h"
	
	.global LIT, commahelper


	FHEADER "STATE",5,0,STATE
	.word LIT,mode,FETCH,0

	// memcpy
	// (addr1 addr2 u --)
	// copy u characters from addr1 to addr2
	HEADER "CMOVE",4,0,CMOVE
	KPOP
	mov r2,r0		// r2 contains the length to copy
	KPOP
	mov r1,r0		// r1 contains the destination
	KPOP
	// r0 contains the source
	bl mymemcpy
	DONE
	
	//
	// -- make a word placeholder

	FHEADER "CREATE",6,0,CREATE

	// create does roughly this:
	.word LATEST,FETCH,TOR			// get the address to the first word in the dictionary
	.word HERE, LATEST, STORE		// set the first word pointer to this word
	.word RFROM,COMMA			// and link this word to the previously first word
	.word LIT,0,COMMA		 	// set the initial flags to zero
	.word WORD,DUP,COMMA			// get the name of the word, store the string length in the header, saving it for later
	.word DUP,TOR				// save the length of the string on the call stack
	.word LIT,0,COMMA			// pointer to exec context, if this is zero, call pushwordaddress

	// on the stack we have this (addr1 u)
	// we need to make the stack (addr1 here u+1)

	.word TOR, HERE, RFROM			// flip the values using the call stack
	.word LIT,1,PLUS			// the string from WORD is zero terminated, but that is not included in the length
	.word CMOVE				// copies the word name to the word definition
	.word RFROM, HERE, PLUS, LIT, 1, PLUS	// string length from call stack, calculate the end of the string
	.word DP,STORE				// and update "HERE"
	.word ALIGN				// and aligns the storage space with word boundaries
	.word END
	
	// figure out where the end of the word pointed to by r0 is
	// dump it on the stack
pushwordaddress:
	ldr r2,[r0,#OFFSET_LENGTH] // get the length of the word name
	mov r1,r0		   // add it to the pointer to the word
	add r1,r2
	add r1,#1 			// +1 to include zero termination
	add r1,#OFFSET_EXEC	  // and add the length of the header up to the start of the name

	// r1 now contains the address after the name of the word
	// adjust it

	bl alignhelper
	mov r0,r1
	KPUSH
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
	//	.int WORD //, OVER, TYPE, LIT, 32, EMIT // if we need to debug word creation
	.int CREATE                 // creates a header for a forth word excluding the marker
	// we also have to set the execution pointer in the word to point
	// at "HERE"
	
	.int HERE, LATEST, FETCH, LIT, OFFSET_EXEC, PLUS, STORE
	
	
	.int LIT,0xabadbeef,COMMA  // forth marker
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

	VARIABLE "DP",2,DP,freemem
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

	
	
