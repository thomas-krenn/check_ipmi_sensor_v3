#!/usr/bin/perl
#
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use IPC::Run qw( run ); #interact with processes
################################################################################
sub get_help{
	return <<EOT;
  [-O <FreeIPMI options>]
       additional options for FreeIPMI. Useful for RHEL/CentOS 5.* with
       FreeIPMI 0.5.1 (this elder FreeIPMI version does not support config
       files).
  [-b]
       backward compatibility mode for FreeIPMI 0.5.* (this omits the FreeIPMI
       caching options --quiet-cache and --sdr-cache-recreate)
  [-T <sensor type(s)>]
       limit sensors to query based on IPMI sensor type.
       Examples for IPMI sensor types are 'Fan', 'Temperature', 'Voltage', ...
       See the output of the FreeIPMI command 'ipmi-sensors -L' and chapter
       '42.2 Sensor Type Codes and Data' of the IPMI 2.0 spec for a full list
       of possible sensor types. You can also find the full list of possible
       sensor types at https://www.thomas-krenn.com/en/wiki/IPMI_Sensor_Types
       The available types depend on your particular server and the available
       sensors there.
       Multiple sensor types can be specified as a comma-separated list.
  [-ST <SEL sensor type(s)>]
       limit SEL entries to specific types, run 'ipmi-sel -L' for a list of
       types. All sensors are populated to the SEL and per default all sensor
       types are monitored. E.g. to limit the sensor SEL types to Memory and
       Processsor use -ST 'Memory,Processor'.
  [-x <sensor id>]
       exclude sensor matching <sensor id>. Useful for cases when unused
       sensors cannot be deleted from SDR and are reported in a non-OK state.
       Option can be specified multiple times. The <sensor id> is a numeric
       value (sensor names are not used as some servers have multiple sensors
       with the same name). Use -vvv option to query the <sensor ids>.
  [-xT <sensor type(s)>]
       exclude sensors based on IPMI sensor type.
       Multiple sensor types can be specified as a comma-separated list.
  [-xST <SEL sensor type(s)]
       exclude SEL entries of specific sensor types.
       Multiple sensor types can be specified as a comma-separated list.
  [-i <sensor id>]
       include only sensor matching <sensor id>. Useful for cases when only
       specific sensors should be monitored. Be aware that only for the
       specified sensor errors/warnings are generated. Use -vvv option to query
       the <sensor ids>.
  [-o]
       change output format. Useful for using the plugin with other monitoring
       software than Nagios or Icinga.
         -o zenoss .. create ZENOSS compatible formatted output (output with
                      underscores instead of whitespaces and no single quotes)
  [-D]
       change the protocol LAN version. Normally LAN_2_0 is used as protocol
       version if not overwritten with this option. Use 'default' here if you
       don't want to use LAN_2_0.
  [-fc <num fans>]
       number of fans that should be active. If the number of current active
       fans reported by IPMI is smaller than <num fans> then a Warning state
       is returned.
  [--fru]
       print the product serial number if it is available in the IPMI FRU data.
       For this purpose the tool 'ipmi-fru' is used. E.g.:
         IPMI Status: OK (9000096781)
  [--nosel]
       turn off system event log checking via ipmi-sel. If there are
       unintentional entries in SEL, use 'ipmi-sel --clear' or the -sx or -xST
       option.
  [-sx|--selexclude <sel exclude file>]
       use a sel exclude file to exclude entries from the system event log.
       Specify name and type pipe delimitered in this file to exclude an entry,
       for example: System Chassis Chassis Intru|Physical Security
       To get valid names and types use the -vvv option and take a look at:
       debug output for sel (-vvv is set). Don't use name and type from the
       web interface as sensor descriptions are not complete there.
  [-xx|--sexclude <exclude file>]
       use an exclude file to exclude sensors.
       Specify name and type pipe delimitered in this file to exclude a sensor,
       To get valid names and types use the -vvv option.
  [--nosudo]
       turn off sudo usage on localhost or if ipmi host is ommited.
  [--nothresholds]
       turn off performance data thresholds from output-sensor-thresholds.
  [--noentityabsent]
       skip sensor checks for sensors that have 'noentityabsent' as event state
  [-s <ipmi-sensor output file>]
       simulation mode - test the plugin with an ipmi-sensor output redirected
       to a file.
  [-h]
       show this help
  [-V]
       show version information

EOT
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



# Excludes a name and type pair if it is present in the given file, pipe
# delimitered.
# @return 1 if name should be skipped, 0 if not
sub exclude_with_file{
	my $file_name = shift;
	my $name = shift;
	my $type = shift;
	my @xlist;
	my $skip = 0;
	if($file_name){
		if(!(open (FH, "< $file_name"))){
			print "-> Reading exclude file $file_name failed with: $!.\n";
			exit(3);
		};
		@xlist = <FH>;
	}
	foreach my $exclude (@xlist){
		my @curr_exclude = map { s/^\s*//; s/\s*$//; $_; } split(/\|/,$exclude);
		if($curr_exclude[0] eq $name &&
		$curr_exclude[1] eq $type){
			$skip = 1;
		}
	}
	close FH;
	return $skip;
}

MAIN: {
	$| = 1; #force a flush after every write or print
	my @ARGV_SAVE = @ARGV;#keep args for verbose output
	my ($show_help, $show_version);
	my ($ipmi_host, $ipmi_user, $ipmi_password, $ipmi_privilege_level, $ipmi_config_file, $ipmi_outformat);
	my (@freeipmi_options, $freeipmi_compat);
	my (@ipmi_sensor_types, @ipmi_exclude_sensor_types, @ipmi_xlist, @ipmi_ilist);
	my (@ipmi_version);
	my $ipmi_sensors = 0;#states to use ipmi-sensors instead of ipmimonitoring
	my $fan_count;#number of fans that should be installed in unit
	my $lanVersion;#if desired use a different protocol version
	my $abort_text = '';
	my $zenoss = 0;
	my @sel_sensor_types;
	my @exclude_sel_sensor_types;
	my $sel_issues_present = 0;
	my $simulate = '';
	my ($use_fru, $no_sel, $no_sudo, $use_thresholds, $no_thresholds, $sel_xfile, $s_xfile, $no_entity_absent);

	#read in command line arguments and init hash variables with the given values from argv
	if ( !( GetOptions(
		'H|host=s'			=> \$ipmi_host,
		'f|config-file=s'	=> \$ipmi_config_file,
		'U|user=s'			=> \$ipmi_user,
		'P|password=s'  	=> \$ipmi_password,
		'L|privilege-level=s'	=> \$ipmi_privilege_level,
		'O|options=s'		=> \@freeipmi_options,
		'b|compat'			=> \$freeipmi_compat,
		'T|sensor-types=s'	=> \@ipmi_sensor_types,
		'xT|exclude-sensor-types=s'	=> \@ipmi_exclude_sensor_types,
		'ST|sel-sensor-types=s'	=> \@sel_sensor_types,
		'xST|exclude-sel-sensor-types=s'	=> \@exclude_sel_sensor_types,
		'fru'				=> \$use_fru,
		'nosel'				=> \$no_sel,
		'nosudo'			=> \$no_sudo,
		'nothresholds'			=> \$no_thresholds,
		'noentityabsent'	=> \$no_entity_absent,
		'v|verbosity'		=> \$verbosity,
		'vv'				=> sub{$verbosity=2},
		'vvv'				=> sub{$verbosity=3},
		'x|exclude=s'		=> \@ipmi_xlist,
		'sx|selexclude=s'	=> \$sel_xfile,
		'xx|sexclude=s'		=> \$s_xfile,
		'i|include=s'		=> \@ipmi_ilist,
		'o|outformat=s'		=> \$ipmi_outformat,
		'fc|fancount=i'		=> \$fan_count,
		'D=s'				=> \$lanVersion,
		's=s'				=> \$simulate,
		'h|help'			=>
			sub{print STDOUT get_version();
				print STDOUT "\n";
				print STDOUT get_usage();
				print STDOUT "\n";
				print STDOUT get_help();
				exit(0)
			},
		'V|version'			=>
			sub{
				print STDOUT get_version();
				exit(0);
			},
		'usage|?'			=>
			sub{print STDOUT get_usage();
				exit(3);
			}
	) ) ){
		usage(1);#call usage if GetOptions failed
	}
	usage(1) if @ARGV;#print usage if unknown arg list is left

###############################################################################
# verify if all mandatory parameters are set and initialize various variables
	#\s defines any whitespace characters
	#first join the list, then split it at whitespace ' '
	#also cf. http://perldoc.perl.org/Getopt/Long.html#Options-with-multiple-values
	@freeipmi_options = split(/\s+/, join(' ', @freeipmi_options)); # a bit hack, shell word splitting should be implemented...
	@ipmi_sensor_types = split(/,/, join(',', @ipmi_sensor_types));
	@ipmi_exclude_sensor_types = split(/,/, join(',', @ipmi_exclude_sensor_types));
	@sel_sensor_types = split(/,/, join(',', @sel_sensor_types));
	@exclude_sel_sensor_types = split(/,/, join(',', @exclude_sel_sensor_types));
	@ipmi_xlist = split(/,/, join(',', @ipmi_xlist));
	@ipmi_ilist = split(/,/, join(',', @ipmi_ilist));

	#check for zenoss output
	if(defined $ipmi_outformat && $ipmi_outformat eq "zenoss"){
		$zenoss = 1;
	}

	# Per default monitor all sensor types, use -ST to specify your sensor types
	if(!@sel_sensor_types){
		@sel_sensor_types = ('all');
	}
    # If -xST has not been set, set this array to empty.
	if(!@exclude_sel_sensor_types){
		@exclude_sel_sensor_types = ('');
	}

	# copy command for fru usage
	my @frucmd;
	if($use_fru){
		@frucmd = @basecmd
	}
	my @selcmd = @basecmd;



	if(@freeipmi_options){
		push @basecmd, @freeipmi_options;
	}

	#keep original basecmd for later usage
	my @getstatus = @basecmd;


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
	my @fruoutput;
	if($use_fru){
		@fruoutput = get_fru(\@frucmd, $verbosity);
	}
	my $seloutput;
	if(!$no_sel){
		$seloutput = parse_sel(\@selcmd, $verbosity, $sel_xfile, \@sel_sensor_types, \@exclude_sel_sensor_types);
	}
################################################################################
# print debug output when verbosity is set to 3 (-vvv)
	if ( $verbosity == 3 ){
		my $ipmicommandversion;
		run [$IPMICOMMAND, '-V'], '2>&1', '|', ['head', '-n', 1], '&>', \$ipmicommandversion;
		#remove trailing newline with chomp
		chomp $ipmicommandversion;
		print "------------- debug output for sensors (-vvv is set): ------------\n";
		print "  script was executed with the following parameters:\n";
		print "    $0 ", join(' ', @ARGV_SAVE), "\n";
		print "  check_ipmi_sensor version:\n";
		print "    $check_ipmi_sensor_version\n";
		print "  FreeIPMI version:\n";
		print "    $ipmicommandversion\n";
		print "  FreeIPMI was executed with the following parameters:\n";
		print "    ", join(' ', @getstatus), "\n";
		print "  FreeIPMI return code: $returncode\n";
		print "  output of FreeIPMI:\n";
		print "$ipmioutput\n";
		print "--------------------- end of debug output ---------------------\n";
	}

################################################################################
# generate main output
	if ( $returncode != 0 ){
		print "$ipmioutput\n";
		print "-> Execution of $IPMICOMMAND failed with return code $returncode.\n";
		print "-> $IPMICOMMAND was executed with the following parameters:\n";
		print "   ", join(' ', @getstatus), "\n";
		exit(3);
	}
	else{
		my @outputRows;
		if(defined($ipmioutput)){
			@outputRows = split('\n', $ipmioutput);
		}
		if(!defined($ipmioutput) || scalar(@outputRows) == 1){
			print "-> Your server seems to be powered off.";
			print " (Execution of FreeIPMI returned an empty output or only 1 header row!)\n";
			print "-> $IPMICOMMAND was executed with the following parameters:\n";
			print "   ", join(' ', @getstatus), "\n";
			exit(3);
		}
		#print desired filter types
		if ( @ipmi_sensor_types ){
			print "Sensor Type(s) ", join(', ', @ipmi_sensor_types), " Status: ";
		}
		else{
			print "IPMI Status: ";
		}
		#split at newlines, fetch array with lines of output
		my @ipmioutput = split('\n', $ipmioutput);

		#remove sudo errors and warnings like they appear on dns resolving issues
		@ipmioutput = map { /^sudo:/ ? () : $_ } @ipmioutput;

		#remove leading and trailing whitespace characters, split at the pipe delimiter
		@ipmioutput = map { [ map { s/^\s*//; s/\s*$//; $_; } split(m/\|/, $_) ] } @ipmioutput;

		#shift out the header as it is the first line
		my $header = shift @ipmioutput;
		if(!defined($header)){
			print "$ipmioutput\n";
			print " FreeIPMI returned an empty header map (first line)";
			if(@ipmi_sensor_types){
				print " FreeIPMI could not find any sensors for the given sensor type (option '-T').\n";
			}
			exit(3);
		}
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
			if(!(exclude_with_file($s_xfile, $row{'name'}, $row{'type'}))){
				push @ipmioutput2, \%row;
			}
		}
		#create hash with sensor name an 1
		my %ipmi_xlist = map { ($_, 1) } @ipmi_xlist;
		#filter out the desired sensor values
		@ipmioutput2 = grep(!exists $ipmi_xlist{$_->{'id'}}, @ipmioutput2);
		#check for an include list
		if(@ipmi_ilist){
			my %ipmi_ilist = map { ($_, 1) } @ipmi_ilist;
			#only include sensors from include list
			@ipmioutput2 = grep(exists $ipmi_ilist{$_->{'id'}}, @ipmioutput2);
		}
		#start with main output
		my $exit = 0;
		my $w_sensors = '';#sensors with warnings
		my $sel_w_sensors = '';#verbose output for sel entries with warnings
		my $perf = '';#performance sensor
		my $curr_fans = 0;
		foreach my $row ( @ipmioutput2 ){
			if( $zenoss ){
				$row->{'name'} =~ s/ /_/g;
			}
			my $check_sensor_state = 1;
			if($no_entity_absent && ($row->{'event'} eq '\'Entity Absent\'')){
				$check_sensor_state = 0;
			}
			#check for warning sensors
			if($check_sensor_state && ($row->{'state'} ne 'Nominal' && $row->{'state'} ne 'N/A')){
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
			if($check_sensor_state && ($row->{'units'} ne 'N/A')){
				my $val = $row->{'reading'};
				my $perf_data;
				my $perf_thresholds;
				if($zenoss){
					$perf_data = $row->{'name'}."=".$val;
				}
				else{
					$perf_data = "'".$row->{'name'}."'=".$val;
				}
				if($use_thresholds && !$no_thresholds){
					if(($row->{'lowerNC'} ne 'N/A') && ($row->{'upperNC'} ne 'N/A')){
						$perf_thresholds = $row->{'lowerNC'}.":".$row->{'upperNC'}.";";
					}
					elsif(($row->{'lowerNC'} ne 'N/A') && ($row->{'upperNC'} eq 'N/A')){
						$perf_thresholds = $row->{'lowerNC'}.":;";
					}
					elsif(($row->{'lowerNC'} eq 'N/A') && ($row->{'upperNC'} ne 'N/A')){
						$perf_thresholds = "~:".$row->{'upperNC'}.";";
					}
					elsif(($row->{'lowerNC'} eq 'N/A') && ($row->{'upperNC'} eq 'N/A')){
						$perf_thresholds = ";";
					}
					if(($row->{'lowerC'} ne 'N/A') && ($row->{'upperC'} ne 'N/A')){
						$perf_thresholds .= $row->{'lowerC'}.":".$row->{'upperC'};
					}
					elsif(($row->{'lowerC'} ne 'N/A') && ($row->{'upperC'} eq 'N/A')){
						$perf_thresholds .= $row->{'lowerC'}.":";
					}
					elsif(($row->{'lowerC'} eq 'N/A') && ($row->{'upperC'} ne 'N/A')){
						$perf_thresholds .= "~:".$row->{'upperC'};
					}
					# Add thresholds to performance data
					if(($row->{'lowerNC'} ne 'N/A') || ($row->{'upperNC'} ne 'N/A') ||
					($row->{'lowerC'} ne 'N/A') || ($row->{'upperC'} ne 'N/A')){
						$perf_data .= ";".$perf_thresholds;
					}
				}
				$perf .= $perf_data." ";
			}
			if( $row->{'type'} eq 'Fan' && $row->{'reading'} ne 'N/A' ){
				$curr_fans++;
			}
		}
		foreach my $row (@{$seloutput}){
			if( $zenoss ){
				$row->{'name'} =~ s/ /_/g;
			}
			if ($row->{'state'} ne 'Nominal'){
				$sel_issues_present += 1;
				$exit = 1 if $exit < 1;
				$exit = 2 if $exit < 2 && $row->{'state'} ne 'Warning';
				if( $verbosity ){
					$sel_w_sensors .= ", " unless $sel_w_sensors eq '';
					$sel_w_sensors .= "($row->{'name'} = $row->{'state'},";
					$sel_w_sensors .= " $row->{'type'}," ;
					$sel_w_sensors .= " $row->{'event'})" ;
				}
			}
		}
		if ( $sel_issues_present ){
			$w_sensors .= ", " unless $w_sensors eq '';
			if ( $sel_issues_present == 1 ){
				$w_sensors .= "1 system event log (SEL) entry present";
			}else{
				$w_sensors .= $sel_issues_present." system event log (SEL) entries present";
			}
			if( $verbosity ){
				$w_sensors .= " - details: ";
				$w_sensors .= $sel_w_sensors;
				$w_sensors .= " - fix the reported issues and clear your SEL";
				$w_sensors .= " or exclude specific SEL entries using the -sx or -xST option";
			}
		}
		#now check if num fans equals desired unit fans
		if( $fan_count ){
			if( $curr_fans < $fan_count ){
				$exit = 1 if $exit < 1;
				$w_sensors .= ", " unless $w_sensors eq '';
				$w_sensors .= "Fan = Warning";
				if( $verbosity ){
					$w_sensors .= " ($curr_fans)" ;
				}
			}
		}
		#check for the FRU serial number
		my @server_serial;
		my $serial_number;
		if( $use_fru ){
			@server_serial = grep(/Product Serial Number/,@fruoutput);
			if(@server_serial){
				$server_serial[0] =~ m/(\d+)/;
				$serial_number = $1;
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
		if( $use_fru && defined($serial_number)){
			print " ($serial_number)";
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
