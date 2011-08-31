
 
#include <LiquidCrystal.h>

/* *** pin out *** */
const int pinReset = 2;
const int pinData  = 3;
const int pinClock = 4;

const int pinOE = 5;
const int pinLE = 6;

const int apinDacOut      = A2;
const int apinDutNegative = A1;
const int apinDutCurrent  = A0;

//         ( RS, Enable, D4, D5, D6, D7 ) ,R/W=Gnd
LiquidCrystal lcd( 9, 8, 13, 12, 11, 10 );

/* *** serial receive *** */
int inByte = 0;         // incoming serial byte
int buf[10];

/* *** ADC read *** */
int voltDacOut      = 0;
int voltDutNegative = 0;
int voltDutCurrent  = 0;

int dacValue = 0;

void setup() {
//  analogReference( INTERNAL );
  Serial.begin(9600);
  lcd.begin(16, 2);

  pinMode(pinReset, OUTPUT); // nReset
  pinMode(pinClock, OUTPUT); // clock
  pinMode(pinData, OUTPUT); // data
  pinMode(pinOE, OUTPUT); // nOE
  pinMode(pinLE, OUTPUT); // LE
  
  dacReset();
  dacLoadToLatch();
  digitalWrite(pinOE, LOW);
  
  lcd.setCursor(0, 0);
  lcd.print("ready.");
}

void loop() {

  if (Serial.available() > 0) {
  // get incoming byte:
    inByte = Serial.read();
    if( '0' <= inByte && inByte <= '9' ){
      int num = inByte - '0';
      dacValue = dacValue * 10 + num;
    }else if( inByte == '\n' ){
      if( 0 <= dacValue && dacValue <= 255 ){
        dacSetValue( dacValue );
        dacLoadToLatch();
        
        measure();
        
        Serial.print(dacValue, DEC);
        Serial.print(" ");
        Serial.print(voltDacOut, DEC);
        Serial.print(" ");
        Serial.print(voltDutNegative, DEC);
        Serial.print(" ");
        Serial.print(voltDutCurrent, DEC);
        Serial.println();
      }
 
      dacValue = 0;
    }
  }
  
  measure();

/*  
  lcd.setCursor(0, 0);
  lcd.print(dacValue, DEC);
  lcd.print(" ");
  lcd.print(voltDacOut, DEC);
  lcd.print(" ");
  lcd.print(voltDutNegative, DEC);
  lcd.print(" ");
  lcd.print(voltDutCurrent, DEC);
*/  
  delay(100);

}

void sweep( float maMax ){
  
}

void measure( void ){
  voltDacOut      = analogRead(apinDacOut);
  voltDutNegative = analogRead(apinDutNegative);
  voltDutCurrent  = analogRead(apinDutCurrent);
}

void dacSetValue( int value ){
  const int numOfBit = 8;
  for(int  pos = 0; pos < numOfBit; pos++ ) {
    digitalWrite( pinData, ((1<<pos & value)==0)?LOW:HIGH );
    dacClockPulse();
  }
}

void dacClockPulse( void ){
  digitalWrite(pinClock, HIGH);
  digitalWrite(pinClock, LOW);
}

void dacReset( void ){
  digitalWrite(pinReset, LOW);
  digitalWrite(pinReset, HIGH);
}

void dacLoadToLatch( void ){
  digitalWrite(pinLE, HIGH);
  digitalWrite(pinLE, LOW);
}
//    digitalWrite( pinData, (i==0)?HIGH:LOW );
void calibration(){

  
}
