#!/usr/bin/env python
# coding: utf-8

from os import path as os_path
from re import compile
from subprocess import check_output, CalledProcessError


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
    regex_compile = compile(r"(\d+)\.(\d+)\.(\d+)")
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


def get_fru_command(base_command):
    base_command[0] = base_command[0].replace("monitoring", "-fru")
    base_command.append("-s")

    return base_command


def get_sel_command(
        base_command, sel_sensor_types=[], sel_exclude_sensor_types=[]):
    base_command[0] = base_command[0].replace("monitoring", "-sel")

    base_command.extend([
        '--output-event-state',
        '--interpret-oem-data',
        '--entity-sensor-names',
        '--sensor-types=' + ",".join(sel_sensor_types),
        '--exclude-sensor-types=' + ",".join(sel_exclude_sensor_types),
    ])

    return base_command


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
        # print " ".join(self.command)

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

        return self.output

    def log(self):
        pass
