// ascii definitions of forth words that run on startup
// final word must end with 0 (hence asciz)
// intermediate must have a space at the end to get the parser working

// math
.ascii ": / /MOD SWAP DROP ; "
.ascii ": MOD /MOD DROP  ; "

// stack manipulation
.ascii ": OVER SWAP DUP ROT SWAP ; "

// conditionals
.ascii ": BEGIN HERE ; IMMEDIATE "

// output
.ascii ": CR 10 EMIT ; "
.ascii ": SPACE 32 EMIT ; "

// test word
.asciz ": A 10 BEGIN DUP . 1 - DUP 0 < UNTIL ;"




// replaced words from "before parsing implemented":
	// moved to forthdefs.h
	//FHEADER "/",1,0,SLASH
	//.word DIVMOD, SWAP, DROP, 0
	//FHEADER "MOD",3,0,MOD	
	//.word DIVMOD, DROP, 0

//	FHEADER "CR",2,0,CR
//	.word LIT,10,EMIT,0

//	FHEADER "SPACE",5,0,SPACE
//	.word LIT,32,EMIT,0



//FHEADER "OVER",4,0,OVER
//	.word SWAP, DUP, ROT, SWAP
//	.int END

//	FHEADER "BEGIN",5,FLAG_IMMEDIATE|FLAG_ONLYCOMPILE,BEGIN
//	.int HERE // drop return address on stack
//	.int END



