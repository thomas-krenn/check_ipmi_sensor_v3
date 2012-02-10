#!/usr/bin/perl
# check_ipmi_sensor: Nagios/Icinga plugin to check IPMI sensors
#
# Copyright (C) 2009-2011 Thomas-Krenn.AG (written by Werner Fischer),
# additional contributors see changelog.txt
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>.
#
################################################################################
# The following guides provide helpful information if you want to extend this
# script:
#   http://nagios.sourceforge.net/docs/3_0/customobjectvars.html (hints on
#                  custom object variables)
#   http://nagiosplug.sourceforge.net/developer-guidelines.html (plug-in
#                  development guidelines)
#   http://nagios.sourceforge.net/docs/3_0/pluginapi.html (plugin API)
################################################################################
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use IPC::Run qw( run ); #interact with processes

use lib '/usr/lib/nagios/plugins';
use utils qw(%ERRORS);

our $missing_command_text = "";
our $abort_text ="";
################################################################################
# set ipmimonitoring path
our $IPMICOMMAND ="";
if(-x "/usr/sbin/ipmimonitoring"){
	$IPMICOMMAND = "/usr/sbin/ipmimonitoring";
}
elsif (-x "/usr/bin/ipmimonitoring"){
	$IPMICOMMAND = "/usr/bin/ipmimonitoring";
}
elsif (-x "/usr/local/sbin/ipmimonitoring"){
	$IPMICOMMAND = "/usr/local/sbin/ipmimonitoring";
}
elsif (-x "/usr/local/bin/ipmimonitoring"){
	$IPMICOMMAND = "/usr/local/bin/ipmimonitoring";
}
else{
	$missing_command_text = " ipmimonitoring command not found";
}

#define entire hashes
our %hdrmap = (
	'Record_ID'		=> 'id',	# FreeIPMI ...,0.7.x
	'Record ID'		=> 'id',	# FreeIPMI 0.8.x,... with --legacy-output
	'ID'			=> 'id',	# FreeIPMI 0.8.x
	'Sensor Name'		=> 'name',
	'Name'			=> 'name',	# FreeIPMI 0.8.x
	'Sensor Group'		=> 'type',
	'Type'			=> 'type',	# FreeIPMI 0.8.x
	'Monitoring Status'	=> 'state',
	'State'			=> 'state',	# FreeIPMI 0.8.x
	'Sensor Units'		=> 'units',
	'Units'			=> 'units',	# FreeIPMI 0.8.x
	'Sensor Reading'	=> 'reading',
	'Reading'		=> 'reading',	# FreeIPMI 0.8.x
	'Event'			=> 'event',	# FreeIPMI 0.8.x
    );

sub get_version
{
    return <<EOT;
check_ipmi_sensor version 3.0 2011-05-01
Copyright (C) 2009-2011 Thomas-Krenn.AG (written by Werner Fischer)
Current updates available at http://www.thomas-krenn.com/en/oss/ipmi-plugin/
EOT
}

sub get_usage
{
    return <<EOT;
Usage:
check_ipmi_sensor -H <hostname>
  [-f <FreeIPMI config file> | -U <username> -P <password> -L <privilege level>]
  [-O <FreeIPMI options>] [-b] [-T <sensor type>] [-x <sensor id>] [-v 1|2|3]
  [-o zenoss] [-h] [-V]
EOT
}

