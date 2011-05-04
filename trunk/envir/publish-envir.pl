#!/usr/bin/perl
#
# Processes and cooks data from an ENVI-R attached to a serial port
# Find WebSphere doco at;
# http://cpansearch.perl.org/src/NJH/WebSphere-MQTT-Client-0.03/lib/WebSphere/MQTT/Client.pm
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use WebSphere::MQTT::Client;
use Device::SerialPort;
use Data::Dumper;
use Clone qw(clone);
use strict;
use warnings;

sub open_port();
sub fetch_data();
sub fetch_data_fake();
sub parse_data($);
sub generate_message($);

my $porthandle;
my $portname = "/dev/ttyUSB0";
my @cache;
my $cachesize = 300;

# Outer loop.  Keep connecting to the broker.
# This is intended to keep the program running even if the broker or TTYUSB
# goes down.
while (1) {
	# Connect to broker
	my $mqtt = new WebSphere::MQTT::Client(
		Hostname => 'localhost',
		Port => 1883,
		Debug => 1,
	);

	my $res = $mqtt->connect();
	if ($res) {
		print "Broker connect failed: $res\nRetrying...\n";
		next;
	}
	print "Broker connection established.\n";

	# Inner loop.  Keep fetching data and outputting it
	while(1) {
		my $rawdata = fetch_data();
		my %packet = parse_data($rawdata);

		if (! %packet ) {
			print "Invalid data packet fetched, retrying ...\n";
			sleep 5;
			next;
		} else {
			# Commit the last known data to the last data queue
			# Also just dump the raw data out
			my $message = generate_message(\%packet);
			my $res = $mqtt->publish($message,"envir-last",0,0);
			my $res2 = $mqtt->publish($rawdata,"envir-raw",0,0);
			if ($res) {
				print "Failed to publish: $res\n";
				last;
			} else {
				print "Published instantaneous data to envir-last\n";
			}

			# Add this element into the cache
			push(@cache, \%packet);

			# Calculate the moving average over the cache lifetime
			if (1) {
				my $cachelength = @cache;
				my %summary = %{ clone(\%packet) };
				$summary{timestamp} = time(); 
				$summary{sensors} = { };
				$summary{tmpr} = 0;

				# Sum up all the data
				foreach my $x (@cache) {
					foreach my $k (keys %{ $x->{sensors} }) {
						if (! exists $summary{sensors}->{$k}) {
							$summary{sensors}->{$k} = 0;
						};

						$summary{sensors}->{$k} += $x->{sensors}->{$k};
					}

					$summary{tmpr} += $x->{tmpr};
				}

				# Average it
				foreach my $k (keys %{ $summary{sensors} }) {
					$summary{sensors}->{$k} = int (($summary{sensors}->{$k} / $cachelength) + 0.5);
				}
				$summary{tmpr} = sprintf("%.1f", $summary{tmpr} / $cachelength);

				# Publish the moving average
				my $message = generate_message(\%summary);
				my $res = $mqtt->publish($message,"envir-average",0,0);
				if ($res) {
					print "Failed to publish: $res\n";
					last;
				} else {
					print "Published average to envir-average\n";
				}
			}

			# Drop the oldest element off the cache until it's not full
			while ($packet{timestamp} - $cache[0]->{timestamp} >= $cachesize) {
				shift(@cache);
			}
			
		}
	}
	
	print "Terminating MQTT session ...\n";
	$mqtt->terminate();
}

exit 0;

############################################################################

# Opens the serial port (does nothing if it's already opened)
sub open_port() {

	my $stty = `stty -F $portname speed 57600`;

	my $port = Device::SerialPort->new($portname) || return 0;
	$port->baudrate(57600) || return 0;
	$port->parity("none") || return 0;
	$port->databits(8) || return 0;
	$port->stty_icrnl(1) || return 0;
	$port->handshake("none") || return 0;
	$port->write_settings || return 0;

	open(DEV, "<$portname") || return 0;

	$porthandle = *DEV;

	return 1;
}

# Generates a single message from the data hash passed in
sub generate_message($) {
	my $output = shift;

	my $message;
	my $sensors = $output->{sensors};

	$message = "timestamp: " . $output->{timestamp} . "\n";
	$message .= "temperature: " . $output->{tmpr} . "\n";

	foreach my $sensornum (keys %$sensors) {
		my $reading = $sensors->{$sensornum};
		$message .= "sensor: " . $sensornum . " ";
		$message .= "reading: " . $reading . "\n";
	}	

	return $message;
}

