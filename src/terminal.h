	# -*- mode: asm -*-
	#include "themacros.h"
	
	.global terminalprompt
	.global FLUSHSTDIN
	.global PROMPT, WORD
	.global newwordhelper
	.global restartinput
	
	# input handling

	CONSTANT "SOURCE-ID",9,SOURCEID,sourceid
	
	
	
	HEADER "S\"",2,FLAG_IMMEDIATE,SQUOTE
	ldr r0,=SKIPSTRING
	KPUSH
	bl commahelper
	
	// where to do the branch later
	ldr r0,=freemem
	ldr r0,[r0]
	push {r0}  // save the address for a later write
	ldr r0,=0  // placeholder for branch memory
	KPUSH
	bl commahelper
	
	// read the string until "
	ldr r1,=freemem  // where to write the string
	ldr r1,[r1]
	push {r1}        // this is where the string is. This goes to the stack after we are done

//	bl mygetchar	// consume the mandatory space delimiter (not part of the string)

_sq2:
	bl mygetchar
	strb r0,[r1]     // store it in the memory, and increase the pointer
	cmp r0,#'\"'     // read until we get a "
	beq _sq1
	add r1,#1
	b _sq2
	
_sq1:
	ldr r0,=0    // NULL terminate the string
	strb r0,[r1]

	push {r1}   // save null-byte position for strlen computation

	// align freemem to next 4-byte boundary *past* the null byte
	// (+3 would land on the null itself when strlen is a multiple of 4)
	add r1,#4
	lsr r1,#2
	ldr r3,=4
	mul r1,r3
	ldr r0,=freemem
	str r1,[r0]

	pop {r2}   // r2 = null-byte position
	pop {r4}   // r4 = string start address
	pop {r0}   // r0 = placeholder address (branch target)
	sub r2,r4  // r2 = strlen = null_pos - string_start

	str r1,[r0]

	// compile the string pointer as literal
	ldr r0,=LIT
	KPUSH
	bl commahelper

	mov r0,r4
	KPUSH
	bl commahelper

	// compile strlen as literal (ANS: S" pushes c-addr u)
	push {r2}          // r2 is caller-saved; protect across bl commahelper
	ldr r0,=LIT
	KPUSH
	bl commahelper
	pop {r0}           // r0 = strlen
	KPUSH
	bl commahelper


//	ldr r0,=0  // end of word
//	KPUSH
//	bl commahelper
	DONE
	
	
	// read one character from input (if the input is redirected to a block of text and not using terminal input, we read from that place)
	HEADER "KEY",3,0,KEY
	bl mygetchar
	KPUSH
	DONE
	
	HEADER "FLUSHSTDIN",10,FLAG_INVISIBLE,FLUSHSTDIN
	ldr r0,=0	
_fss:			
//	bl getchar_timeout_us
//	cmp r0, #0
	//	bge _fss  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	bl flushinput
	DONE
	
	HEADER "READ-LINE",6,0,PROMPT
	// read from terminal, put in input buffer
	// displays a prompt, reads text from stdin, puts it in "buffer"
	bl readlinehelper
	DONE
	
readlinehelper:
	// we need to get rid of pre-existing garbage here
	//	bl flushserial

	push {lr}

	ldr r0,=mode
	ldr r0,[r0]
	cmp r0,#0
	beq _rlh_nc
	
	ldr r0,=compilingstr
	bl printf
_rlh_nc:	
	ldr r0,=inputlen
	ldr r0,[r0]
	cmp r0, #0
	beq _rlh1 // do not print the prompt, the previous line was empty
	
	ldr r0,='o'
	bl putchar
	ldr r0,='k'
	bl putchar
	ldr r0,='\n'
	bl putchar
	  
	// read from the terminal
	// (cheating, with rpi library code)
_rlh1:	
	ldr r1,=buffer
	ldr r2,=inputptr
	str r1,[r2]

loopzor:
	push {r1}
	bl getchar
	bl putchar
	pop {r1}

	cmp r0,#'\n'
	beq endloopzor
	cmp r0,#'\r'
	beq endloopzor

	# backspace
	cmp r0,#8
	bne _notbackspace

	ldr r0,=buffer
	cmp r1,r0
	beq _bs1
	
	sub r1,#1
_bs1:	
	ldr r0,=0	
	strb r0,[r1]

	push {r1}
	ldr r0,=32
	bl putchar
	ldr r0,=8
	bl putchar
	pop {r1}
	b loopzor
	
_notbackspace:	
	strb r0,[r1]
	add r1,#1
	
	b loopzor

endloopzor:
	// dump junk received after the newline
_fsl:
	push {r1}
//	bl getchar_timeout_us
//	cmp r0, #0
	//	bge _fsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	bl flushinput

	pop {r1}
	
	ldr r0,=0
	strb r0,[r1]

	ldr r0,=buffer
	sub r1,r0
	ldr r0,=inputlen
	str r1,[r0]
	
	ldr r0,='\n'
	bl putchar

	
	// and return to whoever called us
