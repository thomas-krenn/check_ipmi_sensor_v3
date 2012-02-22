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
#   http://tldp.org/LDP/abs/html/ (Advanced Bash-Scripting Guide)
#   http://www.gnu.org/software/gawk/manual/ (Gawk: Effective AWK Programming)
#   http://de.wikibooks.org/wiki/Awk (awk Wikibook, in German)
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
################################################################################
# set text variables
sub get_version
{
    return <<EOT;
check_ipmi_sensor version 3.1-dev 2012-02-22
Copyright (C) 2009-2012 Thomas-Krenn.AG
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
  -H <hostname>
       hostname or IP of the IPMI interface.
       For \"-H localhost\" the Nagios/Icinga user must be allowed to execute
       ipmimonitoring with root privileges via sudo (ipmimonitoring must be
       able to access the IPMI devices via the IPMI system interface).
  [-f <FreeIPMI config file>]
       path to the FreeIPMI configuration file.
       Only neccessary for communication via network.
       Not neccessary for access via IPMI system interface (\"-H localhost\").
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
  [-v]
       be verbose
         (no -v) .. single line output
         -v   ..... single line output with additional details for warnings
         -vv  ..... multi line output, also with additional details for warnings
         -vvv ..... debugging output, followed by normal multi line output
  [-o]
       change output format. Useful for using the plugin with other monitoring
       software than Nagios or Icinga.
         -o zenoss .. create ZENOSS compatible formatted output (output with
                      underscores instead of whitespaces and no single quotes)
  [-h]
       show this help
  [-V]
       show version information

Further information about this plugin can be found at
http://www.thomas-krenn.com/en/oss/ipmi-plugin.html

Send email to the IPMI-plugin-user mailing list if you have questions regarding
use of this software, to submit patches, or suggest improvements.
The mailing list is available at http://lists.thomas-krenn.com/
EOT
}
sub usage
{
    my ($arg) = @_; #the list of inputs
    my ($exitcode);
    if ( defined $arg ){
		if ( $arg =~ m/^\d+$/ ){
	    	$exitcode = $arg;
		}
		else{
			print STDOUT $arg, "\n";
	    	$exitcode = 1;
		}
    }
    print STDOUT get_usage();
    exit($exitcode) if defined $exitcode;
}
################################################################################
# set ipmimonitoring path
our $MISSING_COMMAND_TEXT = '';
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
	$MISSING_COMMAND_TEXT = " ipmimonitoring command not found";
}

# Identify the version of the ipmi-tool
sub get_ipmi_version{
	my @ipmi_version_output = '';
	my $ipmi_version = '';
	@ipmi_version_output = `$IPMICOMMAND -V`;
	$ipmi_version = shift(@ipmi_version_output);
	$ipmi_version =~ /(\d+)\.(\d+)\.(\d+)/;	
	@ipmi_version_output = ();
	push @ipmi_version_output,$1,$2,$3;
	return @ipmi_version_output;
}

sub simulate{
	my $output = '';
	my $simul_file = $_[0];
	if( !defined $simul_file || (-x '\"'.$simul_file.'\"')){
		print "DEBUG: Using simulation file: $simul_file\n";
		print "Error: Simulation file with ipmi output not found.\n";
		exit(3);
	}
	return ($output = `cat $simul_file`);	
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
	'Reading'		=> 'reading',# FreeIPMI 0.8.x
	'Event'			=> 'event',	# FreeIPMI 0.8.x
);

our $verbosity = 0;

MAIN: {
    $| = 1; #force a flush after every write or print
    my @ARGV_SAVE = @ARGV;#keep args for verbose output
    my ($show_help, $show_version);
    my ($ipmi_host, $ipmi_user, $ipmi_password, $ipmi_privilege_level, $ipmi_config_file, $ipmi_outformat);
    my (@freeipmi_options, $freeipmi_compat);
    my (@ipmi_sensor_types, @ipmi_xlist);
    my (@ipmi_version);
    my $ipmi_sensors = 0;#states to use ipmi-sensors instead of ipmimonitoring
	my $abort_text = '';
	my $zenoss = 0;
	my $simulate = '';

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
		'vvv'				=> sub{$verbosity=3},
		'x|exclude=s'		=> \@ipmi_xlist,
		'o|outformat=s'		=> \$ipmi_outformat,
		's=s'					=>\$simulate,
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
		'usage|?'					=> 
			sub{print STDOUT get_usage();
				exit(3);
			}	
	) ) ){
		usage(1);#call usage if GetOptions failed
	}
	usage(1) if @ARGV;#print usage if unknown arg list is left
	