# Fetches a line of data from the serial port.
# This sub will manage the opening of the port until it gets a line of data.
sub fetch_data() {
	while (1) {

		# Make sure that the port is open
		if (! $porthandle || tell($porthandle) == -1) {
			print "Attempting to open serial port $portname ...\n";
			if (open_port()) {
				print "Port open successful.\n";
				sleep 1;
				next;
			} else {
				print "Port open failed.\n";
				sleep 5;
				next;
			}
		}

		# The port should be open.  Fetch an input line.
		my $input = <$porthandle>;

		if (! $input) {
			# Bad input = port's down.  Sleep for 5 seconds.
			sleep 5;
			next;
		}	

		# Check it for sanity and return it if OK.
		if ($input =~ m/(<msg>.+?<\/msg>)/) {
			print "Message: '$1'\n";
			return $1;
		}

		# Bad input.  Wait a second and continue.
		sleep 1;
	}	
}

# STUB - Generates fake data from 3 sensors
sub fetch_data_fake() {

	my $sensor1 = int(rand(2400));
	my $sensor2 = int(rand($sensor1));
	my $sensor3 = int(rand($sensor1-$sensor2));

	my $msg = "<msg>";
	$msg .= "<src>CC128-v1.29</src>";
	$msg .= "<dsb>00002</dsb>";
	$msg .= "<tmpr>19.0</dsb>";
	$msg .= "<time>12:11:28</time>";
	$msg .= "<sensor>0</sensor><id>03839</id><type>1</type>";
	$msg .= "<ch1><watts>" . $sensor1 . "</watts></ch1>";
	$msg .= "<ch2><watts>" . $sensor2 . "</watts></ch2>";
	$msg .= "<ch3><watts>" . $sensor3 . "</watts></ch3>";
	$msg .= "</msg>";

	sleep 5;

	return $msg;
}

# Parses incoming sensor data into a hash of values
# Returns undef if there's no good data
sub parse_data($) {
	my $msg = shift;
	my $sensordata;
	my $sensornumber;
	my $sensor;

	my %output = (
		timestamp => time(),
		sensors => { }
	);

	# History messages are disregarded entirely
	if ($msg =~ /<hist>(.+)<\/hist>/i) {
		return undef;
	} elsif ($msg =~ /<msg>(.+)<\/msg>/i) {
		# Otherwise the message is parsed
		$msg = $1;

		# Extract some key information from the string
		if ($msg =~ /<src>(.+)<\/src>/i) {
			$output{src} = $1;
		}
		if ($msg =~ /<dsb>(.+)<\/dsb>/i) {
			$output{dsb} = $1;
		}
		if ($msg =~ /<tmpr>(.+)<\/tmpr>/i) {
			$output{tmpr} = $1;
		}

		# Pull out the sensor data
		while (1) {
			if (! $msg) {
				last
			} elsif ($msg =~ /(<sensor>.+?)(<sensor>.*)/i) {
				$sensordata = $1;
				$msg = $2;
			} elsif ($msg =~ /(<sensor>.+)$/i) {
				$sensordata = $1;
				$msg = undef;
			} else {
				last;
			}

			# Ok, we have some applicable sensor data
			if ($sensordata =~ m/<sensor>(\d+)<\/sensor>/i) {
				$sensornumber = int($1);

				# Fortunately there's only three channels per sensor.
				if ($sensordata =~ m/<ch1><watts>(\d+)<\/watts><\/ch1>/i) {
					$output{sensors}{"$sensornumber.1"} = int($1);
				}
				if ($sensordata =~ m/<ch2><watts>(\d+)<\/watts><\/ch2>/i) {
					$output{sensors}{"$sensornumber.2"} = int($1);
				}
				if ($sensordata =~ m/<ch3><watts>(\d+)<\/watts><\/ch3>/i) {
					$output{sensors}{"$sensornumber.3"} = int($1);
				}
			}
		}
	} else {
		return undef;
	}

	# Data is only returned if it contains some sensor data
	$sensor = $output{sensors};
	if (scalar keys %$sensor) {
		return %output;
	} else {
		return undef;
	}
}

#########################################################################
