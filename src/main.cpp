#include <Arduino.h>
//#include <hardware/regs/addressmap.h>
 
extern "C" void forth();
extern "C" void flushinput();
extern "C" void myputchar(char);
extern "C" char cppgetchar();

void setup() {

  Serial.begin(115200);
  printf("Test message to check that printf 10 works: %d 0x%x\nYielding control to Forth system\n",10,10);
  
  forth();
}

void flushinput() {

}

char cppgetchar() {
  char x;
  if (Serial.available()>0) {
    x= Serial.read();
  }
  else
    x=0xff;

  return (x);
}

void myputchar(char c) {
  Serial.print(c);
}


void loop() {}
