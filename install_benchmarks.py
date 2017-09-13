#!/usr/bin/env python3

"""Installs all the benchmarks"""

import sixonix

for name, module in sixonix.SUITES.items():
    module.install()
