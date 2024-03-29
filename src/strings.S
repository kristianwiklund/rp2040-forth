	.global errormsg, compilemsg, runmsg, notimmediatemsg, immediatedecompilemsg
	.global compiling, hellogoodmorning, donemsg, numberstring
	.global debugstring,worddescstring,debugnumber,codedebugstring,forthwordstring
	.global debugwordmsg, hexnumber, hexdebug, finddebugstring, findlendebugstring
	.global asmmsg, codemsg, argstr, forthmsg, immediatemsg, argstrstr
	.global callstackfullstring, callstackemptystring, stacktracestring,  stacktracenullstring, callstackmsg
	.global finderrornull, findnothingfoundmsg, charvscharmsg, searchingformsg
	.global compilingstr,badatoistring, seevarstring
	###
	##	strings

// call trace strings
	
callstackfullstring:
	.asciz "(info) Forth call stack overflow.\n"

callstackemptystring:		
	.asciz "(info) Forth call stack underflow.\n"

stacktracestring:
	.asciz "Call Trace:\n===========\nStack start: 0x%x\nStack ptr  : 0x%x\n"
stacktracenullstring:
	.asciz " 0x%x: (NULL)\n"
callstackmsg:		
	.asciz " 0x%x: (0x%x) %s\n"

// decompiler strings
	
asmmsg:
	.asciz "0x%x: <asm>\n"

argstr:
	.asciz "      = 0x%x\n"
argstrstr:
	.asciz "      = <%s>\n"
forthmsg:
	.asciz "0x%x: <forth>\n"
immediatedecompilemsg:
	.asciz "-> (immediate)\n"
codemsg:
	.asciz "0x%x: %s\n"

seevarstring:
	.asciz "<<variable>>\n"

// debugging strings	

compilingstr:
	.asciz "(c): "

searchingformsg:
	.asciz "find: searching for length %d word <%s>\n"
charvscharmsg:
	.asciz "<%c> vs <%c>\n"
debugwordmsg:
	.asciz "Token: %s\n"

hexnumber:
	.asciz "%x "
hexdebug:
	.asciz "wordptr: %x\n"

compiling:
	.asciz " <C> "
hellogoodmorning:	
	.asciz "\n\n\nWelcome!\n\n"
donemsg:
	.asciz "\nOK "
numberstring:
	.asciz "%d "
debugstring:
	.asciz "<%s>\n"
finddebugstring:
	.asciz "find: %s\n"
findlendebugstring:
	.asciz "length: %d vs %d\n"
worddescstring:	
	.asciz "<%s, flags=%x, length=%d, v=%x>\n"
debugnumber:
	.asciz "[%d]"
codedebugstring:
	.asciz "->%x\n"
forthwordstring:
	.asciz "forth word starting at %x\n"
findfoundmsg:
	.asciz "found %s\n"
findnothingfoundmsg:	
	.asciz "nothing found\n"


	// error messages

badatoistring:
	//.asciz "ATOI failed because '%s' is NaN\n"
	.asciz "<<%s>> %s ?\n"
	
finderrornull:
	.asciz "Find: NULL pointer argument. Terminating\n"

errormsg:
	.asciz "HardFault - restarted"

compilemsg:
	.asciz "Compiling %s...\n"

runmsg:
	.asciz "Running %s...\n"

notimmediatemsg:	
	.asciz "Not immediate %s...\n"

immediatemsg:	
	.asciz "Immediate %s...\n"