sub get_help
{
    return <<EOT;
Options:
  -H <hostname>
       hostname or IP of the IPMI interface.
       For "-H localhost" the Nagios/Icinga user must be allowed to execute
       ipmimonitoring with root privileges via sudo (ipmimonitoring must be
       able to access the IPMI devices via the IPMI system interface).
  [-f <FreeIPMI config file>]
       path to the FreeIPMI configuration file.
       Only neccessary for communication via network.
       Not neccessary for access via IPMI system interface ("-H localhost").
       It should contain IPMI username, IPMI password, and IPMI privilege-level,
       for example:
         username monitoring
         password yourpassword
         privilege-level user
       As alternative you can use -U/-P/-L instead (see below).
  [-U <username> -P <password> -L <privilege level>]
       IPMI username, IPMI password and IPMI privilege level, provided as
       parameters and not by a FreeIPMI configuration file. Useful for RHEL/
       Centos 5.* with FreeIPMI 0.5.1 (this elder FreeIPMI version does not
       support config files).
       Warning: with this method the password is visible in the process list.
                So whenever possible use a FreeIPMI confiugration file instead.
  [-O <FreeIPMI options>]
       additional options for FreeIPMI. Useful for RHEL/CentOS 5.* with
       FreeIPMI 0.5.1 (this elder FreeIPMI version does not support config
       files).
  [-b]
       backward compatibility mode for FreeIPMI 0.5.* (this omits the FreeIPMI
       caching options --quiet-cache and --sdr-cache-recreate)
  [-T <sensor type>]
       limit sensors to query based on IPMI sensor type.
       Examples for IPMI sensor type are 'Fan', 'Temperature', 'Voltage', ...
       See chapter '42.2 Sensor Type Codes and Data' of the IPMI 2.0 spec for a
       full list of possible sensor types. The available types depend on your
       particular server and the available sensors there.
  [-x <sensor id>]
       exclude sensor matching <sensor id>. Useful for cases when unused
       sensors cannot be deleted from SDR and are reported in a non-OK state.
       Option can be specified multiple times. The <sensor id> is a numeric
       value (sensor names are not used as some servers have multiple sensors
       with the same name). Use -v 3 option to query the <sensor ids>.
  [-v 1|2|3]
       be verbose
         (no -v) .. single line output
         -v 1 ..... single line output with additional details for warnings
         -v 2 ..... multi line output, also with additional details for warnings
         -v 3 ..... debugging output, followed by normal multi line output
  [-o]
       change output format. Useful for using the plugin with other monitoring
       software than Nagios or Icinga.
         -o zenoss .. create ZENOSS compatible formatted output (output with
                      underscores instead of whitespaces and no single quotes)
  [-h]
       show this help
  [-V]
       show version information

When you use the plugin with newer FreeIPMI versions (version 0.8.* and newer)
you can use --entity-sensor-names to identify multiple sensor instances,
or --interpret-oem-data to interpret OEM data.
You can set these options in your FreeIPMI configuration file:
  ipmi-sensors-interpret-oem-data on
or you provide
  -O '--interpret-oem-data --entity-sensor-names'
to the plugin.

Further information about this plugin can be found in the Thomas Krenn Wiki
(currently only in German):
http://www.thomas-krenn.com/de/wiki/IPMI_Sensor_Monitoring_Plugin

Send email to the IPMI-plugin-user mailing list if you have questions regarding
use of this software, to submit patches, or suggest improvements.
The mailing list is available at http://lists.thomas-krenn.com/
EOT
}

sub usage
{
    my ($arg) = @_; #the list of inputs
    my ($exitcode);
    if ( defined $arg ) #check if parameters were given
    {
	#m is the match operator for regex
	if ( $arg =~ m/^\d+$/ )
	{
	    $exitcode = $arg;
	}
	else
	{
	    print STDOUT $arg, "\n";
	    $exitcode = 1;
	}
    }
    print STDOUT get_usage();
    exit($exitcode) if defined $exitcode;
}

our $verbosity = 0;

