#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
	
	.thumb_func
	.global main
	.global execute
	.global buffer
	.global endbuffer
	
	.cpu cortex-m0
	
	.macro DONE
	ldr r0,=done
	mov pc,r0
	.ltorg  // allow a literal pool here
	.endm

# to create the built in words

	#define FLAG_HIDDEN    0x1
	#define FLAG_IMMEDIATE 0x2

	#define END 0x0
	
	.set link,0
	
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

	.macro HEADER word, wordlen, flags, label
	RAWHEADER "\word", \wordlen, \flags, \label
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

//goff:	
//	blx main
	
	.macro FHEADER word, wordlen, flags, label
	RAWHEADER "\word", \wordlen, \flags, \label
	.int 0xabadbeef // signals that this is a forth-defined word
	.endm
	
	#define	OFFSET_FLAGS  (flags_WORDS-next_WORDS)
//	#define OFFSET_CODE   (WORDS-next_WORDS)         // this... does not work, since the size of the ascii is all different.
	#define OFFSET_NAME   (word_WORDS-next_WORDS)
	#define OFFSET_LENGTH (length_WORDS-next_WORDS)
	#define INTLEN 	      (word_WORDS-length_WORDS)

main:
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
	push {r0} // end of input exec marker
	
	
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

	bl get_code_offset
	ldr r4,[r1]
	pop {r1}
_fd:	
	add r1, #OFFSET_NAME
	
	bl printf
	pop {r1}
_nodp1:	
	
	// r1 contains the pointer to the start of the word,
	// use the helper to get the start of the wordlist/code
	bl get_code_offset
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
	push {r2}        // push item we want to execute when we are done with this word, to the stack

	str r1,[r0]      // store wordptr
	DONE             // and run the word
		


	
endoflist:
	// here we need to pop the old pointer, if the old pointer is zero, we go to prompt	
	pop {r0}
	cmp r0,#0
	beq reallydone
_t3:	
	ldr r1,=wordptr
	str r0,[r1]      // store wordptr
	b done
	
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
	push {r0} // end of input exec marker

	b execute

isr_hardfault:	
	ldr r0, =errormsg
	bl printf
	b main

errormsg:
	.asciz "HardFault - restarted"

	
	###
	##	strings

compilemsg:
	.asciz "Compiling %s...\n"

runmsg:
	.asciz "Running %s...\n"

notimmediatemsg:	
	.asciz "Not immediate %s...\n"

immediatemsg:	
	.asciz "Immediate %s...\n"
	.align 4
	
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
	
	
	# -------------
	# a couple of test words

	# -------------
	

	# utility macros to move things on and off the value stack
	# both operate on r0
	.macro KPOP
	bl _kpop
	.endm
		
	.macro KPUSH
	bl _kpush
	.endm
	
	HEADER "WORDS", 5, 0 , WORDS
	ldr r0, =firstword // get the pointer to the first word in the list
	ldr r0, [r0]       // (and fetch the value)
