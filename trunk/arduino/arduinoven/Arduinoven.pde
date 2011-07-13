/* Arduinoven - Arduino-based Reflow Oven Controller
 * http://zencoding.blogspot.com
 *
 * All code written and (c) James Young, 2011
 *
 * These files are licensed under the Creative Commons Attribution-ShareAlike 2.5 License;
 * http://creativecommons.org/licenses/by-sa/2.5/
 */

// ***************************************************************
/* User configurable options begin here */

#define DEBUG
 
// Temperature sensor selection.  Only select _one_ of these.
//#define TEMP_AD595         // AD595 thermocouple amplifier
#define TEMP_FAKE          // Fake temperature sensor for testing

// Attached LCD.  Again, only select one of these (or none!)
//#define TWI_LCD            // DFRobot TWI LCD (16x2)

// Various other peripherals.  Uncomment if they are attached.
//#define PIEZO_SPEAKER        // 5v piezo buzzer
//#define EEPROM_LC256         // I2C 256kbit EEPROM
 
#define TEMP_PIN 3         // Pin that the thermocouple amplifier is on
#define RELAY_PIN 8        // Pin that the relay is triggered on
#define RELAY_LED 13       // Pin that the relay display LED is on
#define PIEZO_PIN 9        // Pin that the piezo buzzer is installed on

#define SERIAL_BAUD 19200   // Default baud rate for the serial link

#define AREF_VOLTAGE 5.0    // Voltage measured on Aref

#define DEFAULT_PID_P  1.0
#define DEFAULT_PID_I  0.0
#define DEFAULT_PID_D  0.0
 
/* User configurable options end */
// ***************************************************************

// ***************************************************************
// Macro configuration and includes begin here

 #if (defined(TEMP_AD595) && defined(TEMP_FAKE))
   #undef TEMP_FAKE
 #endif

#if (defined(TWI_LCD) || defined(EEPROM_LC256))
  #define I2C_NEEDED
#endif

#ifdef I2C_NEEDED
  #include <Wire.h>
#endif

#ifdef TWI_LCD
  #include <LiquidCrystal_I2C.h>
#endif

#include <EEPROM.h>

#define GET_NVR_OFFSET(param) ((int)&(((t_NVR_Data*) 0)->param))
#define readFloat(addr) nvrReadFloat(GET_NVR_OFFSET(addr))
#define writeFloat(value, addr) nvrWriteFloat(value, GET_NVR_OFFSET(addr))
#define readInt(addr) nvrReadInt(GET_NVR_OFFSET(addr))
#define writeInt(value, addr) nvrWriteInt(value, GET_NVR_OFFSET(addr))

// ***************************************************************
// Function prototypes and state variables begin here
float readTempSensor();
void configureTimer();
void setRelay(boolean flag);
float nvrReadFloat(int address);
void nvrWriteFloat(float value, int address);
int nvrReadInt(int address);
void nvrWriteInt(int value, int address);

#ifdef DEBUG
  void writeState(void);
#endif

// State variables
unsigned long currentTimeTicks;  // milliseconds since startup
boolean relayState;              // state of heater relay
const unsigned int tcnt2 = 131;  // Timer2 reload value for 1ms

#ifdef TEMP_FAKE
float fakeTemperature;
unsigned long fakeTemplastStatusChange;
#endif

// EEPROM settings structure
// If you add stuff here, go and change initializeEEPROM immediately!
#define EEPROM_VERSION 5  // Values not equal to this get reset
typedef struct {
  int eeprom_version;
  float p;  // Proportional gain
  float i;  // Integral gain
  float d;  // Differential gain
} t_NVR_Data;

// ***************************************************************

// BEGIN FUNCTION setup()
void setup() {
  Serial.begin(SERIAL_BAUD);
  
  // Configure I/O pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(RELAY_LED, OUTPUT);
  pinMode(PIEZO_PIN, OUTPUT);

  #ifdef TEMP_FAKE
    // Initialize the fake temperature sensor (if installed)  
    fakeTemperature = 12.0;
    fakeTemplastStatusChange = 0;
  #endif
  
  // Check the EEPROM status and initialize if required
  initializeEEPROM();
  
  // Configure the timer to run every 1ms
  configureTimer();
}
// END FUNCTION setup()

// BEGIN FUNCTION loop()
void loop() {
  unsigned long time = currentTimeTicks;
  float temp = readTempSensor();
  if (temp < 100.0) {
      relayState = HIGH;
  } else {
      relayState = LOW;
  };

  // write out the state of the controller
  #ifdef DEBUG
    writeState();
  #endif
  
  // make this loop take 500ms
  delay(time+500-currentTimeTicks);
}
// END FUNCTION loop()

// BEGIN FUNCTION initializeEEPROM()
void initializeEEPROM() {
  
  // Check if the EEPROM version matches the version of this code.  If not, erase it.
  if (readInt(eeprom_version) != EEPROM_VERSION) {
    #ifdef DEBUG
      Serial.print("Expected ver ");
      Serial.print(EEPROM_VERSION);
      Serial.print(", got ver ");
      Serial.print(readInt(eeprom_version));
      Serial.println(".  Initializing EEPROM...");
    #endif
      
    // Initialize the EEPROM to defaults
    writeInt(EEPROM_VERSION, eeprom_version);
    writeFloat(DEFAULT_PID_P, p);
    writeFloat(DEFAULT_PID_I, i);
    writeFloat(DEFAULT_PID_D, d);
  } else {
    #ifdef DEBUG
      Serial.print("EEPROM version matches. (p,i,d) = (");
      Serial.print(readFloat(p));
      Serial.print(", ");
      Serial.print(readFloat(i));
      Serial.print(", ");
      Serial.print(readFloat(d));
      Serial.println(")");
    #endif
  }
}
// END FUNCTION initializeEEPROM()

