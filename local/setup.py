#!/usr/bin/env python
from setuptools import setup

setup( name = 'zfsmond',
       version = '0.2.2',
       description = 'ZFS Monitoring Script',
       author = 'Jenner LaFave',
       author_email = 'jlafave@ucsd.edu',
       url = 'http://crbs.ucsd.edu',
       license = 'MIT Expat License',
       py_modules = ['datazfs'],
       requires = ['requests'],
       scripts = ['updater.py'],
       data_files = [('/etc', ['zfsmond.conf'])]
       )
