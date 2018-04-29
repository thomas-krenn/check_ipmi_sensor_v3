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
from subprocess import check_output, CalledProcessError

from const import VERSION, EPILOG
from format_func import format_ipmi_sensor_result, ipmi_sensor_netxms_format
from format_func import format_sel_result, format_fru_result
from utils import get_ipmimonitoring_path, get_ipmi_version, check_thresholds
from utils import get_fru_command, get_sel_command
from utils import Command


def main():
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
       "--nosel", action="store_true",
       help="""
       turn off system event log checking via ipmi-sel. If there are
       unintentional entries in SEL, use 'ipmi-sel --clear' or the -sx or -xST
       option.
       """
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

    parser.add_argument("-T", "--sensor-types", nargs="*", default=[], help="""
        limit sensors to query based on IPMI sensor type.
        Examples for IPMI sensor types are 'Fan', 'Temperature', 'Voltage', ...
        See the output of the FreeIPMI command 'ipmi-sensors -L' and chapter
        '42.2 Sensor Type Codes and Data' of the IPMI 2.0 spec for a full list
        of possible sensor types. You can also find the full list of possible
        sensor types at https://www.thomas-krenn.com/en/wiki/IPMI_Sensor_Types
        The available types depend on your particular server and the available
        sensors there.
        """)
    parser.add_argument("-xT", "--exclude-sensor-types", nargs="*", default=[], help="""
       exclude sensors based on IPMI sensor type.
       Multiple sensor types can be specified as a comma-separated list.
    """)
    parser.add_argument("-ST", "--sel-sensor-types", nargs="*", default=[], help="""
       limit SEL entries to specific types, run 'ipmi-sel -L' for a list of
       types. All sensors are populated to the SEL and per default all sensor
       types are monitored. E.g. to limit the sensor SEL types to Memory and
       Processsor use -ST 'Memory Processor'.
    """)
    parser.add_argument("-xST", "--exclude-sel-sensor-types", nargs="*", default=[], help="""
       exclude SEL entries of specific sensor types.
       Multiple sensor types can be specified as a comma-separated list.
       """)
    parser.add_argument("-i", nargs="*", default=[], help="""
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
    parser.add_argument("-OPT", "--options", nargs="*", default=[], help="free ipmi options")

    parser.add_argument(
        "--no-thresholds", action="store_true",
        help="turn off performance data thresholds from output-sensor-thresholds.")

    parser.add_argument(
        "-r", "--record-ids", type=str,
        help="Show specific sensors by record id. Accepts comma separated lists ")

    parser.add_argument(
        "--sensor-name", type=str,
        help="Show specific sensors by record name.")

    parser.add_argument(
        "--list-sensor-types", action="store_true", help="List sensor types.")

    parser.add_argument("-v", "--verbose", action="count", help="verbose level")
    parser.add_argument("-V", "--version", action="version", version=VERSION)

    args = parser.parse_args()

    username, password, previlege = None, None, None
    hostname = None
    use_sudo = None
    verbose_level = 1

    if args.nosudo:
        use_sudo = False

    if args.verbose:
        verbose_level = args.verbose

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

    monitor_status_command = deepcopy(base_command)
    sel_command = deepcopy(base_command)
    fru_command = deepcopy(base_command)

    if not args.compat:
        monitor_status_command.append("--quiet-cache")
        monitor_status_command.append("--sdr-cache-recreate")

    ipmi_version = get_ipmi_version()
    if ipmi_version[0] > 0 or ipmi_version[0] == 0 and ipmi_version[1] > 7:
	# since version 0.8 it is necessary to add the legacy option
        monitor_status_command.append("--interpret-oem-data")

    ipmi_sensors = False
    if ipmi_version[0] == 0 and ipmi_version[1] > 7 and "legacy-output" not in args.options:
        monitor_status_command.append("--legacy-output")
    if ipmi_version[0] > 0 and (not args.options or "lagacy-output" not in args.options):
        monitor_status_command[0] = monitor_status_command[0].replace("monitoring", "-sensors")
        ipmi_sensors = True

    if ipmi_sensors:
        monitor_status_command.append("--output-sensor-state")
        monitor_status_command.append("--ignore-not-available-sensors")

    lan_version = ""
    if not args.lan_version:
        lan_version = "LAN_2_0"
    if lan_version != "default" and args.hostname != "localhost":
        monitor_status_command.append("--driver-type={}".format(lan_version))
        if not args.nosel:
            sel_command.append("--driver-type={}".format(lan_version))
        if not args.fru:
            fru_command.append("--driver-type={}".format(lan_version))

    use_thresholds = check_thresholds()
    filter_thresholds = False
    if use_thresholds:
        monitor_status_command.append('--output-sensor-thresholds')
    if args.no_thresholds:
        # remove all the thresholds
        filter_thresholds = True

    if args.record_ids:
        monitor_status_command.append('--record-ids={}'.format(args.record_ids))

    ret = Command(monitor_status_command, use_sudo, verbose_level).call()
    if args.sensor_name:
        print ipmi_sensor_netxms_format(ret, filter_thresholds=filter_thresholds, sensor_name=args.sensor_name)
    elif args.list_sensor_types:
        print ipmi_sensor_netxms_format(ret, filter_thresholds=filter_thresholds, list_sensor_types=True)
    else:
        print ipmi_sensor_netxms_format(ret, filter_thresholds=filter_thresholds)

    # print format_ipmi_sensor_result(ret)
    # sel_command_last = get_sel_command(
    #     sel_command,
    #     sel_sensor_types=args.sel_sensor_types,
    #     sel_exclude_sensor_types=args.exclude_sel_sensor_types,
    # )
    # sel_ret = Command(
    #     sel_command_last,
    #     use_sudo,
    #     verbose_level,
    # ).call()
    # # print format_sel_result(sel_ret)

    # fru_command_last = get_fru_command(fru_command)
    # fru_ret = Command(
    #     fru_command_last,
    #     use_sudo,
    #     verbose_level,
    # ).call()
    # # print format_fru_result(fru_ret),

    # print "{} {} | {}".format(
    #     format_sel_result(sel_ret),
    #     format_fru_result(fru_ret),
    #     format_ipmi_sensor_result(ret),
    # )


if __name__ == "__main__":
    main()