MAIN: {
    $| = 1; #force a flush after every write or print
    my ($show_help, $show_version);
    my ($ipmi_host, $ipmi_user, $ipmi_password, $ipmi_privilege_level, $ipmi_config_file, $ipmi_outformat);
    my (@freeipmi_options, $freeipmi_compat);
    my (@ipmi_sensor_types, @ipmi_xlist);

    my @ARGV_SAVE = @ARGV;#keep args for verbose output

	#before we read in command line arguments we check if ipmimonitoring is available
	if( $missing_command_text ne "" ){
		print STDOUT $missing_command_text;
		exit(3);
	}

	#read in command line arguments and init hash variables with the given values from argv
    if ( !( GetOptions(
    	'H|host=s'	    	=> \$ipmi_host,#the pipe states an list of possible option names
		'f|config-file=s'	=> \$ipmi_config_file,#the backslash inits the variable with the given argument
		'U|user=s'	    	=> \$ipmi_user,
		'P|password=s'  	=> \$ipmi_password,
		'L|privilege-level=s'	=> \$ipmi_privilege_level,
		'O|options=s'		=> \@freeipmi_options,
		'b|compat'			=> \$freeipmi_compat,
		'T|sensor-types=s'	=> \@ipmi_sensor_types,
		'v|verbosity'		=> \$verbosity,
		'vv'				=> sub{$verbosity=2},
		'vvv'				=> sub{$verbosity=3},#TODO Check verbosity levels
		'x|exclude=s'		=> \@ipmi_xlist, #TODO Check if numbers instead of strings must be used
		'o|outformat'		=> \$ipmi_outformat,
		'h|help'	    	=> 
			sub{print STDOUT get_version();
				print STDOUT "\n";
				print STDOUT get_usage();
				print STDOUT "\n";
				print STDOUT get_help();
				exit(0)
			},	
		'V|version'	    	=> 
			sub{
				print STDOUT get_version();
				exit(0);
			},
		'usage|?'					=> #TODO Verify if usage is OK here
			sub{print STDOUT get_usage();
				exit(3);
			}	
	) )){
		usage(1);#call usage if GetOptions failed
	}
	#\s defines any whitespace characters
	#first join the list, then split it at whitespace ' '
	#also cf. http://perldoc.perl.org/Getopt/Long.html#Options-with-multiple-values
    @freeipmi_options = split(/\s+/, join(' ', @freeipmi_options)); # a bit hack, shell word splitting should be implemented...
    @ipmi_sensor_types = split(/,/, join(',', @ipmi_sensor_types));
    @ipmi_xlist = split(/,/, join(',', @ipmi_xlist));
    
    usage(1) if @ARGV;#print usage if unknown arg list is left
   

################################################################################
# verify if all mandatory parameters are set and initialize various variables
    my @basecmd; #variable for command to call ipmi
    if( !(defined $ipmi_host) ){
    	$abort_text= $abort_text . " -H <hostname>"
    }
    else{
    	if( $ipmi_host eq 'localhost' ){
    		@basecmd = ('sudo', $IPMICOMMAND);
    	}
    	else{
    		if(defined $ipmi_config_file){
    			@basecmd = ($IPMICOMMAND, '-h', $ipmi_host, '--config-file', $ipmi_config_file);
    		}
    		elsif ( defined $ipmi_user && defined $ipmi_password && defined $ipmi_privilege_level ){
	    		@basecmd = ($IPMICOMMAND, '-h', $ipmi_host, '-u', $ipmi_user, '-p', $ipmi_password, '-l', $ipmi_privilege_level)
			}
			else{
				$abort_text = $abort_text . " -f <FreeIPMI config file> or -U <username> -P <password> -L <privilege level>";
			}
    	}    		
    }
    
    #TODO Insert missing command text here if desired
    
    if( $abort_text ne ""){
    	print STDOUT "Error: " . $abort_text . " missing.";
		print STDOUT get_usage();
		exit(3);	
    }
    
    # , is the seperator in the new string
    if(@ipmi_sensor_types){
    	 push @basecmd, '-g', join(',', @ipmi_sensor_types);    	 
    }
    if(@freeipmi_options){
    	push @basecmd, @freeipmi_options;
    }
    
    #keep original basecmd for later usage
    my @getstatus = @basecmd;
    
    #if -b is not defined, caching options are used
    if( !(defined $freeipmi_compat) ){
    	push @getstatus, '--quiet-cache', '--sdr-cache-recreate';
    }    

################################################################################
	#execute status command and redirect stdout and stderr to ipmioutput
	my $ipmioutput;
    run \@getstatus, '>&', \$ipmioutput;
    #the upper eight bits contain the error condition (exit code)
    #see http://perldoc.perl.org/perlvar.html#Error-Variables
    my $returncode = $? >> 8;

################################################################################
# print debug output when verbosity is set to 3 (-vvv)
    if ( $verbosity == 3 ){
		my $ipmicommandversion;
		run [$IPMICOMMAND, '-V'], '2>&1', '|', ['head', '-n', 1], '&>', \$ipmicommandversion;
		#remove trailing newline with chomp
		chomp $ipmicommandversion;
		print "------------- begin of debug output (-vvv is set): ------------\n";
		print "  script was executed with the following parameters:\n";
		print "    $0 ", join(' ', @ARGV_SAVE), "\n";
		print "  ipmimonitoring version:\n";
		print "    $ipmicommandversion\n";
		print "  ipmimonitoring was executed with the following parameters:\n";
		print "    ", join(' ', @getstatus), "\n";
		print "  ipmimonitoring return code: $returncode\n";
		print "  output of ipmimonitoring:\n";
		print "$ipmioutput\n";
		print "--------------------- end of debug output ---------------------\n";
    }

################################################################################
# generate main output
    if ( $returncode != 0 ){
		print "$ipmioutput\n";
		print "-> Execution of ipmimonitoring failed with return code $returncode.\n";
		print "-> ipmimonitoring was executed with the following parameters:\n";
        print "   ", join(' ', @getstatus), "\n";
		exit(3);
    }
    else{
		#print desired filter types
		if ( @ipmi_sensor_types ){
	    	print "Sensor Type(s) ", join(', ', @ipmi_sensor_types), " Status: ";
		}
		else{
	    	print "IPMI Status: ";
		}
		#split at newlines, fetch array with lines of output
		my @ipmioutput = split('\n', $ipmioutput);
	
	#remove leading and trailing whitespace characters, split at the pipe delimiter
	@ipmioutput = map { [ map { s/^\s*//; s/\s*$//; $_; } split(m/\|/, $_) ] } @ipmioutput;
	
	#shift out the header as it is the first line
	my $header = shift @ipmioutput;
	my %header;
	for(my $i = 0; $i < @$header; $i++)
	{
		#assigning %header with (key from hdrmap) => $i
		#checking at which position in the header is which key
	    $header{$hdrmap{$header->[$i]}} = $i;
	}
	
	my @ipmioutput2;
	foreach my $row ( @ipmioutput ){
		my %row;
		#fetch keys from header and assign existent values to row
		#this maps the values from row(ipmioutput) to the header values
		while ( my ($key, $index) = each %header ){
			$row{$key} = $row->[$index];
		}
		push @ipmioutput2, \%row;
	}
	#create hash with sensor name an 1
	my %ipmi_xlist = map { ($_, 1) } @ipmi_xlist;
	#filter out the desired sensor values
	@ipmioutput2 = grep(!exists $ipmi_xlist{$_->{'id'}}, @ipmioutput2);
		
	#TODO Check if we need to grep again?
	@ipmioutput2 = grep(!exists $ipmi_xlist{$_->{'id'}}, @ipmioutput2);
	
	my $exit = 0;
	my $w_sensors = '';
	my $perf;
	foreach my $row ( @ipmioutput2 ){
	    if ( $row->{'state'} ne 'Nominal' && $row->{'state'} ne 'N/A' ){
			$exit = 1 if $exit < 1;
			$exit = 2 if $exit < 2 && $row->{'state'} ne 'Warning';
			#don't insert a , the first time
			$w_sensors .= ", " unless $w_sensors eq '';
			$w_sensors .= "$row->{'name'} = $row->{'state'}";
			$w_sensors .= " ($row->{'reading'})" if $verbosity > 0;
	    }
	    if ( $row->{'units'} ne 'N/A' ){
			my $val = $row->{'reading'};
			$val =~ s/(\.[0-9]*?)0+$/$1/;
			$val =~ s/\.$//;
			$perf .= qq|'$row->{'name'}'=$val |;
	    }
	}
	$perf = substr($perf, 0, -1);
	if ( $exit == 0 )
	{
	    print "OK";
	}
	elsif ( $exit == 1 )
	{
	    print "Warning [$w_sensors]";
	}
	else
	{
	    print "Critical [$w_sensors]";
	}
	print " | ", $perf if $perf ne '';
	print "\n";
	
	if ( $verbosity > 1 )
	{
	    foreach my $row (@ipmioutput2)
	    {
			#if outformat is zenoss we substitute whitespaces with underscores
			if($ipmi_outformat eq "zenoss"){
				$row->row->{'name'} =~ s/ /_/g;
			}
			print "$row->{'name'}=$row->{'reading'} (Status: $row->{'state'})\n";
	    }
	}
	exit $exit;
    }
};

# vim:ai:sw=4:sts=4:
