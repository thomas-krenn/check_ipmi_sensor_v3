from setuptools import setup, find_packages

setup(
    name="ipmi",
    version="0.1",
    description="a ipmi python client migrate from perl",
    url="https://github.com/zhao-ji/check_ipmi_sensor_v3",
    keywords='ipmi v3',
    author="Trevor Max",
    packages=find_packages(),
    entry_points={
        "console_scripts": [
            "ipmi_tool=ipmi:main",
        ],
    },
)
