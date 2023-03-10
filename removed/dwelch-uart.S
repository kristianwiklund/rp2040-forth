	// original C code (C) Devid Welch https://github.com/dwelch67
	// MIT License - see attached subrepo for links and details, also https://github.com/dwelch67/raspberrypi-pico
	//	MIT License

	//Copyright (c) 2021 David Welch

	//Permission is hereby granted, free of charge, to any person obtaining a copy
	//of this software and associated documentation files (the "Software"), to deal
	//in the Software without restriction, including without limitation the rights
	//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	//copies of the Software, and to permit persons to whom the Software is
	//furnished to do so, subject to the following conditions:

	//The above copyright notice and this permission notice shall be included in all
	//copies or substantial portions of the Software.

	//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	//SOFTWARE.

	// transformation to assembler by Kristian Wiklund - MIT license. 
	// (trivial changes - PUT32 and GET32 functions are replaced with assembler macros + a couple of
	// loop transformations - the rest is the same
	
	.thumb_func

	.macro PUT32 a,b
	push {r6,r7}
	ldr r6,=\a
	ldr r7,=\b
	str r7,[r6]
	pop {r6,r7}
	.endm

	.macro PUT32r0 a
	push {r6}
	ldr r6,=\a
	str r0,[r6]
	pop {r6}
	.endm
	
	.macro GET32 a
	ldr r0,=\a
	ldr r0,[r0]
	.endm
	
#define RESETS_BASE                 0x4000C000

#define RESETS_RESET_RW        (RESETS_BASE+0x0+0x0000)
#define RESETS_RESET_XOR       (RESETS_BASE+0x0+0x1000)
#define RESETS_RESET_SET       (RESETS_BASE+0x0+0x2000)
#define RESETS_RESET_CLR       (RESETS_BASE+0x0+0x3000)

#define RESETS_WDSEL_RW        (RESETS_BASE+0x4+0x0000)
#define RESETS_WDSEL_XOR       (RESETS_BASE+0x4+0x1000)
#define RESETS_WDSEL_SET       (RESETS_BASE+0x4+0x2000)
#define RESETS_WDSEL_CLR       (RESETS_BASE+0x4+0x3000)

#define RESETS_RESET_DONE_RW   (RESETS_BASE+0x8+0x0000)
#define RESETS_RESET_DONE_XOR  (RESETS_BASE+0x8+0x1000)
#define RESETS_RESET_DONE_SET  (RESETS_BASE+0x8+0x2000)
#define RESETS_RESET_DONE_CLR  (RESETS_BASE+0x8+0x3000)

#define SIO_BASE                    0xD0000000

#define SIO_GPIO_OUT_RW             (SIO_BASE+0x10)
#define SIO_GPIO_OUT_SET            (SIO_BASE+0x14)

#define SIO_GPIO_OUT_CLR            (SIO_BASE+0x18)
#define SIO_GPIO_OUT_XOR            (SIO_BASE+0x1C)

#define SIO_GPIO_OE_RW              (SIO_BASE+0x20)
#define SIO_GPIO_OE_SET             (SIO_BASE+0x24)
#define SIO_GPIO_OE_CLR             (SIO_BASE+0x28)
#define SIO_GPIO_OE_XOR             (SIO_BASE+0x2C)

#define IO_BANK0_BASE               0x40014000

#define IO_BANK0_GPIO0_CTRL_RW      (IO_BANK0_BASE+0x004+0x0000)
#define IO_BANK0_GPIO0_CTRL_XOR     (IO_BANK0_BASE+0x004+0x1000)
#define IO_BANK0_GPIO0_CTRL_SET     (IO_BANK0_BASE+0x004+0x2000)
#define IO_BANK0_GPIO0_CTRL_CLR     (IO_BANK0_BASE+0x004+0x3000)

#define IO_BANK0_GPIO1_CTRL_RW      (IO_BANK0_BASE+0x00C+0x0000)
#define IO_BANK0_GPIO1_CTRL_XOR     (IO_BANK0_BASE+0x00C+0x1000)
#define IO_BANK0_GPIO1_CTRL_SET     (IO_BANK0_BASE+0x00C+0x2000)
#define IO_BANK0_GPIO1_CTRL_CLR     (IO_BANK0_BASE+0x00C+0x3000)

