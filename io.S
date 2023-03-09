	#ifdef NUCLEO_F103

	.global stdio_init_all, getchar_timeout_us, getchar
	.global putchar, _putchar

	// set up the UART
stdio_init_all:
	push {lr}

	
	
	pop {pc}

getchar_timeout_us:
	push {lr}
	pop {pc}

getchar:
	push {lr}
	pop {pc}

_putchar:	
putchar:
	push {lr	}
	pop {pc}
	
	#endif
