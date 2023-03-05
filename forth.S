	# -*- mode: assembler -*-
	#include "hardware/regs/addressmap.h"
	#include "hardware/regs/sio.h"

	.thumb_func
	.global main, done, _kpop, _kpush
	.global wordptr, firstword, freemem, inputptr, buffer
	.global WORD, SWAP,NOP
	.global findhelper, get_code_offset, DUP, mode, wordbuf
	.cpu cortex-m0
	
#include "macros.h"


main:
//	ldr r0,=__vectors
//	ldr r1,=main
//	str r1,[r0,#0x0c]
	// reset things

	bl resetme
	
	mov r7, #0
	bl stdio_init_all
	ldr r0, =hellogoodmorning
	bl printf

	# execute the functions linked from "words"
	ldr r0,=wordptr
	ldr r1,=boot
	str r1,[r0]

	
	ldr r0,=0
	CFPUSH r0
//	push {r0} // end of input exec marker
	
	// present the interactive prompt
	//bl terminalprompt
	

	// remove immediate & compile logic from this function


execute:	
done:
//	ldr r0,=hexdebug
//	ldr r1,=wordptr
//	ldr r1,[r1]
//	bl printf

	// execute the next word in the list, unless we are done executing words in the list
	
	ldr r0, =wordptr
	ldr r1,[r0]
	mov r2,r1
_t2:	
	add r1,#4   // increase the pointer one step
	str r1,[r0]
_t1:	
	ldr r1,[r2]
	cmp r1, #0
	beq endoflist // end of the list handler


//	push {r1}             // push A
//	ldr r0,=runmsg
//	add r1,#OFFSET_NAME
//	bl printf
//  	pop {r1}              // pop A
	
	// r1 now contains the pointer to a structure containing the word, not the code as such
	// hence, we can operate on r1 with offsets, BUT we also have to seek where the actual code is
	// when we intend to execute it
	
