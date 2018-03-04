# define entire hashes
HDRMAP = {
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

SENSOR_TYPES = [
        "Temperature"
        "Voltage"
        "Current"
        "Fan"
        "Physical_Security"
        "Platform_Security_Violation_Attempt"
        "Processor"
        "Power_Supply"
        "Power_Unit"
        "Cooling_Device"
        "Other_Units_Based_Sensor"
        "Memory"
        "Drive_Slot"
        "POST_Memory_Resize"
        "System_Firmware_Progress"
        "Event_Logging_Disabled"
        "Watchdog_1"
        "System_Event"
        "Critical_Interrupt"
        "Button_Switch"
        "Module_Board"
        "Microcontroller_Coprocessor"
        "Add_In_Card"
        "Chassis"
        "Chip_Set"
        "Other_Fru"
        "Cable_Interconnect"
        "Terminator"
        "System_Boot_Initiated"
        "Boot_Error"
        "OS_Boot"
        "OS_Critical_Stop"
        "Slot_Connector"
        "System_ACPI_Power_State"
        "Watchdog_2"
        "Platform_Alert"
        "Entity_Presence"
        "Monitor_ASIC_IC"
        "LAN"
        "Management_Subsystem_Health"
        "Battery"
        "Session_Audit"
        "Version_Change"
        "FRU_State"
        "OEM_Reserved"
]