################################################################################
# check for ipmimonitoring or ipmi-sensors. Since version > 0.8 ipmi-sensors is used
# if '--legacy-output' is given ipmi-sensors cannot be used	

	if( $MISSING_COMMAND_TEXT ne "" ){
		print STDOUT "Error:$MISSING_COMMAND_TEXT";
		exit(3);
	}
	else{
		@ipmi_version = get_ipmi_version();
		if( $ipmi_version[0] > 0 && (grep(/legacy\-output/,@freeipmi_options)) == 0){
			$IPMICOMMAND =~ s/ipmimonitoring/ipmi-sensors/;	
			$ipmi_sensors = 1;
		}
		if( $ipmi_version[0] > 0 && (grep(/legacy\-output/,@freeipmi_options)) == 1){
			print "Error: Cannot use ipmi-sensors with option \'--legacy-output\'. Remove it to work correctly.\n";
			exit(3);
		}
	}

###############################################################################
# verify if all mandatory parameters are set and initialize various variables
	#\s defines any whitespace characters
	#first join the list, then split it at whitespace ' '
	#also cf. http://perldoc.perl.org/Getopt/Long.html#Options-with-multiple-values
    @freeipmi_options = split(/\s+/, join(' ', @freeipmi_options)); # a bit hack, shell word splitting should be implemented...
    @ipmi_sensor_types = split(/,/, join(',', @ipmi_sensor_types));
    @ipmi_xlist = split(/,/, join(',', @ipmi_xlist));
    
    #check for zenoss output    
    if(defined $ipmi_outformat && $ipmi_outformat eq "zenoss"){
    	$zenoss = 1;
    }

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
    #since version 0.8 it is possible to interpret OEM data
    if( ($ipmi_version[0] == 0 && $ipmi_version[1] > 7) ||
			$ipmi_version[0] > 0){
				push @getstatus, '--interpret-oem-data';
	}
	#since version 0.8 it is necessary to add the legacy option
	if( ($ipmi_version[0] == 0 && $ipmi_version[1] > 7) && (grep(/legacy\-output/,@freeipmi_options) == 0)){
			push @getstatus, '--legacy-output';
	}
	#if ipmi-sensors is used show the state of sensors an ignore N/A
	if($ipmi_sensors){
		push @getstatus, '--output-sensor-state', '--ignore-not-available-sensors';
	}    		

################################################################################
	#execute status command and redirect stdout and stderr to ipmioutput
	my $ipmioutput;
	my $returncode;
	if(!$simulate){
		run \@getstatus, '>&', \$ipmioutput;
	    #the upper eight bits contain the error condition (exit code)
    	#see http://perldoc.perl.org/perlvar.html#Error-Variables
    	$returncode = $? >> 8;
	}
	else{
		$ipmioutput = simulate($simulate);
		print "DEBUG: Using simulation mode\n";
		$returncode = 0;
	}
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
	
		my $exit = 0;		
		my $w_sensors = '';#sensors with warnings		
		my $perf = '';#performance sensor		
		
		foreach my $row ( @ipmioutput2 ){
			if( $zenoss ){
				$row->{'name'} =~ s/ /_/g;
			}
			#check for warning sensors
	    	if ( $row->{'state'} ne 'Nominal' && $row->{'state'} ne 'N/A' ){
				$exit = 1 if $exit < 1;
				$exit = 2 if $exit < 2 && $row->{'state'} ne 'Warning';
				#don't insert a , the first time
				$w_sensors .= ", " unless $w_sensors eq '';
				$w_sensors .= "$row->{'name'} = $row->{'state'}";
				if( $verbosity ){
					if( $row->{'reading'} ne 'N/A'){
						$w_sensors .= " ($row->{'reading'})" ;
					}
					else{
						$w_sensors .= " ($row->{'event'})";
					}
				}		
	    	}
	    	if ( $row->{'units'} ne 'N/A' ){
				my $val = $row->{'reading'};
				if($zenoss){
					$perf .= qq|$row->{'name'}=$val |;
				}
				else{
					$perf .= qq|'$row->{'name'}'=$val |;	
				}				
	    	}
		}
		$perf = substr($perf, 0, -1);#cut off the last chars
		if ( $exit == 0 ){
		    print "OK";
		}
		elsif ( $exit == 1 ){
		    print "Warning [$w_sensors]";
		}
		else{
			print "Critical [$w_sensors]";
		}
		print " | ", $perf if $perf ne '';
		print "\n";
	
		if ( $verbosity > 1 ){
	    	foreach my $row (@ipmioutput2){
	    		if( $row->{'state'} eq 'N/A'){
	    			next;
	    		}	    		
	    		elsif( $row->{'reading'} ne 'N/A'){
					print "$row->{'name'} = $row->{'reading'} ";
	    		}
	    		elsif( $row->{'event'} ne 'N/A'){
	    			print "$row->{'name'} = $row->{'event'} ";	
	    		}
	    		else{
	    			next;
	    		}
				print "(Status: $row->{'state'})\n";
	    	}
		}
		exit $exit;
	}
};

# vim:ai:sw=4:sts=4:
