from setuptools import setup
import app


def parse_requirements_file(requirements_path):
    with open(requirements_path) as req_file:
        return req_file.read().strip().split('\n')


setup(
    name="music_page",
    version=app.__version__,
    packages=['app'],
    license='BSD-3-Clause',
    entry_points={
        'console_scripts': [
            'music_page=app.app:main'
        ],
    },
    include_package_data=True,
    install_requires=parse_requirements_file('requirements.txt'),
)
