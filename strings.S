	.global errormsg, compilemsg, runmsg, notimmediatemsg, immediatedecompilemsg
	.global compiling, hellogoodmorning, donemsg, numberstring
	.global debugstring,worddescstring,debugnumber,codedebugstring,forthwordstring
	.global debugwordmsg, hexnumber, hexdebug, finddebugstring, findlendebugstring
	.global asmmsg, codemsg, argstr, forthmsg, immediatemsg, argstrstr
	###
	##	strings

asmmsg:
	.asciz "0x%x: <asm>\n"
codemsg:
	.asciz "0x%x: %s\n"
argstr:
	.asciz "      = 0x%x\n"
argstrstr:
	.asciz "      = <%s>\n"
forthmsg:
	.asciz "0x%x: <forth>\n"
immediatedecompilemsg:
	.asciz "-> (immediate)\n"


	
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

