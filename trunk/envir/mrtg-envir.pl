#!/usr/bin/perl
#
# mrtg-envir.pl
#
# Fetches data from MQTT channels for the ENVI-R in MRTG compatible format
#
# Usage: mrtg-envir channel sensor1 sensor2
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
use Data::Dumper;
use strict;
use warnings;

my $Debug = 1;

sub GetReading($$);
sub CalculateReading($$);

die "usage: mrtg-envir.pl channel sensor1 sensor2" unless ($#ARGV == 2);

my $mqtt = new WebSphere::MQTT::Client(
	Hostname => 'localhost',
	Port => 1883,
);

my $channel = shift @ARGV;
my $sensor1 = shift @ARGV;
my $sensor2 = shift @ARGV;

# Connect to broker
my $res = $mqtt->connect();
die "Failed to connect: $res\n" if ($res);

# Subscribe to channel
$res = $mqtt->subscribe($channel);
die "Failed to subscribe: $res\n" if ($res);

# Receive any messages
my @result = $mqtt->receivePub();
if (@result) {
	# Ok, we got data.  Parse it.
	my $str = $result[1];
	my $value1 = CalculateReading($str, $sensor1);
	my $value2 = CalculateReading($str, $sensor2);

	# Output in MRTG format
	print "$value1\n";
	print "$value2\n";
	print "0\n";
	print "mrtg-envir $channel $sensor1 $sensor2\n";
} else {
	die "Could not receive message for subscription.  Aborting.";
}

# Unsubscribe and terminate MQTT
$mqtt->unsubscribe($channel);
$mqtt->terminate();

# Calculates a reading from some "tricky" maths.
# Tokens;
# <number>.<number> - sensor number
# + - add next argument
# - - subtract next argument
# temp - temperature reading
# offset(number) - offset value
# floor(sensor, number) - return 0 for sensor if it's below number
# Whitespace is NOT permitted!
sub CalculateReading($$)
{
	my $message = shift;
	my $text = shift;
	my $token = $text;
	my $polarity = 1;
	my $result = 0;

	if (! $text) {
		return 0;
	}

	# Find polarity of this argument
	if ($text =~ /^([+-])(.+)/) {
		if ($1 eq "-") {
			$polarity = -1;
		}
		$token = $2;
		$text = $2;
	}	

	# Fetch the next token
	if ($text =~ /^(.+?)([+-].+)/) {
		$token = $1;
		$text = $2;
	} else {
		$text = undef;
	}

	if ($token =~ /^\d+\.\d+$/) {
		# Bare sensor number.  Return the sensor
		$result = GetReading($message,$token);
	} elsif ($token =~ /^offset\((\d+)\)$/) {
		# Offset.
		$result = $1;
	} elsif ($token =~ /^floor\((\d+),(\d+)\)$/) {
		# Floor.
		my $reading = GetReading($message,$1);
		if ($reading < $2) {
			$result = 0;
		} else {
			$result = $reading;
		}
	} elsif ($token =~ /^temp$/) {
		# Temperature reading
		if ($message =~ /temperature: ([0-9\.]+)/) {
			$result = int($1*10+0.5);
		} else {
			$result = 0;
		}
	} else {
		die "Parse error on '$text'";
	}

	# Now, variables are as follows;
	# $result = calculation of this operator
	# $polarity = polarity of this operator
	# $text = remaining tokens

	return $polarity * $result + CalculateReading($message, $text);
}

# Fetches a bare reading from the MQTT output
sub GetReading($$)
{
	my $message = shift;
	my $sensor = shift;
	
	if ($message =~ /sensor: $sensor reading: (\d+)/) {
		return $1;
	} else {
		return 0;
	}
}
