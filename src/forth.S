	# -*- mode: assembler -*-
	#include "hardware/regs/addressmap.h"
	#include "hardware/regs/sio.h"
	
	.thumb_func
	.global forth, done, _stack_restart
	.global stacktop, stackbottom, forthframestackend, forthframestackstart
	.global firstword, freemem, inputptr, buffer
	.global WORD, SWAP,NOP
	.global findhelper, get_code_offset, DUP, mode, wordbuf
	.global input_source_sp, input_source_stack
	.global forthdefs, forthdefs_end
	.cpu cortex-m0

	#ifdef NUCLEO_F103
	.cpu cortex-m3
	.thumb


	#endif


#include "themacros.h"

forth:
//	ldr r0,=__vectors
//	ldr r1,=main
//	str r1,[r0,#0x0c]
	// reset things

	bl resetme

	//	bl stdio_init_all
	//bl dw_uart_init

	ldr r0,='!'
	bl putchar
	
	ldr r0, =hellogoodmorning
	bl printf

	// r5 (IP) is already set to =boot by resetme
	ldr r0,=0
	CFPUSH r0
//	push {r0} // end of input exec marker
	
	// present the interactive prompt
	//bl terminalprompt
	

	// remove immediate & compile logic from this function


execute:
done:
	ldr r1,[r5]     // r1 = word header address at IP
	add r5,#4       // advance IP
	cmp r1,#0
	beq endoflist   // end of the list handler


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
	// store the start of the word in r0 for use by the default exec code
	
	mov r0,r1
	// we replace the calculation of the code offset by accessing the pointer in the word header.
	// this should be a bit more robust + allows us to use the DOES> construct
	ldr r1,[r0,#OFFSET_EXEC]

	// if r1 is zero, we have a variable
	cmp r1,#0
	bne _t7

	// call the address resolver
	ldr r1,=pushwordaddress
	mov pc,r1
_t7:
	// test FLAG_FORTH_WORD flag — no sentinel dereference needed
	ldr r2,[r0,#OFFSET_FLAGS]
	ldr r3,=FLAG_FORTH_WORD
	tst r2,r3
	bne handleforthword

	mov pc,r1          // native asm word: jump to its code

handleforthword:
	CFPUSH r5          // save IP (return address)
	mov r5,r1          // IP = exec ptr = start of Forth word list
	DONE

endoflist:
	// pop the saved IP; if zero, we are at the top level
	CFPOP r5
	cmp r5,#0
	beq reallydone
	DONE

reallydone:
bloop:
	// restart the machine
	ldr r5,=boot       // reset IP to boot list
	ldr r0,=0
	CFPUSH r0          // push 0 sentinel
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
	#include "filewords.h"
	
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
	mov r0,r6
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
	mov r0,r7
	KPUSH
	DONE

	HEADER "RP!",3,0,RPSTORE
	KPOP
	mov r7,r0
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
	push {r5,lr}            // r5=IP must be saved; r6=DSP, r7=RSP are live, do NOT save/restore them
	KPOP
	mov r1,r0 // length
	KPOP
	mov r2,r0 // pointer

	// check for NULL pointer and terminate if we get one
	cmp r2,#0
	bne _fh1

	ldr r0,=finderrornull
	bl printf
	pop {r5,pc}

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

	mov r4,r0 // contains the pointer to the word we compare (r4 = word length = r1 here, safe to reuse)
	add r4, #OFFSET_NAME // transpose to the string part

_findtestloop:
	push {r1}               // save length; use r1 as byte temp
	ldrb r1,[r2,r3]         // r1 = target byte
	ldrb r0,[r4,r3]         // r0 = dict byte
_roggens4:
	// compare strings
	cmp r1,r0
	beq _rg1
	
	add r5,#1
_rg1:
	pop {r1}                // restore length

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

	pop {r5,pc}

	// this is not a match, continue
_nextfl:
	pop {r0}	   // recover the pointer to the next word. FA
	ldr r0, [r0]       // (and fetch the value)
	cmp r0, #0         // continue until we reach the end of the list
_roggens2:
	bne findloop
	ldr r0,=0
	KPUSH		   // nothing found, push 0

	pop {r5,pc}

	

	// -- run a word pointed to by the topmost item on the stack
	// ( xt -- )
	HEADER "EXECUTE",7,0,EXECUTE
	KPOP                       // r0 = execution token (word header address)
	cmp r0,#0
	beq _noexec                // guard: 0 token = no-op

	ldr r1,[r0,#OFFSET_EXEC]   // r1 = exec ptr
	cmp r1,#0
	beq _noexec                // variable — not executable, ignore

	ldr r2,[r0,#OFFSET_FLAGS]
	ldr r3,=FLAG_FORTH_WORD
	tst r2,r3
	bne _exec_forth

	mov pc,r1                  // native word: jump directly

_exec_forth:
	CFPUSH r5                  // save return IP
	mov r5,r1                  // IP = exec ptr (start of Forth word list)
	DONE

_noexec:
	DONE

	
	


	HEADER "NOP",3,0,NOP
	DONE

	HEADER "DUP",3,0,DUP
	KPOP
	KPUSH
	KPUSH
	DONE

	// ( a b -- b a )
	HEADER "SWAP",4,0,SWAP
	push {r4, r5}
	KPOP		// r0 = b (top)
	mov r4, r0
	KPOP		// r0 = a (second)
	mov r5, r0
	mov r0, r4
	KPUSH		// push b
	mov r0, r5
	KPUSH		// push a (now top)
	pop {r4, r5}
	DONE

	// ( a b c -- b c a )
	HEADER "ROT",3,0,ROT
	push {r4, r5}
	KPOP		// r0 = c (top)
	mov r4, r0
	KPOP		// r0 = b (second)
	mov r5, r0
	KPOP		// r0 = a (third)
	mov r3, r0
	mov r0, r5
	KPUSH		// push b
	mov r0, r4
	KPUSH		// push c
	mov r0, r3
	KPUSH		// push a (now top)
	pop {r4, r5}
	DONE

	// ( a b -- a b a )
	HEADER "OVER",4,0,OVER
	push {r4, r5}
	KPOP		// r0 = b (top)
	mov r4, r0
	KPOP		// r0 = a (second)
	mov r5, r0
	mov r0, r5
	KPUSH		// push a
	mov r0, r4
	KPUSH		// push b
	mov r0, r5
	KPUSH		// push a (now top)
	pop {r4, r5}
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
	ldr r2,=inputptr
	ldr r2,[r2]
	ldr r0,=badatoistring
	bl printf

	// then empty the execution context...

	// step 1, is to empty the input buffer
	bl restartinput

	ldr r0,=mode	// reset to interpret mode so the next word starts clean
	ldr r1,=0
	str r1,[r0]
	DONE

	
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
	HEADER "ST",2,FLAG_HIDDEN,STACKTRACE
	push {r5}
	ldr r0,=stacktracestring
	ldr r1,=forthframestackstart
	mov r2,r7               // RSP direct from register
	bl printf

	ldr r5,=forthframestackstart  // r5 = loop pointer

_stl1:
	ldr r1,[r5]
	cmp r1,#0
	bne _stl2

	ldr r0,=stacktracenullstring
	mov r1,r5
	bl printf               // printf preserves r5 (AAPCS callee-saved)
	b _strl3

_stl2:
	ldr r1,[r1]             // actual pointer to a word (next word to execute)
	mov r3,r1
	add r3,#OFFSET_NAME
	mov r2,r1
	mov r1,r5
	ldr r0,=callstackmsg
	bl printf               // printf preserves r5

_strl3:
	add r5,#4
	cmp r5,r7               // done when r5 > r7 (= RSP)
	ble _stl1

	pop {r5}
	DONE
	
	
	
	
	.align 4
	// boot is the core loop we run to exec the interpreter
boot:
	.word FLUSHSTDIN
	.word INTERPRET			// run the text
//	.word EXECUTE
	.int END

// shared fault recovery: reset both Forth stacks and restart the interpreter.
// does not wipe the dictionary, so previously defined words are preserved.
_stack_restart:
	ldr r6,=stacktop                // reset value stack pointer
	ldr r7,=forthframestackend      // reset frame stack pointer
	ldr r0,=cpustacktop             // reset ARM CPU stack to known state
	ldr r0,[r0]
	mov sp,r0
	ldr r0,=bloop
	mov pc,r0


resetme:
	push {lr}
	ldr r0,=freemem
	ldr r1,=heap
	str r1,[r0]

	ldr r0,=link
	ldr r1,=firstword
	str r0,[r1]

	ldr r5,=boot           // initialise IP; forth() will start executing from here

	ldr r0,=cpustacktop
	mov r1,sp
	str r1,[r0]

	ldr r6,=stacktop
	ldr r7,=forthframestackend
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
	.word 0
firstword:
	.word link

	.align 4
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

wordbuf:
	.rept 32
	.byte 0
	.endr

wordbuf2:
	.rept 32
	.byte 0
	.endr
execbuf:
	.word 0
	.word 0
	
inputptr:
	.word forthdefs
inputlen:
	.int  0

	/* Input source stack for INCLUDE nesting.
	   Each entry: { int32 source_id (1=file), int32 vfs_fd }
	   input_source_sp = 0 means empty (bootstrap/UART path active). */
input_source_sp:
	.int 0
input_source_stack:
	.space 64	/* 8 entries × 8 bytes */

forthframestackstart:
       .rept 100
       .word 0
       .endr
forthframestackend:
	.word 0

buffer:
	.rept 200
	.byte 0
	.endr
endbuffer:
	// base only supports 16 and "not 16" at this time. "not 16" defaults to 10


	// read a word from stdin
forthdefs:
	#include "forthdefs.h"

forthdefs_end:
	.align 4

heapguard:
	.int 0x13371337
heap:
	.rept 2000
	.int 0xaddaadba
	.endr
