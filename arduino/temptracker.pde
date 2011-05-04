/*
	Very simple temperature tracking program.  Records temperature data
	into the EEPROM and plays it back on start.

	Code template taken from;

	http://www.oomlout.com/a/products/ardx/circ-10
*/

#include <EEPROM.h>
#include <math.h>

//TMP36 Pin Variables
int temperaturePin = 0; //the analog pin the TMP36's Vout (sense) pin is connected to
                        //the resolution is 10 mV / degree centigrade 
                        //(500 mV offset) to make negative temperatures an option

int eepromoffset = 0;  // offset to write the lowest value to the eeprom
int samplefrequency = 300;  // number of samples to take for a moving average (1 sample a second)

int EEPROM_writeFloat(int ee, float& value)
{
    const byte* p = (const byte*)(const void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
	  EEPROM.write(ee++, *p++);
    return i;
}

int EEPROM_readFloat(int ee, float& value)
{
    byte* p = (byte*)(void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
	  *p++ = EEPROM.read(ee++);
    return i;
}

/*
 * setup() - this function runs once when you turn your Arduino on
 * We initialize the serial connection with the computer
 */
void setup()
{
  pinMode(13, OUTPUT);
  Serial.begin(9600);
  
  Serial.println("Dump of EEPROM data starting...");
  
  for (int i = 0; i < (1024 / sizeof(float)); i++) {
     float val;    
     EEPROM_readFloat(i*sizeof(float), val);
     Serial.print(i);
     Serial.print(",");
     Serial.println(val);
  }
}
 
void loop()                     // run over and over again
{
 float sum = 0;
 float average;
 
 // Collect samples for one minute before calculating the moving average
 for (int i = 0; i < samplefrequency; i++) {
   float temp = getVoltage(temperaturePin);
   temp = (temp - .5) * 100;
   sum += temp;
   
   if (i % 2) {
     digitalWrite(13, HIGH);
   } else {
     digitalWrite(13, LOW);
   }
   
   delay(1000);
 }
 
 average = sum / (float)samplefrequency; 
 
 if (eepromoffset < 1024) {
   EEPROM_writeFloat(eepromoffset, average);
   //Serial.print(eepromoffset);
   //Serial.print(",");
   //Serial.println(average);
   eepromoffset += sizeof(average);
 }
}

/*
 * getVoltage() - returns the voltage on the analog input defined by
 * pin
 */
float getVoltage(int pin){
 return (analogRead(pin) * .004882814); //converting from a 0 to 1024 digital range
                                        // to 0 to 5 volts (each 1 reading equals ~ 5 millivolts
}
