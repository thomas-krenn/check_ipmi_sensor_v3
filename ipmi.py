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

def get_fru(use_sudo=False, verbose_level=1):
    default_fre_bin = "/usr/sbin/ipmi-fru"
    if os_path.isfile(default_fre_bin):
        fru_bin = default_fre_bin
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
            self.output = ret
            self.excute_result = True

        self.log()
        if not self.excute_result:
            assert False, returncode

        return self.format_output()

    def log(self):
        pass

    def format_output(self):
        return self.output


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
       "-L", "--previlege",
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
    parser.add_argument("-OPT", "--options", nargs="*", help="free ipmi options")

    parser.add_argument(
        "--no-thresholds", action="store_true",
        help="turn off performance data thresholds from output-sensor-thresholds.")

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

    ipmi_sensors = False
    if ipmi_version[0] == 0 and ipmi_version[1] > 7 and "legacy-output" not in args.options:
        get_status_command.append("--legacy-output")
    if ipmi_version[0] > 0 and (not args.options or "lagacy-output" not in args.options):
        get_status_command[0] = get_status_command[0].replace("monitoring", "-sensors")
        ipmi_sensors = True

    if ipmi_sensors:
        get_status_command.append("--output-sensor-state")
        get_status_command.append("--ignore-not-available-sensors")

    lan_version = ""
    if not args.lan_version:
        lan_version = "LAN_2_0"
    if lan_version != "default" and args.hostname != "localhost":
        get_status_command.append("--driver-type={}".format(lan_version))

    if use_thresholds and not args.no_thresholds:
        get_status_command.append('--output-sensor-thresholds')

    # print get_status_command
    ret = Command(get_status_command, use_sudo, verbose_level).call()
    print ret
