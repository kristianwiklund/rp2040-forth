#include <Arduino.h>
//#include <hardware/regs/addressmap.h>
 
extern "C" void forth();
extern "C" void flushinput();
 
void setup() {

  Serial.begin(115200);
  forth();
}

void flushinput() {

}

void loop() {}
