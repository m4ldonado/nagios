#!/usr/bin/perl


#This script takes the path to the libexec and the name of a module as arguments 
#and outputs a script to the libexec folder which uses ansible to call the module
#You can use the script that's created as you would have used the module and it additionaly takes a HostName as it's first argument 
#I.E you can call it like this: 
# ./convert_to_ansible.pl /usr/local/nagios/libexec check_disk
# which will create /usr/local/nagios/ansible_check_disk
#which you can call like 
# ./ansible_check_disk $hostname -w 5 -c 10
#where you would have called the original module like
#./check_disk -w 5 -c 10

use warnings;
use strict;

my $path = $ARGV[0] || die "please supply path to libexec as ARGV[0]";
my $module = $ARGV[1] || die "please supply module filename as ARGV[1]";
die "path $path doesnt exist" if (! -d $path);
$path .= '/' if $path !~ /\/$/;
my $ansible_module = "$path" . "ansible_$module";
open(my $ifh, '<', "$path$module") || die "Couldnt open $path$module for reading";
die "ansible_$module already exists" if(-e "$ansible_module");
open(my $ofh, '>', $ansible_module) || die "Couldn't open $ansible_module for writing";
print $ansible_module . "\n";
print $ofh <<"EOF"
#!/usr/bin/env perl

use JSON;

my \$ansible_command = "ansible \$ARGV[0] -m script -a '$path$module ";
\$ansible_command .= join(' ', \@ARGV[1..\$#ARGV]) if(\@ARGV > 1);
\$ansible_command .= "'";
my \$output = `\$ansible_command`;
#strip the ansible output to only JSON
my \$JSON = \$output;
#print \$JSON . "\\n";
\$JSON =~ s/^[^{]+//;
if(\$JSON =~ /unreachable": true/){
	print 'CAN\\'T CONNECT TO HOST';
	exit 3;
}
#print \$JSON . "\\n";
\$JSON =~ s/[^}]+?\$//;
#print \$JSON . "\\n";
my \$text = decode_json(\$JSON);
if(\${\$text}{'stdout_lines'}){
	print \${\$text}{'stdout_lines'}[-1] . "\n";
}
else{
	print \${\$text}{'stdout'};
}
exit \${\$text}{'rc'};
EOF
;


chmod 0755, "$ansible_module"; 
