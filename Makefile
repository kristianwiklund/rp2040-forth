all:
	pio run

upload:
	pio run -t upload

gdb:
	gdb-multiarch .pio/build/pico/firmware.elf

gdb-nucleo:
	gdb-multiarch .pio/build/f103nucleo/firmware.elf

serial:
	./scripts/serial.sh

picoprobe:
	./scripts/picoprobe.sh

stlink:
	./scripts/stlink.sh

clean:
	pio run -t clean
