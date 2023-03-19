openocd -f interface/jlink.cfg -c "transport select swd"  -f target/stm32f1x.cfg "$@"
