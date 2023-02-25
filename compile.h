	# -*- mode: asm -*-
	#include "macros.h"
	
	.global LIT, commahelper


	FHEADER "STATE",5,0,STATE
	.word LIT,mode,FETCH,0
	
	# -- make a word placeholder
	
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



	// bump the pointer and store the name itself
	add r5,#INTLEN

_cl1:
	ldrb r3,[r2,r1]
	strb r3,[r5,r1]
	sub r1,#1
	cmp r1,#0
	bne _cl1
	ldrb r3,[r2,r1] // store last letter
	strb r3,[r5,r1]
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

	mov r1,r5
	
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
_o1:	
	eor r1,r2
_o2:	
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
	
	
	
	
	FHEADER ":",1,0,COLON
	.int WORD
	.int CREATE                 // creates a header for a forth word including the marker
	.int LATEST, FETCH, HIDDEN  // LATEST provides the address to the varible containing the latest word link, fetch fetches its content, HIDDEN hides it from searches
	.int RBRAC			// go to compile mode
	.int END

	FHEADER ";",1,FLAG_IMMEDIATE,SEMICOLON
	.int LIT,0,COMMA	// add end of word marker
	.int LBRAC		// end compile mode
	.int LATEST, FETCH, HIDDEN // remove hidden flag
	.int END
	
	# ---- COMMA
	
	# push integer to HERE, increase HERE with integer length
	
	HEADER ",",1,0,COMMA
	bl commahelper
	DONE

	
commahelper:
	push {lr}
	ldr r1,=freemem
	ldr r1,[r1]
	KPOP
	str r0,[r1]
	add r1,#INTLEN
	ldr r0,=freemem
	str r1,[r0]
	pop {pc}
	
	HEADER "LATEST",6,0,LATEST
	ldr r0,=firstword
	KPUSH
	DONE

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
	ldr r5,[r0]
	
	add r5,#3
	lsr r5,#2
	ldr r3,=4
	mul r5,r3

	str r5,[r0]
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

	HEADER "HERE",4,0,HERE
	ldr r0,=freemem
	ldr r0,[r0]
	KPUSH
	DONE

	HEADER "@",1,0,FETCH
	KPOP
	ldr r0,[r0]
	KPUSH
	DONE

	HEADER "!",1,0,STORE
	KPOP
	mov r1,r0
	KPOP
	str r1,[r0]
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

	// can be replaced by a forth definition if "tick" is implemented
	FHEADER "UNTIL",5,FLAG_IMMEDIATE|FLAG_ONLYCOMPILE,UNTIL
	// the stack contains where to jump if the condition is false
	// start by compiling 0BRANCH to the HERE
	.int LIT,ZBRANCH,COMMA
	// then compile the word on the stack to HERE
	.int COMMA
	.int END

	// can be replaced by a forth definition if "tick" is implemented
	FHEADER "IF",2,FLAG_IMMEDIATE|FLAG_ONLYCOMPILE,IF
	.int LIT,ZBRANCH,COMMA // compile a zbranch
	.int HERE              // drop "HERE" on the stack
	.int LIT,0,COMMA       // compile a placeholder for the jump we do if we are not doing the IF code
	.int END

	FHEADER "ELSE",4,FLAG_IMMEDIATE|FLAG_ONLYCOMPILE,ELSE
	// compile a placeholder jump to the stack, to finalize the ongoing branch
	// then back-compile the new address to the previous placeholder
	.int LIT,BRANCH,COMMA // A branch that we always take
	.int HERE
	.int LIT,0,COMMA // new placeholder to fill for the THEN
	.int SWAP               // get the old address (put "IF NOT JUMP" on top)
	.int HERE,STORE         // and make it jump here
	.int END

	FHEADER "THEN",4,FLAG_IMMEDIATE|FLAG_ONLYCOMPILE,THEN
	.int HERE             // drop the address where we are to the stack
	.int STORE	      // and put it in the placeholder we compiled earlier
	.int LIT,NOP,COMMA    // something to land at
	.int END


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

	HEADER "SKIPSTRING",10,0,SKIPSTRING
	ldr r0, =wordptr  	// grab the next thing in the function list
	ldr r1,[r0]
	ldr r1,[r1]		// and move the pointer to it
	str r1,[r0]
	DONE
	
