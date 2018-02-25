#!/usr/bin/env python
# coding: utf-8

"""
migrate from check_ipmi_sensor

    1. get the user input
    2. show the parameter information
    3. check if ipmi tools exist
    4. excute it and get result
    5. format the result and give it to user
"""

import argparse
from copy import deepcopy
from os import path as os_path
from re import compile
from subprocess import check_output, CalledProcessError

# define entire hashes
hdrmap = {
    "Record_ID"	: "id",	# FreeIPMI ...,0.7.x
    "Record ID"	: "id",	# FreeIPMI 0.8.x,... with --legacy-output
    "ID"		: "id",	# FreeIPMI 0.8.x
    "Sensor Name"	: "name",
    "Name"		: "name",	# FreeIPMI 0.8.x
    "Sensor Group"	: "type",
    "Type"		: "type",	# FreeIPMI 0.8.x
    "Monitoring Status": "state",
    "State"		: "state",	# FreeIPMI 0.8.x
    "Sensor Units"	: "units",
    "Units"		: "units",	# FreeIPMI 0.8.x
    "Sensor Reading": "reading",
    "Reading"	: "reading",	# FreeIPMI 0.8.x
    "Event"		: "event",	# FreeIPMI 0.8.x
    "Lower C"	: "lowerC",
    "Lower NC"	: "lowerNC",
    "Upper C"	: "upperC",
    "Upper NC"	: "upperNC",
    "Lower NR"	: "lowerNR",
    "Upper NR"	: "upperNR",
}

def get_fru(use_sudo=False, verbose_level=1):
    default_fre_bin = "/usr/sbin/ipmi-fru"
    if os_path.isfile(default_fre_bin):
        fru_bin = default_fre_bin
        print "come in"
    else:
        fru_bin = Command(
            ["which", "ipmi-fru"],
            use_sudo, verbose_level
        ).call()

    return Command([fru_bin, "-s"], use_sudo).call().split("\n")

def get_sel(use_sudo=False, verbose_level=1, sel_sensor_types=[], sel_exclude_sensor_types=[]):
    default_sel_bin = "/usr/sbin/ipmi-sel"
    if os_path.isfile(default_sel_bin):
        sel_bin = default_sel_bin
    else:
        sel_bin = Command(
            ["which", "ipmi-sel"],
            use_sudo, verbose_level
        ).call()

    params = [
        default_sel_bin,
        '--output-event-state',
        '--interpret-oem-data',
        '--entity-sensor-names',
        '--sensor-types=' + ",".join(sel_sensor_types),
        '--exclude-sensor-types=' + ",".join(sel_exclude_sensor_types),
    ]

    return Command(params, use_sudo, verbose_level).call().split("\n")

class Command:
    """
    call the shell command in a safe way
    """
    command = list()
    # False means haven't been excuted or failed, True means success
    excute_result = False

    def __init__(self, params=[], use_sudo=False, verbose=1):
        self.params = params
        self.verbose = verbose
        self.use_sudo = use_sudo

    def prepare(self):
        if self.use_sudo:
            self.command = ["sudo"]
            self.command.extend(self.params)
        else:
            self.command = self.params

    def call(self):
        try:
            self.prepare()
            ret = check_output(self.command)
        except CalledProcessError as excute_error:
            returncode = excute_error.returncode
            self.excute_result = False
        else:
            self.output = check_output(args)
            self.excute_result = True

        self.log()
        if not self.excute_result:
            assert False, returncode

        self.format_output()

    def log(self):
        pass

    def format_output(self):
        return self.output


VERSION = """
check_ipmi_sensor version 3.12
Copyright (C) 2009-2016 Thomas-Krenn.AG
Current updates at https://github.com/thomas-krenn/check_ipmi_sensor_v3.git
"""

