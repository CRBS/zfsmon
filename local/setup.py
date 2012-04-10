#!/usr/bin/env python
from setuptools import setup

setup( name = 'zfsmond',
       version = '0.1.2',
       description = 'ZFS Monitoring Script',
       author = 'Jenner LaFave',
       author_email = 'jlafave@ucsd.edu',
       url = 'http://crbs.ucsd.edu',
       packages = ['zfsmond'],
       requires = ['requests'],
       scripts = ['zfsmond.py']
       data_files = [('/etc', ['zfsmond.conf'])]
       )