_tpret:
	pop {pc}

flushserial:
	push {lr}  // push FSL
	ldr r0,=0
_ofsl:	
//	bl getchar_timeout_us
//	cmp r0, #0
	//	bge _ofsl  // if we get a timeout due to no readable character, we get -1 returned. Continue until this happens
	bl flushinput
	pop {pc}  // pop FSL

	

	// there is a bug in this word - for example, if one do
	// WORD CR FIND, it returns "WORD"
	HEADER "WORD",4,0,WORD
	// read from input buffer until space, enter, or zero is found.
	bl newwordhelper
	// the bug is because
	// subsequent use of other words will overwrite this buffer
	// hence, we need to copy it to another buffer - wordbuf2
	
	KPOP
	push {r0} // save word length for later
	KPOP
	ldr r1,=wordbuf2
	ldr r2,=0
_wcopyloop:
	ldrb r3,[r0,r2]
	strb r3,[r1,r2]
	add r2,#1
	cmp r3,#0
	bne _wcopyloop
	
	mov r0,r1
	KPUSH
	pop {r0}
	KPUSH
	DONE


newwordhelper:
	push {lr}
	
	// start by discarding everything that is a newline, carriage return, space

_nww_l1:	
	bl mygetchar		
//	bl putchar // echo
	// get rid of leftovers from last word
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
	bl mygetchar		
//	bl putchar // echo
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
//	ldr r0,='\n'
//	bl putchar
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


	// return the next character from the input buffer ("buffer"), and increase the pointer
	// if the character in the buffer is 0, read a new line from stdin
	// yet another thing that should be possible to write in forth
	
mygetchar:
	push {r1,r2,r3,r4,lr}

_mgc_top:
	// Check if a file source is active on the input source stack.
	ldr r1,=input_source_sp
	ldr r1,[r1]
	cmp r1,#0
	beq _mgc_nosource	// stack empty → use original inputptr/UART path

	// Compute pointer to top entry: &input_source_stack[(sp-1)*8]
	sub r1,#1
	lsl r1,#3		// * 8 bytes per entry
	ldr r2,=input_source_stack
	add r2,r1		// r2 = &top entry
	ldr r4,[r2,#4]		// r4 = vfs_fd

	// vfs_read(fd, &ch_buf, 1) — allocate 1 byte on ARM stack
	sub sp,#4
	mov r0,r4		// r0 = fd
	mov r1,sp		// r1 = &buf
	mov r2,#1		// r2 = 1 byte
	bl vfs_read		// r0 = bytes read (1) or 0=EOF or -1=error

	cmp r0,#1
	bne _mgc_file_eof

	ldrb r0,[sp]		// r0 = character read
	add sp,#4
	pop {r1,r2,r3,r4,pc}

_mgc_file_eof:
	add sp,#4
	// Close the exhausted fd and pop the source stack.
	ldr r2,=input_source_sp
	ldr r3,[r2]
	sub r3,#1		// new depth
	lsl r1,r3,#3
	ldr r4,=input_source_stack
	add r4,r1
	ldr r0,[r4,#4]		// vfs_fd of the entry we're closing
	bl vfs_close
	ldr r2,=input_source_sp
	ldr r3,[r2]
	sub r3,#1
	str r3,[r2]		// input_source_sp--
	b _mgc_top		// retry with next source

_mgc_nosource:
	// Original logic: read from inputptr (forthdefs bootstrap or UART buffer).
	ldr r1,=inputptr
	ldr r2,[r1]		// pointer to the next character

	ldr r3,=buffer		// check if the pointer is the start of
	cmp r2,r3		// the buffer.
	bne _mgc2		// no, have ongoing input to feed from

	// buffer is empty, read a new line from the terminal
	push {r1,r2}
	bl readlinehelper
	pop {r1,r2}
_mgc2:
	ldrb r0,[r2]		// the next character

	cmp r0,#0		// if it is not zero
	bne _mgc1		// continue feeding from the buffer

	bl restartinput
	pop {r1,r2,r3,r4,pc}	// return 0 to the caller (end of current source)

_mgc1:
	add r2,#1		// advance the pointer
	str r2,[r1]

	pop {r1,r2,r3,r4,pc}	// return to the caller

restartinput:	
	push {r1,r2,lr}
	ldr r1,=inputptr	
	ldr r2,=buffer		// it is zero, set inputptr to the start
	str r2,[r1]		// of the buffer. This will force a terminal read on the next call.
	ldr r1,=0
	str r1,[r2]		// and set the buffer to zero to avoid double processing
	ldr r2,=sourceid
	str r1,[r2]		// and set sourceid to 0 indicating that we run from the input buffer
	pop {r1,r2,pc}
	
	
	
