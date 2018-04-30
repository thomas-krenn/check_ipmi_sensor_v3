from setuptools import setup, find_packages

setup(
    name="ipmi",
    version="0.7",
    description="A ipmi python client used in NetXMS migrated from perl",
    long_description="mainly use the /use/bin/ip-sensor command",
    url="https://github.com/zhao-ji/check_ipmi_sensor_v3",
    keywords='ipmi netxms',
    author="Trevor Max",
    author_email="me@minganci.org",
    license="MIT",
    packages=find_packages(),
    entry_points={
        "console_scripts": [
            "ipmi_tool=ipmi:main",
        ],
    },
)
