	.thumb_func
	.global main

main:
	mov r7, #0
	bl stdio_init_all

	# set vommen to something
	ldr r0,=vommen
	ldr r1,=list
	str r1,[r0]
test:
	# load the address pointed to by vommen, then update vommen
	ldr r0, =vommen
	ldr r1,[r0]
	mov r2,r1
	beq loop
	add r1,#4
	str r1,[r0]
	ldr r1,[r2]
	mov pc,r1
loop:
	b loop
	
tick:
	ldr r0, =hello
	bl printf
	b test

	.data
	.align 4
hello:
	.asciz "."

	.align 4
vommen:
	.word 0

	.align 4		
list:
	.word tick
	.word tick
	.word tick
	.word 0