EPILOG = """
Examples:
  check_ipmi_sensor -H 192.0.2.1 -U monitor -P monitor -L user
    IPMI Status: OK | 'System Temp'=30.00 'Peripheral Temp'=32.00
    'FAN 1'=2775.00 [...]
  check_ipmi_sensor -H 192.0.2.1 -U monitor -P monitor -L user -x 205
    IPMI Status: OK | 'System Temp'=30.00 'Peripheral Temp'=32.00
    'FAN 2'=2775.00 [...]
  check_ipmi_sensor -H 192.0.2.1 -U monitor -P monitor -L user -i 4,71
    IPMI Status: OK | 'System Temp'=30.00 'Peripheral Temp'=32.00
  check_ipmi_sensor -H 192.0.2.1 -U monitor -P monitor -L user -i 4 --fru
    IPMI Status: OK (0000012345) | 'System Temp'=30.00

Further information about this plugin can be found at
http://www.thomas-krenn.com/en/wiki/IPMI_Sensor_Monitoring_Plugin

Use the github repo at https://github.com/thomas-krenn/check_ipmi_sensor_v3.git
to submit patches, or suggest improvements.

Send email to the IPMI-plugin-user mailing list if you have questions regarding
use of this software. The mailing list is available at
http://lists.thomas-krenn.com/
"""
HELP = """
  [-H <hostname>]
  [-f <FreeIPMI config file>]
  [-U <username> -P <password> -L <privilege level>]
  [-O <FreeIPMI options>]
       additional options for FreeIPMI. Useful for RHEL/CentOS 5.* with
       FreeIPMI 0.5.1 (this elder FreeIPMI version does not support config
       files).
  [-i <sensor id>]
       include only sensor matching <sensor id>. Useful for cases when only
       specific sensors should be monitored. Be aware that only for the
       specified sensor errors/warnings are generated. Use -vvv option to query
       the <sensor ids>.
  [-v|-vv|-vvv]
       be verbose
         (no -v) .. single line output
         -v   ..... single line output with additional details for warnings
         -vv  ..... multi line output, also with additional details for warnings
         -vvv ..... debugging output, followed by normal multi line output
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
  [--nothresholds]
       turn off performance data thresholds from output-sensor-thresholds.
  [--noentityabsent]
       skip sensor checks for sensors that have 'noentityabsent' as event state
  [-s <ipmi-sensor output file>]
       simulation mode - test the plugin with an ipmi-sensor output redirected
       to a file.
  [--nosel]
       turn off system event log checking via ipmi-sel. If there are
       unintentional entries in SEL, use 'ipmi-sel --clear' or the -sx or -xST
       option.
  [-h]
       show this help
  [-V]
       show version information
"""


def get_ipmimonitoring_path():
    possible_file_path = [
        "/usr/sbin/ipmimonitoring",
        "/usr/bin/ipmimonitoring",
        "/usr/local/sbin/ipmimonitoring",
        "/usr/local/bin/ipmimonitoring",
    ]
    for file_path in possible_file_path:
        if os_path.isfile(file_path):
            return file_path
    assert False, "ipmimonitoring/ipmi-sensors command not found!\n"

def get_ipmi_version():
    args = [get_ipmimonitoring_path(), "-V"]
    ret = check_output(args)
    regex_compile = compile("(\d+)\.(\d+)\.(\d+)")
    return regex_compile.findall(ret)[0]

