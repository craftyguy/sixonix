import os
import os.path
import stat
import subprocess
import sys
from urllib.request import urlretrieve
import zipfile

from . import config

class TQDMReporter:
    def __init__(self, tqdm, desc):
        self.tqdm = tqdm.tqdm
        self.desc = desc
        self.pbar = None

    def __call__(self, count, block_size, total_size):
        if self.pbar is None:
            self.pbar = self.tqdm(desc = self.desc, ascii = True,
                                  total = total_size, unit = 'B',
                                  unit_scale = True, unit_divisor = 1024)

        self.pbar.update(block_size)

        if count * block_size >= total_size:
            self.pbar.close()

def get_report_hook(desc):
    try:
        import tqdm
        return TQDMReporter(tqdm, desc)
    except ModuleNotFoundError:
        return None

def install_benchmarks_for_module(module_name, quiet = False):
    """Installs the bechmark binaries for the given module"""
    conf = config.get_config_for_module(module_name)

    # Check to see if it's already installed
    installed = True
    for executable in conf.executables:
        executable_path = os.path.join(conf.benchmark_path, executable)
        if not os.path.exists(executable_path):
            installed = False

    if installed:
        return

    if not quiet:
        print("Installing benchmark binaries for {}...".format(module_name))

    os.makedirs(conf.benchmark_path, exist_ok = True)

    for package_url in conf.packages:
        package_fname = os.path.join(conf.benchmark_path,
                                     os.path.basename(package_url))
        if not os.path.exists(package_fname):
            reporthook = None if quiet else \
                         get_report_hook(os.path.basename(package_url))
            urlretrieve(package_url, package_fname, reporthook)
            print("retrieved binaries for {}...".format(package_url))
            os.sync()
        if package_fname.endswith(".zip"):
            try:
                zipf = zipfile.ZipFile(package_fname)
            except zipfile.BadZipFile:
                os.remove(package_fname)
                assert False, ("ERROR: The benchmark package is corrupt "
                               "and as been removed.")
            try:
                zipf.extractall(path=conf.benchmark_path)
            except Exception as e:
                assert False, ("ERROR: The benchmark package could not be "
                               "fully extracted.")
        elif package_fname.endswith(".run"):
            print("executing {}".format(package_fname))
            proc = subprocess.Popen(["/bin/sh", package_fname],
                                    stdout=subprocess.PIPE, 
                                    stderr=subprocess.PIPE,
                                    cwd = conf.benchmark_path)
            (out, err) = proc.communicate()
            os.sync()
            print("stdout: " + out)
            print("stderr: " + err)
        else:
            assert False, "Unknown package file extension"

    if conf.platform == "linux":
        # If we're on linux, we need to make the executables executable
        for executable in conf.executables:
            executable_path = os.path.join(conf.benchmark_path, executable)
            perms = os.stat(executable_path)
            os.chmod(executable_path, perms.st_mode | stat.S_IXUSR |
                                      stat.S_IXGRP | stat.S_IXOTH)
