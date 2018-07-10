#!/usr/bin/env perl

use strict;
use warnings;

use Monitoring::Plugin;

use vars qw($VERSION $warn $critical $timeout $result $directory $mtime $seconds_since_write $return_code $warning_threshold $critical_threshold);
$VERSION = '1.0';

my $p = Monitoring::Plugin->new(
  usage => "Usage: %s [ -v|--verbose ] [-H <host>] [-t <timeout>]
  [ -d|--directory=<> ]
  [ -c|--critical=<critical threshold in seconds> ]
  [ -w|--warning=<warning threshold in seconds> ]
  [ -x|--exclude=<do not look at the mtimes of files that contain this string> ]
  [ -r|--result=<INTEGER>]",
  version => $VERSION,
  blurb => 'This module checks the mtime how long ago the most recent file modification was for a given directory.  Useful to see if processes are writing out correctly',);

$p->add_arg(
  spec => 'warning|w=s',
  help => qq{-w,  --warning=INTEGER:INTEGER
  Minimum and maximum number of allowable result, outside of which a warning will be generated.},
  default => '3600',
);

$p->add_arg(
  spec => 'critical|c=s',
  help => qq{-c, --critical=INTEGER:INTEGER
        Minimum and maximum number of the generated result, outside of which a critical will be generated. },
  default => '36000',
);

$p->add_arg(
  spec => 'directory|d=s',
  help => qq{-D, --directory=STRING
	path of directory to check},
  default => '/',
);

$p->add_arg(
  spec => 'result|r=f',
  help => qq{-r, --result=INTEGER
  Specify the result on the command line. For testing.},
);

$p->add_arg(
  spec => 'exclude|x=s@',
  help => qq{-R, --regex=STRING
	a regex for which file NOT to include.},
);


$p->getopts;


#Sanity check on arguments

$directory = $p->opts->directory;

if ( ! -e  $directory){
	$p->plugin_die("Please check directory - cannot stat $directory\n");
}


my $awk_if_statement = '1';
if(my $foo = $p->opts->exclude){
	my @escaped = map(quotemeta($_),  @{$foo});
	my $regex = join('|', @escaped);
	$awk_if_statement = "\$2 !~ /$regex/";
}

#this lovely bit of awk comes from marco's answer here
# https://stackoverflow.com/questions/4561895/how-to-recursively-find-the-latest-modified-file-in-a-directory/18641147
my $bash_command = <<"END_MESSAGE";
find $directory -type f -printf "%T@ %p\\n"  |
awk '
BEGIN { current_highest = 0; file_info = "" }
{
		if($awk_if_statement){
			if (\$1 > current_highest){
				current_highest = \$1;
				file_info = \$0;
			}
		}
}
END { print file_info; }'
END_MESSAGE

`$bash_command` =~ /(^.*?)\..*? (.*)/ || $p->plugin_die("no files to check in $directory.  Please check the directory or exclude options\n");

my($mtime, $file) = ($1, $2);

$result = time - $mtime;
$return_code = $p->check_threshold($result);
$p->plugin_exit(
  return_code => $return_code,
  message => "file $file written $result seconds ago | seconds_since_write=$result;$p->{opts}->{warning};$p->{opts}->{critical};$return_code",
);
  

