	.macro DONE
	ldr r0,=done
	mov pc,r0
	.ltorg  // allow a literal pool here
	.endm

# to create the built in words

	#define FLAG_HIDDEN      0x1
	#define FLAG_IMMEDIATE   0x2
	#define FLAG_ONLYCOMPILE 0x4
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

