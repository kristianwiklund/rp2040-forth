
ASFLAGS=-g3 -ffreestanding -DNUCLEO_F103
CFLAGS=-g3 -ffreestanding -DNUCLEO_F103 -mcpu=cortex-m3 -DPRINTF_DISABLE_SUPPORT_FLOAT -DPRINTF_DISABLE_SUPPORT_EXPONENTIAL -DPRINTF_DISABLE_SUPPORT_LONG_LONG -DPRINTF_DISABLE_SUPPORT_PTRDIFF_T
CC=arm-none-eabi-gcc
# --specs=nosys.specs adds stubs for bare metal
LDFLAGS=--specs=nosys.specs -nostartfiles -TSTM32F103RBT6.ld

forth.elf: forth.o convert.o helpers.o strings.o printf/printf.o io.o system_stm32f10x.o startup_stm32f103xb.o system_stm32f10x.o
	$(CC) $(LDFLAGS) -o forth.elf io.o forth.o convert.o helpers.o strings.o printf/printf.o startup_stm32f103xb.o system_stm32f10x.o

clean:
	find . -name "*.o" -exec rm {} \;


