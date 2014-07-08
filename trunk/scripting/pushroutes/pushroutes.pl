#!/usr/bin/perl
#
# OpenVPN Push Route configurator for OpenWRT.  
# Written by James Young, 2013.  No warranties.  Use at your own risk.
#
# This script generates appropriate push route rules and pins DNS entries
# permitting you to redirect routes into an OpenVPN tunnel on an OpenWRT
# router.  It will automatically log into your router, upload the correct
# files and restart the services.
#
# DANGER -  This is only for use with OpenWRT and OpenVPN.  Be careful
# with what you do with this, you may badly damage your network by using
# this script incorrectly.
#
# OpenWRT files
# -------------
# 
# /etc/hosts should contain the following two tag lines;
#
# ##### PUSHROUTES hosts START - DON'T MODIFY THIS #####
# ##### PUSHROUTES hosts END - DON'T MODIFY THIS #####
#
# Without the leading "# " of course.  This indicates an area inside the
# file that will be overwritten by this script.
#
# /etc/config/openvpn should contain the same tags, but with the 'hosts'
# part replaced with the target name you specify below in the config file.
# These sections should go inside the config for that vpn client connection.
#
# Config file format:
# -------------------
#
# Comments start with #'s.  Can be either whole lines or at end of lines.
#
# config router ROUTERFQDN
# 	Configures the target router to log into as ROUTERFQDN
# config openvpn PATH
# 	Configures the path for the OpenWRT client config to be at PATH
# 	Default: /etc/config/openvpn
# config hosts PATH
# 	Configures the path for the DNSMASQ Hosts file to be at PATH
# 	Default: /etc/hosts
# config addvpn TARGETNAME dns DNSSERVER
# 	Adds a new target VPN tunnel tagged TARGETNAME with a dns server
# 	of DNSSERVER.  Target name must exist in openvpn config.
# config defaultvpn TARGETNAME
# 	Sets the default vpn to use for rules to TARGETNAME
# route dns FQDN [dnsfailok] [target TARGETNAME]
# 	Configures a route for whatever address FQDN resolves to to go
# 	out target TARGETNAME.  If dnsfailok is specified, DNS failures
# 	cause this route to be ignored.  If target not specified, uses
# 	default.
# route ip IPADDRESS [netmask NETMASK] [target TARGETNAME]
#	Configures a route for the IP address/netmask specified to go
#	out target TARGETNAME.  If a netmask is not specified, it defaults
#	to 255.255.255.255.  If target not specified, uses default.
#

use Net::DNS::Resolver;
use strict;

# Name of input file
my $inputfile = "routes.conf";

my $lineno = 0;

# Disable output buffering
$| = 1;

# Configuration data
my $router;					# OpenWRT router to write to
my $openvpnpath = "/etc/config/openvpn";	# Path to read/write OpenVPN config from
my $hostspath = "/etc/hosts";			# Path to read/write hosts config from
my $defaultvpn;					# Name of default VPN entry

# Created routing and push dns info
my %routedata;		# Route data, keyed by vpn
my %vpndns;		# VPN DNS servers, keyed by vpn
my @dnsdata;		# DNS entries that need to be pinned in hosts

