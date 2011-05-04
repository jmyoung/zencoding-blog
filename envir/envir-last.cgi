#!/usr/bin/perl
#
# Horrible CGI script for dropping out the latest ENVIR temperature data
# to a table.
# 

use WebSphere::MQTT::Client;
use Data::Dumper;
use strict;
use warnings;

print "Content-type: text/html\n\n";

my $mqtt = new WebSphere::MQTT::Client(
	Hostname => 'localhost',
	Port => 1883,
);

my $channel = "envir-last";
my $reading1 = 0;
my $reading2 = 0;
my $reading3 = 0;

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

	if ($str =~ /sensor: 0.1 reading: (\d+)/) {
		$reading1 = $1;
	}
	if ($str =~ /sensor: 0.2 reading: (\d+)/) {
		$reading2 = $1;
	}
	if ($str =~ /sensor: 0.3 reading: (\d+)/) {
		$reading3 = $1;
	}
} else {
	die "Could not receive message for subscription.  Aborting.";
}

# Output in nice HTML format
my $diff = $reading1 - $reading2 - $reading3;
print "<table border=1>";
print "<tr align=center><td>Lights</td><td>Water</td><td>Other</td><td>TOTAL</td></tr>";
print "<tr align=center><td>$reading2</td><td>$reading3</td><td>$diff</td><td>$reading1</td></tr>";
print "</table>";

# Unsubscribe and terminate MQTT
$mqtt->unsubscribe($channel);
$mqtt->terminate();

