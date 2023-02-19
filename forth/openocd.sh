openocd -f interface/jlink.cfg -c "transport select swd" -c "adapter speed 1000" -f target/rp2040.cfg "$@"