#define IO_BANK0_GPIO25_STATUS_RW   (IO_BANK0_BASE+0x0C8+0x0000)
#define IO_BANK0_GPIO25_STATUS_XOR  (IO_BANK0_BASE+0x0C8+0x1000)
#define IO_BANK0_GPIO25_STATUS_SET  (IO_BANK0_BASE+0x0C8+0x2000)
#define IO_BANK0_GPIO25_STATUS_CLR  (IO_BANK0_BASE+0x0C8+0x3000)

#define IO_BANK0_GPIO25_CTRL_RW     (IO_BANK0_BASE+0x0CC+0x0000)
#define IO_BANK0_GPIO25_CTRL_XOR    (IO_BANK0_BASE+0x0CC+0x1000)
#define IO_BANK0_GPIO25_CTRL_SET    (IO_BANK0_BASE+0x0CC+0x2000)
#define IO_BANK0_GPIO25_CTRL_CLR    (IO_BANK0_BASE+0x0CC+0x3000)

#define CLOCKS_BASE                 0x40008000

#define CLK_REF_CTRL_RW             (CLOCKS_BASE+0x30+0x0000)
#define CLK_REF_CTRL_XOR            (CLOCKS_BASE+0x30+0x1000)
#define CLK_REF_CTRL_SET            (CLOCKS_BASE+0x30+0x2000)
#define CLK_REF_CTRL_CLR            (CLOCKS_BASE+0x30+0x3000)

#define CLK_SYS_CTRL_RW             (CLOCKS_BASE+0x3C+0x0000)
#define CLK_SYS_CTRL_XOR            (CLOCKS_BASE+0x3C+0x1000)
#define CLK_SYS_CTRL_SET            (CLOCKS_BASE+0x3C+0x2000)
#define CLK_SYS_CTRL_CLR            (CLOCKS_BASE+0x3C+0x3000)

#define CLK_PERI_CTRL_RW            (CLOCKS_BASE+0x48+0x0000)
#define CLK_PERI_CTRL_XOR           (CLOCKS_BASE+0x48+0x1000)
#define CLK_PERI_CTRL_SET           (CLOCKS_BASE+0x48+0x2000)
#define CLK_PERI_CTRL_CLR           (CLOCKS_BASE+0x48+0x3000)


#define CLK_SYS_RESUS_CTRL_RW       (CLOCKS_BASE+0x78+0x0000)
#define CLK_SYS_RESUS_CTRL_XOR      (CLOCKS_BASE+0x78+0x1000)
#define CLK_SYS_RESUS_CTRL_SET      (CLOCKS_BASE+0x78+0x2000)
#define CLK_SYS_RESUS_CTRL_CLR      (CLOCKS_BASE+0x78+0x3000)


#define XOSC_BASE                   0x40024000

#define XOSC_CTRL_RW                (XOSC_BASE+0x00+0x0000)
#define XOSC_CTRL_XOR               (XOSC_BASE+0x00+0x1000)
#define XOSC_CTRL_SET               (XOSC_BASE+0x00+0x2000)
#define XOSC_CTRL_CLR               (XOSC_BASE+0x00+0x3000)

#define XOSC_STATUS_RW              (XOSC_BASE+0x04+0x0000)
#define XOSC_STATUS_XOR             (XOSC_BASE+0x04+0x1000)
#define XOSC_STATUS_SET             (XOSC_BASE+0x04+0x2000)
#define XOSC_STATUS_CLR             (XOSC_BASE+0x04+0x3000)

#define XOSC_STARTUP_RW             (XOSC_BASE+0x0C+0x0000)
#define XOSC_STARTUP_XOR            (XOSC_BASE+0x0C+0x1000)
#define XOSC_STARTUP_SET            (XOSC_BASE+0x0C+0x2000)
#define XOSC_STARTUP_CLR            (XOSC_BASE+0x0C+0x3000)

#define UART0_BASE                  0x40034000