// BEGIN FUNCTION writeState()
#ifdef DEBUG
void writeState() {
  Serial.print("temp = ");
  Serial.print(readTempSensor());
  Serial.print(" time = ");  
  Serial.print(currentTimeTicks);
  Serial.print(" relay = ");
  Serial.print(relayState?1:0);
  Serial.println("");
}
#endif
// END FUNCTION writeState()

// BEGIN FUNCTION configureTimer()
// Configures TIMER2 to call an ISR every 1ms
void configureTimer() {
	// Disable the timer2 overflow interrupt during configuration
	TIMSK2 &= ~(1 << TOIE2);

	// Configure timer2 in normal mode (pure counting)
	TCCR2A &= ~((1<< WGM21)|(1<<WGM20));
	TCCR2B &= ~(1<<WGM22);

	// Select clock source as internal I/O clock
	ASSR &= ~(1<<AS2);

	// Disable Compare Match A interrupt enable (only want overflow)
	TIMSK2 &= ~(1<<OCIE2A);

	// Now configure the prescaler to CPU clock divided by 128
	TCCR2B |= (1<<CS22)  | (1<<CS20); // Set bits
	TCCR2B &= ~(1<<CS21);             // Clear bit

	/* The math behind this is:
	 * (CPU frequency) / (prescaler value) = 125000 Hz = 8us.
	 * (desired period) / 8us = 125.
	 * MAX(uint8) + 1 - 125 = 131;
	 */

	/* Finally load end enable the timer */
	TCNT2 = tcnt2;
	TIMSK2 |= (1<<TOIE2);
}

// Interrupt service routine for Timer2.  Increments the global timer
ISR(TIMER2_OVF_vect) {
  /* Reload the timer */
  TCNT2 = tcnt2;

  currentTimeTicks++;
}
// END FUNCTION configureTimer()

// BEGIN FUNCTION readTempSensor()
#ifdef TEMP_AD595
// Extremely simple temperature reader for the AD595.
// Just read the temperature and process it.
// Value returned is in degrees C.
float readTempSensor() {
  float raw = analogRead(TEMP_PIN);
  return (raw/1024.0*AREF_VOLTAGE*100);
}
#endif

#ifdef TEMP_FAKE
// Fake temp sensor.  Fakes up an oven with the following;
// 1.  Temp increases at 5 deg/sec when relay is on
// 2.  Temp decreases at 2 deg/sec when off
// 3.  Temp starts at 15 degrees, caps at 300
float readTempSensor() {
  float time = (currentTimeTicks - fakeTemplastStatusChange)/1000.0;
  if ((fakeTemperature <= 15.0) && !relayState) {
      // temp too low and relay is off
      fakeTemperature = 15.0;
  } else if ((fakeTemperature >= 300) && relayState) {
      // temp too high and relay is on
      fakeTemperature = 300.0;
  } else if (relayState) {
      // relay is on, increase temperature
      fakeTemperature += 5.0 * time;
  } else {
      // relay is off, decrease temperature
      fakeTemperature -= 2.0 * time;
  }
      
  fakeTemplastStatusChange = currentTimeTicks;
  return fakeTemperature;
}
#endif
// END FUNCTION readTempSensor()

// BEGIN FUNCTION setRelay()
void setRelay(boolean flag)
{
  relayState = flag;
  #ifndef TEMP_FAKE
    // relay does not actually activate in fake temp mode
    digitalWrite(RELAY_PIN, relayState);
  #else
    // otherwise we just "read" the sensor to reset its state
    // this allows the fake sensor to change properly
    readTempSensor();
  #endif
  
  digitalWrite(RELAY_LED, relayState);
}

// END FUNCTION setRelay()

// START FUNCTION nvrReadFloat()
// Taken from AeroQuad code, www.aeroquad.com
float nvrReadFloat(int address) {
  union floatStore {
    byte floatByte[4];
    float floatVal;
  } floatOut;

  for (int i = 0; i < 4; i++)
    floatOut.floatByte[i] = EEPROM.read(address + i);
  return floatOut.floatVal;
}
// END FUNCTION nvrReadFloat()

// START FUNCTION nvrWriteFloat()
// Taken from AeroQuad code, www.aeroquad.com
void nvrWriteFloat(float value, int address) {
  union floatStore {
    byte floatByte[4];
    float floatVal;
  } floatIn;

  floatIn.floatVal = value;
  for (int i = 0; i < 4; i++)
    EEPROM.write(address + i, floatIn.floatByte[i]);
}
// END FUNCTION nvrWriteFloat()

// START FUNCTION nvrReadInt()
int nvrReadInt(int address) {
  union intStore {
    byte intByte[2];
    int intVal;
  } intOut;

  for (int i = 0; i < 2; i++)
    intOut.intByte[i] = EEPROM.read(address + i);
  return intOut.intVal;
}
// END FUNCTION nvrReadFloat()

// START FUNCTION nvrWriteFloat()
void nvrWriteInt(int value, int address) {
  union intStore {
    byte intByte[2];
    int intVal;
  } intIn;

  intIn.intVal = value;
  for (int i = 0; i < 2; i++)
    EEPROM.write(address + i, intIn.intByte[i]);
}
// END FUNCTION nvrWriteFloat()

// END SCRIPT