runthecode:

	ldr r0,=debugflag
	ldr r0, [r0]
	cmp r0,#1
	bne _nodp1

	push {r1}
	push {r1}
	ldr r0, =worddescstring
	mov r2, r1
	add r2, #OFFSET_FLAGS
	ldr r2, [r2]
	mov r3, r1
	add r3, #OFFSET_LENGTH
	ldr r3, [r3]

	// we replace the calculation of the code offset by accessing the pointer in the word header.
	// this should be a bit more robust + allows us to use the DOES> construct
	//bl get_code_offset
	ldr r1,[r1,#OFFSET_EXEC]
	ldr r4,[r1]
	pop {r1}
_fd:	
	add r1, #OFFSET_NAME
	
	bl printf
	pop {r1}
_nodp1:
	// when we are here, we will execute a word written in assembler
	// record this in the call graph
//	bl pushforthcall
	
	// r1 contains the pointer to the start of the word,
	// use the helper to get the start of the wordlist/code

	// we replace the calculation of the code offset by accessing the pointer in the word header.
	// this should be a bit more robust + allows us to use the DOES> construct
	//bl get_code_offset
	ldr r1,[r1,#OFFSET_EXEC]
	
	// now we have the pointer to the code list in r1

	// load the first word of whatever we are pointing at
	// if that is number 1, the word we intend to execute
	// is a forth-defined word

	
	ldr r2,[r1]
_t6:
	ldr r5,=0xabadbeef
	cmp r2,r5
	beq handleforthword

//	push {r1}
//	ldr r0,=codedebugstring
//	bl printf
//	pop {r1}
	
	mov pc,r1 // jump to the next word in the list

	// handle a word written in forth.
	
handleforthword:
//	push {r1}
//	ldr r0,=forthwordstring
//	bl printf
//	pop {r1}
	// start by bumping the address to the next item in the list,
	// which is a pointer to an actual word
	add r1,#INTLEN

	ldr r0,=wordptr
	ldr r2,[r0]

	CFPUSH r2
	//push {r2}        // push item we want to execute when we are done with this word, to the stack
	
	str r1,[r0]      // store wordptr
	mov r1,r2
	// when we are here, we will execute a word written in forth
	// record the call in the call trace
//	bl pushforthcall
//	bl pushforthcall // reasons. - to keep a trace once we pop the trace in DONE
	DONE             // and run the word
		


	
endoflist:
	// here we need to pop the old pointer, if the old pointer is zero, we go to prompt
	CFPOP r0
	//pop {r0}
	cmp r0,#0
	beq reallydone
_t3:	
	ldr r1,=wordptr
	str r0,[r1]      // store wordptr
	DONE
	
reallydone:	
//	ldr r0, =donemsg
//	bl printf
bloop:

	// restart the machine:
	// execute the functions linked from "words"
	ldr r0,=wordptr
	ldr r1,=boot
	str r1,[r0]       // store wordptr

	ldr r0,=0

	CFPUSH r0
	//push {r0} // end of input exec marker
	// record it in the list
//	mov r1,r0
//	bl pushforthcall

	b execute

//	.global isr_hardfault
	
//isr_hardfault:	
//	ldr r0, =errormsg
//	bl printf
//	bl resetme
//	ldr r0,=0xFFFFFFF9UL
//	mrs r0,ipsr
//	mov r0,lr
	
	

	
	// helper to get the offset to the code from a pointer to a word
get_code_offset:
	// the actual code is located at
	// word base + OFFSET_NAME + name length (OFFSET_LENGTH) + padding

	// r1 contains the word base
	// get the length


	push {r3,lr}
	ldr r3, [r1,#OFFSET_LENGTH]
	add r1, r3
	add r1, #1  // null terminator of word name
	add r1, #OFFSET_NAME
	// pad the pointer to get to where the code is
	add r1,#15
	lsr r1,#4
	ldr r3,=16
	mul r1,r3
	pop {r3,pc}

//// ############## WORD DEFINITIONS ############################ ///	

	// split to other files, but have to be included due to macro magic
	#include "compile.h"
	#include "terminal.h"
	#include "output.h"	
	#include "mathwords.h"
	
	HEADER "WORDS", 5, 0 , WORDS
	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
wordsloop:

	push {r0}          // push W1

	// do not print hidden or invisible words
	ldr r3,[r0,#OFFSET_FLAGS]
	mov r1,r3
	ldr r2,=FLAG_HIDDEN 
	and r1,r2
	bne skipprint

	mov r1,r3
	ldr r2,=FLAG_INVISIBLE
	and r1,r2
	bne skipprint

	add r0,#OFFSET_NAME	   
	bl printf	   // print the word
	
	ldr r0,=' '        // then print a space
	bl putchar
skipprint:	
	pop {r0}	   // pop W1, recver the pointer to the next word
	ldr r0, [r0]       // (and fetch the value)
	cmp r0, #0         // continue until we reach the end of the list
	bne wordsloop
	
	ldr r0,='\n'       // then finish with newline and return
	bl putchar
	DONE

	# access to debug flag
	# a variable
	FHEADER "DEBUG", 5, 0, DEBUGFLAG
	.word LIT,debugflag
	.word END

	# ------- stack manipulation -------
	
	HEADER "DROP",4,0,DROP
	KPOP
	DONE

	// constants to get the state of the stack
	// fetch the current stack pointer
	HEADER "SP@",3,0,SPFETCH
	ldr r0,=vstackptr
	ldr r0,[r0]
	KPUSH
	DONE

	// fetch the initial stack pointer
	HEADER "SP0",3,0,SP0
	ldr r0,=stacktop
	KPUSH
	DONE

	// return stack manipulation

	HEADER "R>",2,FLAG_ONLYCOMPILE,RFROM
	CFPOP r0
	KPUSH
	DONE

	
	HEADER ">R",2,FLAG_ONLYCOMPILE,TOR
	KPOP
	CFPUSH r0
	DONE

	HEADER "RP@",3,0,RPFETCH
	ldr r0,=forthframestackptr
	ldr r0,[r0]
	KPUSH
	DONE

	HEADER "RP!",3,0,RPSTORE
	KPOP
	ldr r1,=forthframestackptr
	str r0,[r1]
	DONE

	HEADER "RP0",3,0,RP0
	ldr r0,=forthframestackstart
	KPUSH
	DONE
	
	HEADER "CRASH",5,0,CRASH
	//	ldr r0,=main
	//	add r0,#1
	//	str r1,[r0]
	ldr r0,=0
	mov pc,r0
	DONE
//	bl resetme
//	ldr r0,=main
//	mov pc,r0
	
	# --------------------
	# --- FIND ------------

	// r0 - linked list pointer
	// r1 - target word length
	// r2 - target word string pointer

	// in the match loop:
	// r3 - loop indexer
	
	HEADER "FIND",4,0,FIND
	// traverse the word linked list and see if we match what we have on the stack
	// consume the length and the address of the word on the stack

	bl findhelper
	DONE

findhelper:
	push {lr}
	KPOP
	mov r1,r0 // length
	KPOP
	mov r2,r0 // pointer

	// check for NULL pointer and terminate if we get one
	cmp r2,#0
	bne _fh1

	ldr r0,=finderrornull
	bl printf
	pop {pc}

_fh1:	

		
	// drop the address to the word header on the stack on match, zero on no match

	// start at the end of the list

	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)

	
findloop:
	// go through the words
	
	push {r0}  // push FA
	ldr r4,[r0,#OFFSET_LENGTH]

	// match the length	
	cmp r4,r1  // then compare to the word we have on the stack
_roggens:			
	bne _nextfl // jump to the next part if it does not match

_roggens5:
	// if r5 is zero when we are done, we have a match
	ldr r5,=0
	ldr r3,=0
	// r4 contains the length of the string in the word we are checking against

	mov r6,r0 // contains the pointer to the word we compare
	add r6, #OFFSET_NAME // transpose to the string part

_findtestloop:	
	ldrb r7,[r2,r3]
	ldrb r0,[r6,r3]
_roggens4:
	// compare strings
	cmp r7,r0
	beq _rg1
	
	add r5,#1
_rg1:	

	add r3,#1
	cmp r3,r1
_roggens3:	
	blt _findtestloop

	// not a match
	cmp r5,#0
	bne _nextfl

	// match
	//ldr r0,='*'        
	//bl putchar

	// cleanup and return
	pop {r0}  // push pointer to match to the value stack
	
	KPUSH

	pop {pc}

	// this is not a match, continue
_nextfl:
	pop {r0}	   // recover the pointer to the next word. FA
	ldr r0, [r0]       // (and fetch the value)
	cmp r0, #0         // continue until we reach the end of the list
_roggens2:	
	bne findloop
	ldr r0,=0
	KPUSH		   // nothing found, push 0

	pop {pc}

	

	// -- run a word pointed to by the topmost item on the stack
	// only works for non-forth-words
	HEADER "EXECUTE",7,0,EXECUTE
	KPOP
	cmp r0,#0
	beq _noexec
	mov r1,r0
	ldr r0,=runthecode
	mov pc,r0
//	bl get_code_offset
//	mov pc,r1
_noexec:
	DONE
	
	


	HEADER "NOP",3,0,NOP
	DONE

	

	// ---------- interpreter ---------
	
	HEADER "INTERPRET",9,0,INTERPRET
	// get words from input until exhausted
	// run each word through execution
	// happy fun time
interpreter:	
	// we can reuse code from the forth words earlier defined:
	bl newwordhelper // drops word and length of word on the forth stack
	bl findhelper // find the word, drops pointer or zero on the forth stack

	// when we get here, we have found the word we are looking for
	// now check if the word is an IMMEDIATE word, in which case we will jump
	// directly to execution

	// check if the word was found or not. If it was not found, we assume it is
	// a literal and try to parse it
	
	KPOP
	cmp r0,#0
	bne foundaword // found something, go process it

	// the string we got and couldn't find a word for is available in wordbuf
	// try converting it to an integer

	ldr r0,=wordbuf
	ldr r1,=base
	ldr r1,[r1]
	bl myatoi

	bvc _goodatoi

	mov r1,r0
	ldr r0,=badatoistring
	bl printf
	
_goodatoi:	
	
	mov r0,r2
	
	// note that a failed lookup and a failed conversion will result in a zero (0) value

	ldr r1,=mode
	ldr r1,[r1]
	cmp r1,#1    // compile mode
	beq litcompile
	KPUSH
	DONE
	
litcompile:
	push {r0}
	
	ldr r0,=LIT   // pointer to the lit word
	KPUSH
	bl commahelper
	
	pop {r0}
	KPUSH
	bl commahelper
	
//	ldr r0,=compiling
//	bl printf
	
	b interpreter
	
foundaword:	

	// check immediate mode here

	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_IMMEDIATE 
	and r1,r2
	bne goimmediate
	
	ldr r1,=mode
	ldr r1,[r1]
	cmp r1,#1
	beq wordcompile
	
goimmediate:	
	mov r1,r0
	ldr r0,=runthecode
	mov pc,r0

wordcompile:
	// push r0 to HERE
	KPUSH
	bl commahelper
	
//	ldr r0,=compiling
//	bl printf

	b interpreter

//	HEADER "EVALUATE",8,0,EVALUATE
//	ldr r0,=inputptr
//	ldr r1,[r0]
//	KPOP
//	str r0,[r1]
//	DONE
	
	// print a stacktrace of the calls from where we are to the first 0
	HEADER "ST",2,FLAG_HIDDEN,STACKTRACE // disabled
	// start with the stack pointer, read each item, move up until we have a zero

	// print basic information about the call stack
	ldr r0, =stacktracestring
	ldr r1,=forthframestackstart
	ldr r2,=forthframestackptr
	ldr r2,[r2]
	bl printf
	
	ldr r7,=forthframestackstart

_stl1:
	ldr r1,[r7] // pointer to somewhere in a list. this is the _next_ word we intend to execute.
	cmp r1,#0
	bne _stl2

	// if we are here, we are at the "end marker" (which is NULL)
	push {r7}
	ldr r0,=stacktracenullstring
	mov r1,r7
	bl printf
	pop {r7}
	b _strl3
_stl2:

	ldr r1,[r1] // actual pointer to a word - to the _next_ word we intend to execute.
	mov r3,r1
	add r3,#OFFSET_NAME
	mov r2,r1
	mov r1,r7
	ldr r0,=callstackmsg
	push {r7}
	bl printf
	pop {r7}
_strl3:				
	add r7,#4
	ldr r6,=forthframestackptr
	ldr r6,[r6]
	cmp r7,r6
	ble _stl1
	DONE
	
	
	
	
	.align 4
	// boot is the core loop we run to exec the interpreter
boot:
	.word FLUSHSTDIN
	.word INTERPRET			// run the text
//	.word EXECUTE
	.int END

_kpush:	
        push {r1,r2,lr}
        ldr r1, =vstackptr               // get the pointer to the bottom of the stack
        ldr r2,[r1]
        str r0,[r2]                     // store the value on the stack
        sub r2,#INTLEN      // update the stack pointer
        str r2,[r1]
        pop {r1,r2,pc}


_kpop:	
	push {r1,lr}
	ldr r1,=vstackptr
	ldr r0,[r1]
	add r0,#INTLEN
	str r0,[r1]
	ldr r0,[r1]
	ldr r0,[r0]
	pop {r1,pc}


resetme:
	push {lr}
	ldr r0,=freemem
	ldr r1,=heap
	str r1,[r0]

	ldr r0,=link
	ldr r1,=firstword
	str r0,[r1]

	ldr r0,=wordbuf
	ldr r1,=wordptr
	str r0,[r1]

	ldr r0,=cpustacktop
	mov r1,sp
	str r1,[r0]

	ldr r0,=forthframestackptr
	ldr r1,=forthframestackend
	str r1,[r0]
	
	pop {pc}


	.data

	.align 4
		
sourceid:
	.word -1  // we start executing the core words
base:	
	.word 10
dbw:
	.word 0
	.align 4
freemem:
	.word heap

	// compile or interpretation mode
mode:
	.word 0
debugflag:
	.word 1
firstword:
	.word link

	.align 4
vstackptr:
	.word stacktop
	
stackbottom:
	.rept 200
	.int 0
	.endr
stacktop:
	.int 0
endstack:
	.align 4
cpustacktop:
	.int 0

wordptr:
	.word 0

wordbuf:
	.rept 32
	.byte 0
	.endr

wordbuf2:
	.rept 32
	.byte 0
	.endr
	
inputptr:	
	.word forthdefs
inputlen:
       .int  0
forthframestackstart:
       .rept 100
       .word 0
       .endr
forthframestackend:
	.word 0
forthframestackptr:
       .word forthframestackend
	      
buffer:
	.rept 200
	.byte 0
	.endr
endbuffer:
	// base only supports 16 and "not 16" at this time. "not 16" defaults to 10


	// read a word from stdin
forthdefs:
	#include "forthdefs.h"
	
	.align 4	

heapguard:
	.int 0x13371337
heap:
	.rept 2000
	.int 0xaddaadba
	.endr
