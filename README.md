# check_ipmi_sensor - Nagios/Icinga plugin to check IPMI sensors

## Requirements
* FreeIPMI version 0.5.1 or newer

## Installation hints
* ```apt-get install freeipmi```
* ```pip install git+https://github.com/zhao-ji/check_ipmi_sensor_v3.git@master```
* ```ipmi_tool -H localhost -U username -P password -L user```

## Notes on ipmi-sel
If you want to clear the ipmi system event log, pleas use:
* /usr/sbin/ipmi-sel -h $IP -u ADMIN -p $PW -l ADMIN --clear

## Get same results with NetXMS
- show all sensors and show thresholds
    ```ipmi_tool -H hostname -U username -P password -L user```
- show all sensors and hide thresholds
    ```ipmi_tool -H hostname -U username -P password -L user --no-thresholds```
- show temperature sensors and show thresholds
    ```ipmi_tool -H hostname -U username -P password -L user -T TEMPERATURE```
- show temperature sensors and hide thresholds
    ```ipmi_tool -H hostname -U username -P password -L user --no-thresholds -T TEMPERATURE```
- show voltage sensors and show thresholds
    ```ipmi_tool -H hostname -U username -P password -L user -T VOLTAGE```
- show voltage sensors and hide thresholds
    ```ipmi_tool -H hostname -U username -P password -L user --no-thresholds -T VOLTAGE```
- show fan sensors and show thresholds
    ```ipmi_tool -H hostname -U username -P password -L user -T FAN```
- show fan sensors and hide thresholds
    ```ipmi_tool -H hostname -U username -P password -L user --no-thresholds -T FAN```
- show power supply and show thresholds
    ```ipmi_tool -H hostname -U username -P password -L user -T POWER_SUPPLY```
- show power sensors and hide thresholds
    ```ipmi_tool -H hostname -U username -P password -L user --no-thresholds -T POWER_SUPPLY```


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
