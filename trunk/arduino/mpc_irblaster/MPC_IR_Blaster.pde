/*
	Media Center Remote Relay for Arduino

	This sketch accepts input from a Media Center Remote (the model tested
	is a Hauppauge remote), and then outputs IR a short time later for 
	activating other devices.

	Default config will register the BLUE and YELLOW buttons and power 
	on/off a Logitech amplifier and a Panasonic TV.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
*/

/*
	Hardware setup:

	1.	Attach a TTL IR receiver to PIN5
	2.	Attach an IR LED (or driver circuit for an IR LED) to PIN3
	3.	Put the RED pin from an RGB LED on PIN9
	4.	Put the GREEN pin from an RGB LED on PIN10
	5.	Put the BLUE pin from an RGB LED on PIN11

	All LEDs should have current limiting resistors.  A driver circuit for
	the IR LED is adviseable since the ATMEGA can't deliver a huge amount
	of power to the digital output pins.
*/

// Utilizes library from;
// http://www.arcfn.com/2009/08/multi-protocol-infrared-remote-library.html
#include <IRremote.h>

//#define DEBUG

// Values are in 50us ticks as returned by irrecv.decode() raw
#define MCE_MARK_HIGH 18
#define MCE_MARK_LOW 9
#define MCE_SPACE_HIGH 18
#define MCE_SPACE_LOW 9
#define MCE_SPECIAL_HIGH 54
#define MCE_SPECIAL_LOW 27
#define MCE_FUZZFACTOR 1

// Minimum code length for decoding
#define MCE_MINIMUMCODE 64

// The remote ID required for decode to work (first long)
#define MCE_REMOTEID 0x05000008

// Tests value X against reference Y with fuzz factor
#define MCE_TEST(x,y) ((x)-MCE_FUZZFACTOR <= (y) && (x)+MCE_FUZZFACTOR >= (y))

// Define the various pins
#define OUTPUT_PIN 3
#define RECV_PIN 5
#define RED_PIN 9
#define GREEN_PIN 10
#define BLUE_PIN 11

// How long to wait after a code before sending the response out
#define SEND_DELAY 1000

// Define a few globals required for IR decoding / encoding
IRrecv irrecv(RECV_PIN);
IRsend irsend;
decode_results results;

void setup() 
{
#ifdef DEBUG
	Serial.begin(9600);
#endif

	irrecv.blink13(1);

	irrecv.enableIRIn();
}

void loop()
{
	// Fetch a code from the IR receiver.	We only care about MCE codes.
	if (irrecv.decode(&results)) {
		
		unsigned long code = MCE_decode(&results);

		// Valid MCE code returned.	We're interested.
		if (code) {
				// MCE remotes toggle the high byte between 0x10 and 0x04 between individual keypresses.
				// This helps identify a held-down key.	We don't care much about this...
				if ((code & 0x00ffffff) == 0x000C3810) {
#ifdef DEBUG
					Serial.println("Button press: BLUE");
#endif					
					analogWrite(BLUE_PIN, 255);
					delay(SEND_DELAY);
					powerAmp();					
				} else if ((code & 0x00ffffff) == 0x000C3860) {
#ifdef DEBUG
					Serial.println("Button press: YELLOW");
#endif				 
					analogWrite(GREEN_PIN, 255);
					analogWrite(RED_PIN, 220);
					delay(SEND_DELAY);
					powerTV();
				} else if ((code & 0x00ffffff) == 0x000C3840) {
#ifdef DEBUG
					Serial.println("Button press: GREEN");					
#endif					
					analogWrite(GREEN_PIN, 255);
					delay(SEND_DELAY);
				} else if ((code & 0x00ffffff) == 0x000C3980) {
#ifdef DEBUG
					Serial.println("Button press: RED");					
#endif					
					analogWrite(RED_PIN, 255);
					delay(SEND_DELAY);
				} else {
#ifdef DEBUG					
					Serial.print("Unknown press: ");
					Serial.println(code, HEX);
#endif					
				}
		} else {
#ifdef DEBUG			
			 Serial.println("Received unknown IR code.	Ignoring."); 
#endif			 
		}

		delay(50);
 
		// re-enable the receiver
		irrecv.enableIRIn();
		
		// Shut off the RGB LED
		analogWrite(RED_PIN, 0);
		analogWrite(GREEN_PIN, 0);
		analogWrite(BLUE_PIN, 0);
	}
}

// Sends a power-on signal to the Logitech amplifier
void powerAmp()
{
	 // NEC 10EF08F7, 32 bits
	 irsend.sendNEC(0x10EF08F7, 32); 
}

// Sends a power-on signal to the Panasonic TV
void powerTV()
{
	 // Panasonic TV, output is raw (unfortunately)
	 // Much of this is probably repeated, but so what.
	 const unsigned int rawCodes[] = {
		 3550,1750,400,450,450,1300,450,450,400,450,450,450,400,450,450,450,400,450,450,450,400,450,400,500,400,450,400,500,400,1300,450,450,400,450,450,450,400,450,400,500,400,450,400,500,400,450,400,500,400,1300,450,450,400,450,450,450,400,450,450,450,400,450,400,500,400,450,400,1350,400,500,400,1300,450,1300,450,1300,400,1350,400,500,400,450,400,1350,400,450,450,1300,450,1300,450,1300,400,1350,400,500,400,1300,450
	 };
	 irsend.sendRaw((unsigned int *)rawCodes, sizeof(rawCodes)/sizeof(int), 38);
}

// Decodes an MCE infrared code and returns the command
// Returns 0 if there's some issue
unsigned long MCE_decode(decode_results *res)
{
	// Length has to be appropriate.
	if (res->rawlen < MCE_MINIMUMCODE) {
		return 0;
	}

	// Now check that the correct markers are in the buffer
	if (MCE_TEST(res->rawbuf[1],MCE_SPECIAL_HIGH) && MCE_TEST(res->rawbuf[2],MCE_SPACE_HIGH) && MCE_TEST(res->rawbuf[11],MCE_SPECIAL_LOW) && MCE_TEST(res->rawbuf[12],MCE_SPACE_HIGH)) {
		// Assemble the remote's ID
		unsigned long remoteID = MCE_getLong(res,13);
		remoteID >>= 8;
		remoteID |= ((unsigned long)MCE_getByte(res,3)) << 24;

		// Validate that the device ID matches
		if (remoteID == MCE_REMOTEID) {
			// Return the command code
			return MCE_getLong(res,37);
		} else {
			return 0;
		}		
	}
	
	return 0;
}

// Fetches a long out of an MCE infrared code
unsigned long MCE_getLong(decode_results *res,int offset)
{
	unsigned long output = 0;

	output |= (unsigned long)MCE_getByte(res,offset);
	output <<= 8;	
	output |= (unsigned long)MCE_getByte(res,offset+8);
	output <<= 8;	
	output |= (unsigned long)MCE_getByte(res,offset+16);
	output <<= 8;	
	output |= (unsigned long)MCE_getByte(res,offset+24);

	return output;
}

// Fetches a byte of data out of an MCE infrared code
unsigned char MCE_getByte(decode_results *res,int offset)
{
	unsigned char output = 0;

	// Assemble a byte from the decode results
	for(int i = 0; i < 8; i++) {
		unsigned int val = 0;
		if (i+offset < res->rawlen) {
			val = res->rawbuf[i+offset];
		}
		output <<= 1;
		if (i & 1) {
			// space
			output |= MCE_TEST(val,MCE_SPACE_HIGH);
		} else {
			// mark
			output |= MCE_TEST(val,MCE_MARK_HIGH);
		}
	}

	// Return the byte
	return output;	
}
