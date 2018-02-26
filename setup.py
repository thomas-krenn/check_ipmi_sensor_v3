from setuptools import setup

setup(
    name="ipmi",
    version="0.1",
    description="a ipmi python client migrate from perl",
    url="https://github.com/zhao-ji/check_ipmi_sensor_v3",
    keywords='ipmi v3',
    author="Trevor Max",
    entry_points={
        "console_scripts": [
            "ipmi=ipmi:main",
        ],
    },
)
