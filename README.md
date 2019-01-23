# check_ipmi_sensor - Nagios/Icinga plugin to check IPMI sensors [![License: GPL v3+](https://img.shields.io/badge/License-GPL%20v3%2B-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Description
With this plugin the hardware status of a server can be monitored with Nagios, Icinga or Icinga 2. Specifically, fan speeds, temperatures, voltages, power consumption, power supply performance, etc. can be monitored.

## Requirements
* Nagios, Icinga or Icinga 2
* FreeIPMI version 0.5.1 or newer
* Perl
* Perl IPC::Run

## Installation hints
For detailed information, installation instructions and definition examples, please go to:

* [IPMI Sensor Monitoring Plugin](https://www.thomas-krenn.com/en/wiki/IPMI_Sensor_Monitoring_Plugin)

### Destination folder
Copy this plugin to the following folder:

	/usr/lib/nagios/plugins/check_ipmi_sensor

### Debian/Ubuntu
Install missing lib:

	apt-get install libipc-run-perl

### CentOS
Install missing lib:

	yum install perl-IPC-Run freeipmi

### Additional
If you are running the plugin locally and not via network, the user 'nagios'
needs root privileges for calling:
* ipmimonitoring/ipmi-sensors/ipmi-sel/[ipmi-fru]/[ipmi-dcmi]

You can achieve that by adding a sudoers config (e.g. for ipmi-sensors)

	nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-sensors, /usr/sbin/ipmi-sel, /usr/sbin/ipmi-fru, /usr/sbin/ipmi-dcmi

Please check with '-vvv' which commands are run by the plugin!

## Notes on ipmi-sel
If you want to clear the ipmi system event log, please use ipmi-sel.

### Remote machine
	/usr/sbin/ipmi-sel -h $IP -u ADMIN -p $PW -l ADMIN --clear

### Local machine
	/usr/sbin/ipmi-sel --clear

## License
Copyright (C) 2009-2019 [Thomas-Krenn.AG](https://www.thomas-krenn.com/en/index.html),
additional contributors see changelog.txt

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.
 
This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.
 
You should have received a copy of the GNU General Public License along with
this program; if not, see <http://www.gnu.org/licenses/>.
