#!/usr/bin/env python
# coding: utf-8

from const import HDRMAP


def format_sel_result(doc):
    doc_by_row = doc.split("\n")
    header = doc_by_row[0]
    body = doc_by_row[1:]

    header_list = map(lambda i: i.strip(), header.split("|"))

    result_list = []
    for row in body:
        if not row:
            continue
        row_fields = map(lambda i: i.strip(), row.split("|"))
        row_ret = {
            header_list[i]: row_fields[i]
            for i in range(len(header_list))
        }
        result_list.append(row_ret)

    sel_issues_present = 0
    for item in result_list:
        if item["State"] != "Nominal":
            sel_issues_present += 1

    ret_doc = ""
    if sel_issues_present == 1:
        ret_doc = "1 system event log (SEL) entry present"
    elif sel_issues_present > 1:
        ret_doc = "{} system event log (SEL) entries present".format(sel_issues_present)

    return "IPMI Status: Critical [{}]".format(ret_doc)


def format_ipmi_sensor_result(doc):
    """
    translate the header and extract the doc into dict
    ordering: reading, lower nc, upper nc, lower c, upper c 
    """
    doc_by_row = doc.split("\n")
    header = doc_by_row[0]
    body = doc_by_row[1:]

    origin_header_list = map(lambda i: i.strip(), header.split("|"))
    header_list = [HDRMAP.get(header) for header in origin_header_list]

    result_dict = []
    for row in body:
        if not row:
            continue
        row_fields = map(lambda i: i.strip(), row.split("|"))
        row_ret = {
            header_list[i]: row_fields[i]
            for i in range(len(header_list))
        }
        if row_ret["reading"] != "N/A":
            result_dict.append(row_ret)

    return " ".join([
        "'{name}'={reading};{lowerNC}:{upperNC};{lowerNR}:{upperNR}".format(
            name = row["name"],
            reading = row["reading"],
            lowerNC = row["lowerNC"],
            upperNC = row["upperNC"],
            lowerNR = row["lowerNR"],
            upperNR = row["upperNR"],
        ) for row in result_dict
    ])


def format_fru_result(doc):
    doc_by_row = doc.split("\n")
    serial_number_line = filter(
        lambda row: "Product Serial Number" in row,
        doc_by_row,
    )
    if serial_number_line:
        number = [str(i) for i in range(10)]
        serial_number = "".join(
            filter(lambda i: i in number, serial_number_line[0])
        )
    return "({})".format(serial_number)


def ipmi_sensor_netxms_format(doc, filter_thresholds=False):
    """
    translate the header and extract the doc into dict
    ordering: reading, lower nc, upper nc, lower c, upper c 
    """
    doc_by_row = doc.split("\n")
    header = doc_by_row[0]
    body = doc_by_row[1:]

    origin_header_list = map(lambda i: i.strip(), header.split("|"))
    header_list = [HDRMAP.get(header) for header in origin_header_list]

    result_dict = []
    for row in body:
        if not row:
            continue

        row_fields = map(lambda i: i.strip(), row.split("|"))
        row_ret = {
            header_list[i]: row_fields[i]
            for i in range(len(header_list))
        }
        # if row_ret["reading"] != "N/A":
        result_dict.append(row_ret)

    header = "Name|Status|Reading|Low NR|LowCT|Low NC|High NC|High CT|High NR"
    if filter_thresholds:
        header = "Name|Status|Reading"

    body = []
    for row in result_dict:
        if filter_thresholds:
            body_line = "|".join([
                row["name"], row["state"],
                "{} {}".format(row["reading"], row["units"]),
            ])
        else:
            body_line = "|".join([
                row["name"], row["state"],
                "{} {}".format(row["reading"], row["units"]),
                row["lowerNR"], row["lowerC"],
                row["lowerNC"], row["upperNC"],
                row["upperC"], row["upperNR"],
            ])
        body.append(body_line)

    body.insert(0, header)
    return "\n".join(body)
