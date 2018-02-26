# check_ipmi_sensor - Nagios/Icinga plugin to check IPMI sensors

## Requirements
* FreeIPMI version 0.5.1 or newer

## Installation hints
On Debian/Ubuntu use 'apt-get install libipc-run-perl' to install IPC::Run.
If you are running the plugin locally and not via network, the user 'nagios'
needs root privileges for calling:
* ipmimonitoring/ipmi-sensors/ipmi-sel/[ipmi-fru]

You can achieve that by adding a sudoers config (e.g. for ipmi-sensors)
* nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-sensors, /usr/sbin/ipmi-sel

Please check with '-vvv' which commands are run by the plugin!

* ```git+https://github.com/zhao-ji/check_ipmi_sensor_v3.git@master```
* ```ipmi_tool -H localhost -U username -P password -L user```

## Notes on ipmi-sel
If you want to clear the ipmi system event log, pleas use:
* /usr/sbin/ipmi-sel -h $IP -u ADMIN -p $PW -l ADMIN --clear

## License
Copyright (C) 2009-2016 Thomas-Krenn.AG,
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