#define UART0_BASE_UARTDR_RW        (UART0_BASE+0x000+0x0000)
#define UART0_BASE_UARTFR_RW        (UART0_BASE+0x018+0x0000)
#define UART0_BASE_UARTIBRD_RW      (UART0_BASE+0x024+0x0000)
#define UART0_BASE_UARTFBRD_RW      (UART0_BASE+0x028+0x0000)
#define UART0_BASE_UARTLCR_H_RW     (UART0_BASE+0x02C+0x0000)
#define UART0_BASE_UARTCR_RW        (UART0_BASE+0x030+0x0000)

#define STK_CSR 0xE000E010
#define STK_RVR 0xE000E014
#define STK_CVR 0xE000E018

	.global dw_uart_recv, dw_uart_send, dw_uart_init
	
	

dw_uart_recv:
	push {r1,lr}
_uarl1:
	GET32 (UART0_BASE_UARTFR_RW)
	ldr r1,=(1<<4)
	and r0,r1
	cmp r0,#0
	bne _uarl1
	GET32 UART0_BASE_UARTDR_RW

	pop {r1,pc}	
	

dw_uart_send:	
	push {r1,lr}
	push {r0}
_uasl1:
	GET32 UART0_BASE_UARTFR_RW
	ldr r1,=(1<<5)
	and r0,r1
	cmp r0,#0
	bne _uasl1

	pop {r0}
	PUT32r0 UART0_BASE_UARTDR_RW
	
	pop {r1,pc}	

	//static void uart_flush ( void )
uart_flush:	
	push {lr}
//{
    //while(1)
    //{
        //if((GET32(UART0_BASE_UARTFR_RW)&(1<<7))!=0) break;
    //}
	//}
	pop {pc}
	
clock_init:	
	push {lr}
	PUT32 CLK_SYS_RESUS_CTRL_RW,0 
	//PUT32 CLK_REF_CTRL_RW,0 
	//PUT32 CLK_SYS_CTRL_RW,0 
	PUT32 XOSC_CTRL_RW,0xAA0       //1 - 15MHZ
	PUT32 XOSC_STARTUP_RW,47       //straight from the datasheet
	PUT32 XOSC_CTRL_SET,0xFAB000   //enable
	//    while(1)
	//    {
	//        if((GET32(XOSC_STATUS_RW)&0x80000000)!=0) break;
	//    }
	PUT32 CLK_REF_CTRL_RW,2  //XOSC
	PUT32 CLK_SYS_CTRL_RW,0  //reset/clk_ref
	//	}
	pop {pc}

dw_uart_init:
	push {lr}
	bl clock_init

	PUT32 CLK_PERI_CTRL_RW,(1<<11)|(4<<5) 

	PUT32 RESETS_RESET_CLR,(1<<5)  //IO_BANK0
	//while(1)
	//{
        //if((GET32(RESETS_RESET_DONE_RW)&(1<<5))!=0) break;
	//}
	
	PUT32 RESETS_RESET_CLR,(1<<22)  //UART0
	//while(1)
	//{
        //if((GET32(RESETS_RESET_DONE_RW)&(1<<22))!=0) break;
	//}

	//GPIO 0 UART0 TX function 2
	//GPIO 1 UART0 RX function 2

	//(12000000/(16/115200)) = 6.514
	//0.514*64 = 32.666
	PUT32 UART0_BASE_UARTIBRD_RW,6 
	PUT32 UART0_BASE_UARTFBRD_RW,33 
	//0 11 1 0 0 0 0
	//0111 0000
	PUT32 UART0_BASE_UARTLCR_H_RW,0x70 
	PUT32 UART0_BASE_UARTCR_RW,(1<<9)|(1<<8)|(1<<0) 

	PUT32 IO_BANK0_GPIO0_CTRL_RW,2   //UART
	PUT32 IO_BANK0_GPIO1_CTRL_RW,2   //UART

	//for(ra=0;ra<100;)
	//{
        //if((GET32(UART0_BASE_UARTFR_RW)&(1<<5))==0)
        //{
        //PUT32 UART0_BASE_UARTDR_RW,0x55 
        //ra++;
        //}
	//}
	
	pop {pc}

//-------------------------------------------------------------------------
//
// Copyright (c) 2021 David Welch dwelch@dwelch.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//-------------------------------------------------------------------------
