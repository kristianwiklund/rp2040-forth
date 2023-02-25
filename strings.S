	.global errormsg, compilemsg, runmsg, notimmediatemsg, immediatemsg
	.global compiling, hellogoodmorning, donemsg, numberstring
	.global debugstring,worddescstring,debugnumber,codedebugstring,forthwordstring
	.global debugwordmsg, hexnumber, hexdebug, finddebugstring, findlendebugstring
	###
	##	strings

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