def check_thresholds():
    """
    check if output-sensor-thresholds can be used, this is supported
    since 1.2.1. Version 1.2.0 was not released, so skip the third minor
    version number
    """
    ipmi_version = get_ipmi_version()

    if ipmi_version[0] > 1 or ipmi_version[0] == 1 and ipmi_version[1] >= 2:
        return True

    return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="FreeIPMI python wrapper",
        epilog=EPILOG,
    )
    parser.add_argument(
        "-H", "--hostname",
        type=str, default="localhost",  # required=True,
        metavar="HOSTNAME",
        help="""
        hostname or IP of the IPMI interface.
        For \"-H localhost\" or if no host is specified (local computer) the Nagios/Icinga user must be allowed to run ipmimonitoring/ipmi-sensors/ipmi-sel/[ipmi-fru] with root privileges or via sudo (ipmimonitoring/ipmi-sensors/ipmi-sel/[ipmi-fru] must be able to access the IPMI devices via the IPMI system interface).
        """,
    )
    parser.add_argument(
        "-F", "--credential-file",
        type=argparse.FileType("r"),
        help="""path to the FreeIPMI configuration file.
        Only neccessary for communication via network.
        Not neccessary for access via IPMI system interface (\"-H localhost\").
        It should contain IPMI username, IPMI password, and IPMI privilege-level,
        for example:
          username monitoring
          password yourpassword
          privilege-level user
        As alternative you can use -U/-P/-L instead (see below).""",
    )
    parser.add_argument("-U", "--username", type=str, help="username")
    parser.add_argument("-P", "--password", type=str, help="password")
    parser.add_argument(
       "-L", "--previlege-level",
       type=str, default="user",
       help="""
       previlege
       IPMI username, IPMI password and IPMI privilege level, provided as
       parameters and not by a FreeIPMI configuration file. Useful for RHEL/
       Centos 5.* with FreeIPMI 0.5.1 (this elder FreeIPMI version does not
       support config files).
       Warning: with this method the password is visible in the process list.
                So whenever possible use a FreeIPMI confiugration file instead.
       """,
    )
    parser.add_argument(
       "--nosudo", action="store_true",
       help="turn off sudo usage on localhost or if ipmi host is ommited",
    )
    parser.add_argument(
        "-O", "--output-format",
        type=str, help="""
        change output format. Useful for using the plugin with other monitoring
        software than Nagios or Icinga.
          -o zenoss .. create ZENOSS compatible formatted output (output with
                       underscores instead of whitespaces and no single quotes)
        """
    )

    parser.add_argument(
       "-B", "--compat", action="store_true",
       help="""
       backward compatibility mode for FreeIPMI 0.5.* (this omits the FreeIPMI
       caching options --quiet-cache and --sdr-cache-recreate)
       """,
    )

    parser.add_argument("-T", "--sensor-types", nargs="*", help="""
        limit sensors to query based on IPMI sensor type.
        Examples for IPMI sensor types are 'Fan', 'Temperature', 'Voltage', ...
        See the output of the FreeIPMI command 'ipmi-sensors -L' and chapter
        '42.2 Sensor Type Codes and Data' of the IPMI 2.0 spec for a full list
        of possible sensor types. You can also find the full list of possible
        sensor types at https://www.thomas-krenn.com/en/wiki/IPMI_Sensor_Types
        The available types depend on your particular server and the available
        sensors there.
        """)
    parser.add_argument("-xT", "--exclude-sensor-types", nargs="*", help="""
       exclude sensors based on IPMI sensor type.
       Multiple sensor types can be specified as a comma-separated list.
    """)
    parser.add_argument("-ST", "--sel-sensor-types", nargs="*", help="""
       limit SEL entries to specific types, run 'ipmi-sel -L' for a list of
       types. All sensors are populated to the SEL and per default all sensor
       types are monitored. E.g. to limit the sensor SEL types to Memory and
       Processsor use -ST 'Memory Processor'.
    """)
    parser.add_argument("-xST", "--exclude-sel-sensor-types", nargs="*", help="""
       exclude SEL entries of specific sensor types.
       Multiple sensor types can be specified as a comma-separated list.
       """)
    parser.add_argument("-i", nargs="*", help="""
       exclude sensor matching <sensor id>. Useful for cases when unused
       sensors cannot be deleted from SDR and are reported in a non-OK state.
       Option can be specified multiple times. The <sensor id> is a numeric
       value (sensor names are not used as some servers have multiple sensors
       with the same name). Use -vvv option to query the <sensor ids>.
       """)
    parser.add_argument(
       "-D", "--lan-version", action="store_true",
       help="""
       change the protocol LAN version. Normally LAN_2_0 is used as protocol
       version if not overwritten with this option. Use 'default' here if you
       don't want to use LAN_2_0.
       """,
    )
    parser.add_argument(
       "--fru", action="store_true",
       help="""
       print the product serial number if it is available in the IPMI FRU data.
       For this purpose the tool 'ipmi-fru' is used. E.g.:
         IPMI Status: OK (9000096781)
       """,
    )
    parser.add_argument("-fc", "--fan-count", type=int, help="""
       number of fans that should be active. If the number of current active
       fans reported by IPMI is smaller than <num fans> then a Warning state
       is returned.
    """)
    parser.add_argument("-O", "--options", nargs="*", help="free ipmi options")

    parser.add_argument("-v", "--verbose", action="count", help="verbose level")
    parser.add_argument("-V", "--version", action="version", version=VERSION)

    args = parser.parse_args()

    username, password, previlege = None, None, None
    hostname = None
    use_sudo = None
    verbose_level = 1
    use_ipmi_sensors = True
    use_thresholds = check_thresholds()

    if args.nosudo:
        use_sudo = False

    if args.verbose:
        verbose_level = args.verbose

    # get_sel(use_sudo=True)

    base_command = [get_ipmimonitoring_path()]
    if hostname == "localhost":
	# If host is omitted localhost is assumed, if not turned off sudo is used
        if use_sudo is None:
            base_command.insert(0, "sudo")
    else:
        base_command.append("-h")
        base_command.append(args.hostname)

    if args.credential_file:
        if not os_path.isfile(args.credential_file):
            assert False, "credential file doesn't exist"
        base_command.append("--config-file")
        base_command.append(args.credential_file)
    elif args.username and args.password and args.previlege:
        base_command.append("-u")
        base_command.append(args.username)
        base_command.append("-p")
        base_command.append(args.password)
        base_command.append("-l")
        base_command.append(args.previlege)

    print dir(args)
    if args.sensor_types:
        base_command.append("-g")
        base_command.append(",".join(args.sensor_types))

    if args.exclude_sensor_types:
        base_command.append("--exclude-sensor-types")
        base_command.append(",".join(args.exclude_sensor_types))

    get_status_command = deepcopy(base_command)

    if not args.compat:
        get_status_command.append("--quiet-cache")
        get_status_command.append("--sdr-cache-recreate")

    ipmi_version = get_ipmi_version()
    if ipmi_version[0] > 0 or ipmi_version[0] == 0 and ipmi_version[1] > 7:
	# since version 0.8 it is necessary to add the legacy option
        get_status_command.append("--interpret-oem-data")

    if ipmi_version[0] == 0 and ipmi_version[1] > 7 and "legacy-output" not in args.options:
        get_status_command.append("--legacy-output")

    if not args
	#if not stated otherwise we use protocol lan version 2 per default
	if(!defined($lanVersion)){
		$lanVersion = 'LAN_2_0';
	}
	if($lanVersion ne 'default' && defined $ipmi_host && $ipmi_host ne 'localhost'){
		push @getstatus, "--driver-type=$lanVersion";
		if(!$no_sel){
			push @selcmd, "--driver-type=$lanVersion";
		}
		if($use_fru){
			push @frucmd, "--driver-type=$lanVersion";
		}
	}
	if($use_thresholds && !$no_thresholds){
		push @getstatus, '--output-sensor-thresholds';
	}
