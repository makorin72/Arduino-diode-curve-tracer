#include <EEPROM.h>
#include <LiquidCrystal.h>

#define  SUCCESS              0
#define  VOLTAGE_OVER_RANGE   1
#define  VOLTAGE_LIMIT        2
#define  OVER_PC_MAX          3

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

/* *** ADC read *** */
int voltDacOut      = 0;
int voltDutNegative = 0;
int voltDutCurrent  = 0;

/* *** serial receive *** */
int inByte = 0;         // incoming serial byte
int setValue = 0;

const int adcStep = 1024;
const int dacStep =  256;
const float vcc  = 4.95;
const float vRef = vcc;          // ADC vref = default
const float maxCurrent = 30e-3;  // 30[mA] at DAC=255
const float minVce     = 0.3;     // 2SC1815 Vce(sat)=<0.25[V]
const float maxPc      = 200.0;  // 2SC1815 Pc_max=400[mW]
float ratio = 0;
float rc = 0;

int maxDutVoltage = 5.0;

void setup() {
//  analogReference( INTERNAL );
  Serial.begin(9600);
  lcd.begin(16, 2);

  pinMode(pinReset, OUTPUT); // nReset
  pinMode(pinClock, OUTPUT); // clock
  pinMode(pinData, OUTPUT);  // data
  pinMode(pinOE, OUTPUT); // nOE
  pinMode(pinLE, OUTPUT); // LE
  
  dacReset();
  dacLoadToLatch();
  digitalWrite(pinOE, LOW);
  
  lcd.setCursor(0, 0);
  lcd.print("ready.");
  
//  currentCalibration();

  // read from eeprom
  ratio = EEPROM_readDouble(0);  // 0x00 - 0x03
  rc    = EEPROM_readDouble(4);  // 0x04 - 0x07
}

void loop() {
  if(Serial.available() > 0) {
    inByte = Serial.read();
    if('0' <= inByte && inByte <= '9'){
      int num = inByte - '0';
      setValue = setValue * 10 + num;
    }else if(inByte == 's'){  // sweep
      Serial.println("sweep");
      Serial.println(setValue/1000, DEC);
      sweep(setValue/1000);  
      setValue = 0;
    }else if(inByte == 't'){  // single
      Serial.println("single");
//      Serial.println(setCurrent/1000, DEC);
      Serial.println(setValue, DEC);
      singleMeasure( setValue );
      getADC();     
      printRecord();
      setValue = 0;
    }else if(inByte == '\n'){
            
    }else{    }
    
    
    
  }
  
} // loop

  /*
  if (Serial.available() > 0) {
    // get incoming byte:
    inByte = Serial.read();
    if( '0' <= inByte && inByte <= '9' ){
      int num = inByte - '0';
      dacValue = dacValue * 10 + num;
    }else if( inByte == 's' ){
      Serial.println("s");
      sweep(dacValue);
    }else if( inByte == 't' ){
      if( 0 <= dacValue && dacValue <= 255 ){
        switch( singleMeasure(dacValue) ){
          case VOLTAGE_OVER_RANGE:
          Serial.println("VOLTAGE_OVER_RANGE");
          break;

          case VOLTAGE_LIMIT:
          Serial.println("VOLTAGE_LIMIT");
          break;

          case OVER_PC_MAX:
          Serial.println("OVER_PC_MAX");
          break;

          case SUCCESS: ;
          default: ;
        }
        Serial.print("cnt: ");
        Serial.println(dacValue, DEC);
        printRecord();
        dacValue = 0;
      }
    }
  }
  delay(100);
}
*/

void sweep( float maMax ){
  for(int i=0; i<255; i++){
    singleMeasure(i++);
    getADC();
    Serial.print(getDutVoltage(), DEC);
    Serial.print(", ");
    Serial.println(getDutCurrent()*1000, DEC);
    if( maMax <= getDutCurrent()*1000 ){ break; }
  }
  dacReset();
  dacLoadToLatch();
  Serial.print("done.");
}

void printRecord(){  
  Serial.print("dac: ");
  Serial.println(voltDacOut, DEC);
  Serial.print("v  : ");
  Serial.println(getDutVoltage(), DEC);
  Serial.print("i  : ");
  Serial.println(getDutCurrent()*1000, DEC);
  Serial.print("vce: ");
  Serial.println(getVce(), DEC);
  Serial.print("pc : ");
  Serial.println(getPc()*1000, DEC);      
  Serial.println("---");      
}

int currentToDacValue(float c){
  return c/1000 * rc / ratio / vRef * dacStep;
}

float getDutVoltage(){
  return vcc - adcToVoltage(voltDutNegative);  
}
float getDutCurrent(){
  return adcToVoltage(voltDacOut) * ratio / rc;
}
float getVce(){
  return adcToVoltage(voltDutNegative - voltDutCurrent);
}
float getPc(){
  return adcToVoltage(voltDutCurrent) / rc * getVce();  
}
float adcToVoltage(int value){
  return value * vRef / 1024.0;  
}

int singleMeasure( int dacValue ){
  dacSetValue( dacValue );
  dacLoadToLatch();
  
  getADC();

  if(maxPc < getPc()*1000){
    digitalWrite(pinOE, HIGH);
    dacReset();
    dacLoadToLatch();
    digitalWrite(pinOE, LOW);
    return OVER_PC_MAX;
  }
  if(maxDutVoltage < getDutVoltage()){
    digitalWrite(pinOE, HIGH);
    dacReset();
    dacLoadToLatch();
    digitalWrite(pinOE, LOW);
    return VOLTAGE_LIMIT;
  }
  if(getVce() < minVce){
    return VOLTAGE_OVER_RANGE;
  }
  return SUCCESS;
}

void getADC(){
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

void currentCalibration(){
  
  dacSetValue( 255 );
  dacLoadToLatch();
  
//  delay(10000);
  // wait here for push button
  
  unsigned long sumDutCurrent = 0;
  unsigned long sumDacOut = 0;
  int avgTimes = 200;
  
  for(int i=0; i < avgTimes; i++){
    getADC();
    sumDutCurrent += voltDutCurrent;
    sumDacOut += voltDacOut;
  }
  dacSetValue( 0 );
  dacLoadToLatch();
  
  float voltDutCurrent = sumDutCurrent / avgTimes;
  float a = (float)sumDutCurrent / sumDacOut;
  float r = (float)voltDutCurrent * vRef / 1024.0 / maxCurrent;
//  float r1= (float)voltDacOut * vRef / 1024.0 * a / maxCurrent;
//  Serial.println(a, DEC);
//  Serial.println(r, DEC);
//  Serial.println(r1, DEC);

  // write to eeprom
  EEPROM_writeDouble(0, a);
  EEPROM_writeDouble(4, r);
}

void EEPROM_writeDouble(int ee, double value)
{
    byte* p = (byte*)(void*)&value;
    for (int i = 0; i < sizeof(value); i++)
	  EEPROM.write(ee++, *p++);
}

double EEPROM_readDouble(int ee)
{
    double value = 0.0;
    byte* p = (byte*)(void*)&value;
    for (int i = 0; i < sizeof(value); i++)
	  *p++ = EEPROM.read(ee++);
    return value;
} 

