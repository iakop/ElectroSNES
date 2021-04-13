#include <CollarTransmitter.h>
#include <LiquidCrystal.h>

#define RS 3
#define E 4
#define D4 5
#define D5 6
#define D6 7 
#define D7 8
#define OUTPUT_PIN       11

CollarTransmitter transmitter(0x6490);
LiquidCrystal lcd(RS, E, D4, D5, D6, D7);

String cmd;
String prompt = "Awaiting cmd...";
const String startStr = "cmd:";

unsigned long long millisTimer = 0;

void setup() {
  transmitter.attach(OUTPUT_PIN);
  
  lcd.begin(16, 2);
  lcd.setCursor(0 /*x*/ , 0 /*y*/); 
  lcd.print(prompt);
  Serial.begin(115200);
}

void loop() {
  while (Serial.available() > 0) {
    //Read in Serial input:
    cmd = Serial.readStringUntil(';');

    //Locate start, to remove any junk
    uint8_t startIdx = cmd.indexOf(startStr);
    if (startIdx == -1){
      continue;
    }
    //Locate args:
    uint8_t sepIdx[2];
    sepIdx[0] = cmd.indexOf(':', startIdx+startStr.length());
    sepIdx[1] = cmd.indexOf(':', sepIdx[0]+1);
    
    //Extract the mode, power and duration:
    String cmdMode = cmd.substring(startIdx+startStr.length(), sepIdx[0]);
    String cmdPower = cmd.substring(sepIdx[0]+1, sepIdx[1]);
    String cmdDuration = cmd.substring(sepIdx[1]+1);
    uint8_t mode = cmdMode.toInt();
    uint8_t power = cmdPower.toInt();
    uint16_t duration = cmdDuration.toInt();

    //Print parameters:
    lcd.clear();
    lcd.setCursor(0 /*x*/ , 0 /*y*/);
    lcd.print("Mod: "); lcd.print(mode);  lcd.print(" Pwr: "); lcd.print(power);
    lcd.setCursor(0 /*x*/ , 1 /*y*/);
    lcd.print("Dur: "); lcd.print(duration);

    //Start millis timer:
    millisTimer = millis();

    //Execute command:
    while(millis() < millisTimer + duration){
      transmitter.blockingSend(1, mode, power);
      delay(20);
    }

    //Reprint prompt:
    lcd.clear();
    lcd.setCursor(0 /*x*/ , 0 /*y*/); 
    lcd.print(prompt);
  }
}
