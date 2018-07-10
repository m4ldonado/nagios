#!/usr/bin/env perl

use strict;
use warnings;

use Monitoring::Plugin;

use vars qw($VERSION $PROGNAME $verbose $warn $critical $timeout $result $iface $max_throughput $bytes1 $bytes2);
$VERSION = '1.0';



my $p = Monitoring::Plugin->new(
	usage => "Usage: %s [ -v|--verbose ] [-H <host>] [-t <timeout>]
	[ -i|--iface=<nic name> ]
	[ -c|--critical=<critical threshold> ]
	[ -w|--warning=<warning threshold> ]
	[ -r|--result=<INTEGER> ]
	[ -m| --max_throughput=<max throughput in Mbits/sec>]",
	version => $VERSION,
	blurb => 'This plugin monitors how much of a nic\'s throughput is being used and will warn if the throughput exceeds a selected a percentage of it\'s maximum',);

$p->add_arg(
	spec => 'warning|w=s',
	help => qq{-w,  --warning=INTEGER:INTEGER
	Minimum and maximum number of allowable result, outside of which a warning will be generated.},
	default => '0:50',
);

$p->add_arg(
	spec => 'critical|c=s',
	help => qq{-c, --critical=INTEGER:INTEGER
        Minimum and maximum number of the generated result, outside of which a critical will be generated. },
	default => '0:90',
);



$p->add_arg(
	spec => 'iface|i=s',
	help => qq{-i, --iface=STRING
	The name of the network interface card (should be as it appears in /sys/class/net/). },
        required => 1,
);

$p->add_arg(
	spec => 'max_throughput|m=s',
	help => qq{-m, --max_throughput=Integer
	The maxmimum throughput in Mbits/sec - defaults to the link speed },
);


$p->add_arg(
	spec => 'result|r=f',
	help => qq{-r, --result=INTEGER
	Specify the result on the command line. For testing.},
);

$p->getopts;


#Sanity check on arguments

$iface =  $p->opts->iface; 

if ( ! -e "/sys/class/net/$iface" ){
	$p->plugin_die("Please check iface name - cannot stat /sys/class/net/$iface");
}

#set throughput to link speed if not set 

if ( ! $p->opts->max_throughput ){ 
	open(my $fh, '<', "/sys/class/net/$iface/speed");
	chomp($max_throughput = <$fh>);
	close($fh);
}

else{
	$max_throughput = $p->opts->max_throughput;
}




open(my $fh, '<', "/sys/class/net/$iface/statistics/tx_bytes");
$bytes1 = <$fh>;
sleep 10;
seek($fh,0,0);
chomp($bytes2 = <$fh>);
close $fh;



$result = ((($bytes2 - $bytes1) / 10 ) * 8e-6) / ($max_throughput / 100);


$p->plugin_exit(
	return_code => $p->check_threshold($result),
	message=> " interface $iface is at $result% capacity",
);
