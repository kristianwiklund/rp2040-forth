all:
	pio run

upload:
	pio run -t upload

gdb:
	gdb-multiarch .pio/build/pico/firmware.elf

serial:
	./scripts/serial.sh

picoprobe:
	./scripts/picoprobe.sh

clean:
	pio run -t clean