wordsloop:
	push {r0}          // push W1

	// do not print hidden words
	ldr r1,[r0,#OFFSET_FLAGS]
	ldr r2,=FLAG_HIDDEN 
	cmp r1,r2
	beq skipprint
	
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

	# ---- arithmetics ----
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

	# divide...
	# using the hardware divider
	HEADER "/MOD",4,0,DIVMOD
	ldr r3,=SIO_BASE
	KPOP
	str r0, [r3, #SIO_DIV_SDIVISOR_OFFSET]
	KPOP
	str r0, [r3, #SIO_DIV_SDIVIDEND_OFFSET	]

	// delay 8 cycles

	b 1f
1: 	b 1f	
1: 	b 1f
1: 	b 1f
1:
	ldr r0, [r3, #SIO_DIV_REMAINDER_OFFSET]
	KPUSH
	ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET]
	KPUSH
	DONE

	FHEADER "/",1,0,SLASH
	.word DIVMOD, SWAP, DROP, 0

	FHEADER "MOD",3,0,MOD	
	.word DIVMOD, DROP, 0
	

	# -------- end arithmetics -------



	# ------- stack manipulation -------
	
	HEADER "DUP",3,0,DUP
	KPOP
	KPUSH
	KPUSH
	DONE

	HEADER "SWAP",4,0,SWAP
	KPOP
	mov r1,r0
	KPOP
	mov r2,r0
	mov r0,r1
	KPUSH
	mov r0,r2
	KPUSH
	DONE

	FHEADER "OVER",4,0,OVER
	.word SWAP, DUP, ROT, SWAP
	.int END
	
	HEADER "DROP",4,0,DROP
	KPOP
	DONE

	HEADER "ROT",3,0,ROT
	KPOP
	mov r1,r0
	KPOP
	mov r2,r0
	KPOP
	mov r3,r0
	mov r0 ,r2
	KPUSH
	mov r0,r1
	KPUSH
	mov r0,r3
	KPUSH
	DONE
	
	
	
	# ------ output -------	

	HEADER ".",1,0,DOT
	KPOP
	ldr r2,=base
	ldr r2,[r2]
	cmp r2,#16
	beq _hex
	mov r1,r0
	ldr r0,=numberstring
	bl printf
	DONE
_hex:
	mov r1,r0
	ldr r0,=hexnumber
	bl printf
	DONE

	# print a char from ascii on the stack
	HEADER "EMIT",4,0,EMIT
	KPOP
	bl putchar
	DONE

	# print a string from ascii pointed to by an item on the stack
	HEADER "TYPE",4,0,TYPE
	KPOP
	bl printf
	DONE
	
	FHEADER "CR",2,0,CR
	.word LIT,10,EMIT,0

	FHEADER "SPACE",5,0,SPACE
	.word LIT,32,EMIT,0

	# ------ memory manipulation ---------

	HEADER "HERE",4,0,HERE
	ldr r0,=freemem
	ldr r0,[r0]
	KPUSH
	DONE

	# input handling

	HEADER "FLUSHSTDIN",10,0,FLUSHSTDIN
	ldr r0,=0	
_fss:			
	bl getchar_timeout_us
	cmp r0, #0
	bge _fss  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	DONE
	
	HEADER "PROMPT",6,0,PROMPT
	// read from terminal, put in input buffer
	// displays a prompt, reads text from stdin, puts it in "buffer"
terminalprompt:
	// we need to get rid of pre-existing garbage here
//	bl flushserial

	ldr r0,=0
_fsl:	
	bl getchar_timeout_us
	cmp r0, #0
	bge _fsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	
	ldr r0,='>'
	bl putchar
	ldr r0,=' '
	bl putchar

	// read from the terminal
	// (cheating, with rpi library code)

	ldr r1,=buffer
	ldr r2,=input
	str r1,[r2]

loopzor:
	push {r1}
	
	bl getchar
	bl putchar // echo

	pop {r1}

	cmp r0,#'\n'
	beq endloopzor
	cmp r0,#'\r'
	beq endloopzor
	
	strb r0,[r1]
	add r1,#1
	
	b loopzor

endloopzor:
	ldr r0,=0
	strb r0,[r1]
	ldr r0,='\n'
	bl putchar
	// debug code
	//	ldr r0,=buffer
	//	bl printf
	// and return to whoever called us
_tpret:
	DONE

flushserial:
	push {lr}  // push FSL
	ldr r0,=0
_ofsl:	
	bl getchar_timeout_us
	cmp r0, #0
	bge _ofsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	pop {pc}  // pop FSL

	

	// rewrite this to read from the input instead of from a tokenized row
	
	HEADER "WORD",4,0,WORD
	// read from input buffer until space, enter, or zero is found.
	bl newwordhelper
	DONE


	# --- restart

	HEADER "RESET",5,0,RESET
	bl resetme
	b main
	DONE
	
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

	// there is a bug in this code, we should return the newest match, but we return the oldest
findhelper:
	push {lr}
	KPOP
	mov r1,r0 // length
	KPOP
	mov r2,r0 // pointer

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
	sub r7,r0
	add r5,r7

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

	// and pad the end of the word up to the code place with a very visible filler
	ldr r3,=0xAA
	ldr r2,=0xFF
cloop:
	strb r3,[r1]
	eor r3,r2
	add r1,#1
	cmp r1,r5
	bne cloop
	
	
	// and we are good to go
_created:			
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

	FHEADER ":",1,0,COLON
	.int WORD
	.int CREATE
	.int LIT, 0xabadbeef, COMMA          // this compiles a "1" into the word which indicates to the system that it is defined in forth, not assembler
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

	HEADER "@",1,0,FETCH
	KPOP
	ldr r0,[r0]
	KPUSH
	DONE

	FHEADER "DEMO",4,0,DEMO
	.int LIT,7,LIT,3,DUP,LIT,1
	.int DOT,DOT,DOT,DOT, CR
	.int END
	
	FHEADER "BASE",4,0,BASE
	.int LIT,base
	.int END

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
	bl atoi

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
	
	ldr r0,=compiling
	bl printf
	
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
	
	ldr r0,=compiling
	bl printf

	b interpreter
	
	
	// read a word from stdin
	
newwordhelper:

	push {lr}
	
	// start by discarding everything that is a newline, carriage return, space

_nww_l1:	
	bl getchar		
	bl putchar // echo

	cmp r0,#0
	beq _nww_l1
	cmp r0, #' '
	beq _nww_l1
	cmp r0, #'\n'
	beq _nww_l1
	cmp r0, #'\r'
	beq _nww_l1

	ldr r1,=wordbuf
	
	// read until we get a char we don't want
_nww_l2:
	strb r0,[r1]
	add r1, #1
	
	push {r1}
	bl getchar		
	bl putchar // echo
	pop {r1}
	
	cmp r0,#0
	beq _nww_l2_end
	cmp r0, #' '
	beq _nww_l2_end
	cmp r0, #'\n'
	beq _nww_l2_end
	cmp r0, #'\r'
	beq _nww_l2_end

ap:	
	b _nww_l2
	
_nww_l2_end:
	cmp r0,#'\r'
	bne _nww_l3
	push {r1}
	ldr r0,='\n'
	bl putchar
	pop {r1}
_nww_l3:	
	ldr r0,=0
	strb r0,[r1]

	ldr r0,=wordbuf
	KPUSH
	sub r1,r0
	mov r0,r1
	KPUSH

//	ldr r0,=debugwordmsg
//	ldr r1,=wordbuf
//	bl printf
	
	pop {pc}

	// ---

debugwordmsg:
	.asciz "Token: %s\n"


	

hexnumber:
	.asciz "%x"
hexdebug:
	.asciz "wordptr: %x\n"
	
	
	.align 4		
boot:
//	.word PROMPT
//	.word PROMPT
//	.word WORD
//	.word FIND
	//	.word EXECUTE
	.word FLUSHSTDIN
	.word INTERPRET			// run the text
//	.word EXECUTE
	.int END

_kpush:	
        push {r1,r2,lr}
        ldr r1, =stackptr               // get the pointer to the bottom of the stack
        ldr r2,[r1]
        str r0,[r2]                     // store the value on the stack
        sub r2,#endstack-stacktop       // update the stack pointer
        str r2,[r1]
        pop {r1,r2,pc}


_kpop:	
	push {r1,lr}
	ldr r1,=stackptr
	ldr r0,[r1]
	add r0,#endstack-stacktop
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

	pop {pc}

	
	###
	## variables

	.data

compiling:
	.asciz " <C> "
hellogoodmorning:	
	.asciz "\n\n\nWelcome!\n\n"
donemsg:
	.asciz "\nOK "
numberstring:
	.asciz "%d"
debugstring:
	.asciz "<%s>\n"
worddescstring:	
	.asciz "<%s, flags=%x, length=%d, v=%x>\n"
debugnumber:
	.asciz "[%d]"
codedebugstring:
	.asciz "->%x\n"
forthwordstring:
	.asciz "forth word starting at %x\n"
	.align 4
dbw:
	.word 0
input:
	.word buffer
buffer:
	.rept 200
	.byte 0
	.endr
endbuffer:
	.align 4
freemem:
	.word endstack

	// base only supports 16 and "not 16" at this time. "not 16" defaults to 10
base:
	.word 10

	// compile or interpretation mode
mode:
	.word 0
debugflag:
	.word 0
firstword:
	.word link

	.align 4
stackptr:
	.word stacktop
	
stackbottom:
	.rept 200
	.int 0
	.endr
stacktop:
	.int 0
endstack:
	.align 4
wordptr:
	.word 0

wordbuf:
	.rept 32
	.byte 0
	.endr
heap:
	.rept 2000
	.int 0xaddaadba
	.endr