# Read data lines from end of file
open INPUT, $inputfile or die "Cannot open input file $inputfile";
print "Parsing input data ";
while (my $line = <INPUT>) {
	$lineno++;

	# Chop off anything after # signs
	$line =~ s/\s*#.*//g;

	# Smash any multi-character whitespace to spaces
	$line =~ s/\s+/ /g;

	# Trim any whitespace from beginning and end of line
	$line =~ s/^\s+//g;
	$line =~ s/\s+$//g;

	# Skip comment lines
	if ($line =~ m/^\s*$/ || $line =~ m/^\s*#/) {
		next;
	}
	
	# Print pacifier
	print(".");

	if ($line =~ m/^config router (\S+)$/) {
		$router = $1;
		next;	
	}

	if ($line =~ m/^config openvpn (\S+)$/) {
		$openvpnpath = $1;
		next;
	}

	if ($line =~ m/^config hosts (\S+)$/) {
		$hostspath = $1;
		next;
	}

	if ($line =~ m/^config addvpn (\S+) dns (\S+)$/) {
		if (exists $routedata{$1}) {
			die "VPN $1 already exists on line $lineno";
		}

		if (! $defaultvpn) {
			$defaultvpn = $1;
		}

		# Generate an empty routing table for this vpn
		my $array = [];
		$routedata{$1} = $array;

		# Generate a DNS resolver for this VPN
		my $res = Net::DNS::Resolver->new(
			nameservers => [$2]
		);
		$vpndns{$1} = $res;

		next;
	}

	if ($line =~ m/^config defaultvpn (\S+)$/) {
		if (exists $routedata{$1}) {
			$defaultvpn = $1;
		} else {
			die "Can't set undefined VPN $1 as default on line $lineno";
		}
		next;
	}

	# Route creation
	if ($line =~ m/^route (ip|dns) (.+)$/) {
		my $type = $1;		# type of route
		my $params = $2;
		my @addresses;
		my $hostname;
		my $netmask = "255.255.255.255";
		my $dnsfailok = 0;
		my $target = $defaultvpn;

		if (scalar keys(%routedata) eq 0) {
			die "No VPNs have been defined";
		}

		# fetch target (if any)
		# this is done early because we use this to resolve dns
		if ($params =~ m/target (\S+)/) {
			if (exists $routedata{$1}) {
				$target = $1;
			} else {
				die "target $1 doesn't exist on line $lineno";
			}
		}

		# if dns resolution fails, just go to the next entry instead of aborting
		if ($params =~ m/dnsfailok/) {
			$dnsfailok = 1;
		}

		# fetch addresses to be routed	
		if ($type eq "dns") {
			# Resolve DNS addresses
			if ($params =~ m/^(\S+)/) {
				$hostname = $1;
				my $query = $vpndns{$target}->search($hostname);
				if ($query) {
					foreach my $rr ($query->answer) {
						next unless $rr->type eq "A";
						push(@addresses, $rr->address);
					}
				} else {
					if ($dnsfailok) {
						print "(!$hostname)";
						next;
					} else {
						die "couldn't resolve $hostname for vpn $target on line $lineno";
					}
				}
			} else {
				die "route dns must be followed by a dns name on line $lineno";
			}
		} else {
			# By IP address
			if ($params =~ m/^(\d+\.\d+\.\d+\.\d+)/) {
				my $ipaddr = $1;
				push(@addresses,$ipaddr);
			} else {
				die "route ip must be followed by an ip address on line $lineno";
			}
		}

		# fetch netmask (if any - not valid with dns type)
		if ($params =~ m/netmask (\d+\.\d+\.\d+\.\d+)/) {
			if ($type eq "dns") {
				die "netmask option invalid with dns route type on line $lineno";
			}
			$netmask = $1;
		}

		# At this point, we have a complete config line.  Commit it.
		foreach (@addresses) {
			my $address = $_;

			# Push any DNS names into hosts file
			if ($type eq "dns") {
				push (@dnsdata, "$address\t$hostname");
			}

			# Push any routes into the right array
			push(@{$routedata{$target}}, "$address $netmask");
		}

		next;
	}

	# Errr...
	die "Invalid line '$line' on line $lineno";
}
print " done\n";

# Input data parsed.  Now copy in the relevant files
print "Copying files from source router ...\n";
system("scp root\@$router:$openvpnpath /tmp/pushroutes.openvpn");
system("scp root\@$router:$hostspath /tmp/pushroutes.hosts");
END {
	unlink "/tmp/pushroutes.openvpn";
	unlink "/tmp/pushroutes.hosts";
}

# Prepare new files
print "Generating new files ... \n";
my $outputhosts = "/tmp/pushroutes.hosts.new";
my $outputovpn = "/tmp/pushroutes.openvpn";

