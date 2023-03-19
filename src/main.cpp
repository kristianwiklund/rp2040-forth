#include <Arduino.h>
//#include <hardware/regs/addressmap.h>
 
extern "C" void forth();
extern "C" void flushinput();
 
void setup() {

  //  Serial1.begin(115200);
  printf("Test message to check that printf 10 works: %d 0x%x\nYielding control to Forth system\n",10,10);
  
  forth();
}

void flushinput() {

}

void loop() {}
