openocd -f interface/stlink.cfg -c "transport select hla_swd;" -f target/stm32f1x.cfg "$@"