# Write out the hosts file
if (1) {
	open(FHHOSTS, ">$outputhosts");
	END {
		close FHHOSTS;
		unlink $outputhosts;
	}

	# Sort and uniq the list
	@dnsdata = sort @dnsdata;
	my @unique = do { my %seen; grep { !$seen{$_}++ } @dnsdata };

	print FHHOSTS readfile(1,"hosts","/tmp/pushroutes.hosts");
	print FHHOSTS gettag(1,"hosts");
	print FHHOSTS "\n";

	foreach (@unique) {
		print FHHOSTS "$_\n";
	}

	print FHHOSTS "\n";
	print FHHOSTS gettag(0,"hosts");
	print FHHOSTS readfile(0,"hosts","/tmp/pushroutes.hosts");
	
	close FHHOSTS;
}

# Write out the openvpn file
if (1) {
	foreach (keys(%routedata)) {
		my $target = $_;

		# Sort and uniq the list
		my @routes = sort @{$routedata{$target}};
		my @unique = do { my %seen; grep { !$seen{$_}++ } @routes };

		# Generate a new file for this vpn
		open(FHOVPN, ">/tmp/pushroutes.openvpn.$target");
		END {
			close FHOVPN;
			unlink "/tmp/pushroutes.openvpn.*";
		}

		# Output the file
		print FHOVPN readfile(1,$target,$outputovpn);
		print FHOVPN gettag(1,$target);
		print FHOVPN "\n";

		foreach (@unique) {
			print FHOVPN "\tlist route '$_'\n";
		}

		print FHOVPN "\n";
		print FHOVPN gettag(0,$target);
		print FHOVPN readfile(0,$target,$outputovpn);
	
		close FHOVPN;

		$outputovpn = "/tmp/pushroutes.openvpn.$target";
	}
}

# And finally, push the files to the router.
if (1) {
	# Files generated.  Push to the router.
	print "Sending new files to source router ...\n";
	system("scp $outputovpn root\@$router:$openvpnpath");
	system("scp $outputhosts root\@$router:$hostspath");

	# And finally, restart services on the router
	print "Reloading dnsmasq ...\n";
	system("ssh root\@$router /etc/init.d/dnsmasq reload");
	print "Reloading OpenVPN ...\n";
	system("ssh root\@$router /etc/init.d/openvpn reload");
}

print "Run completed.\n";

####### Subroutines #######

sub gettag($$) {
	my $pre = shift;
	my $tag = shift;

	if ($pre) {
		return "##### PUSHROUTES $tag START - DON'T MODIFY THIS #####\n";
	} else {
		return "##### PUSHROUTES $tag END - DON'T MODIFY THIS #####\n";
	}
}

sub readfile($$) {
	my $pre = shift;
	my $tag = shift;
	my $file = shift;
	my $starttagfound = 0;
	my $endtagfound = 0;
	my $output = "";
	open(FH, "<$file");

	while (<FH>) {
		my $line = $_;
		chomp $line;
		if ($line =~ m/##### PUSHROUTES $tag (START|END) - DON'T MODIFY THIS #####/) {
			if ($1 eq "START" && $starttagfound) {
				die "Found start tag $tag more than once in $file, aborting.";
			} elsif ($1 eq "START" && $endtagfound) {
				die "Found start tag $tag after end tag in $file, aborting.";
			} elsif ($1 eq "START") {
				$starttagfound=1;
				next;
			} elsif ($1 eq "END" && ! $starttagfound) {
				die "Found end tag without leading start tag $tag in $file, aborting.";
			} elsif ($1 eq "END") {
				$endtagfound = 1;
				next;
			}				
		}

		if ($pre) {
			# We want the stuff _before_ the start tag
			if (! $starttagfound) {
				$output .= $line . "\n";
			}
		} else {
			# We want the staff _after_ the end tag
			if ($endtagfound) {
				$output .= $line . "\n";
			}
		}
	}

	if ($output eq "") {
		die "Did not find any valid tag $tag in $file, aborting.";
	}

	return $output;
}
