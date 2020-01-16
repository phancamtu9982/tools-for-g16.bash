# tools-for-g16.bash

Various bash scripts to aid the use of the quantum chemistry software package Gaussian 16.

This is still a work in progress, but will hopefully/ eventually become an extended version of 
[tools-for-g09.bash](https://github.com/polyluxus/tools-for-g09.bash).
The version for Gaussian 09 is no longer maintained.

Please understand, that this project is primarily for me to help my everyday work. 
I am happy to hear about suggestions and bugs. 
I am fairly certain, that it will be a work in progress for quite some time 
and might be therefore in constant flux. 
This 'software' comes with absolutely no warrenty. None. Nada.

There is also absolutely no warranty in any case. 
If you decide to use any of the scripts, it is entirely your resonsibility. 

## Installation and configuration

The files of this repository are not self-contained. 
They each need access to the resources directory.
The scripts can be configured with the help of `g16.tools.rc`; 
more advisable, however, is to copy this file onto `.g16.toolsrc`
and modify this file instead.

The `configure` directory contains a script that will allow you to configure
all currently supported settings of the tools.
It produces a file like `g16.tools.rc` from old or the default settings,
which I recommend to store as `.g16.toolsrc` in the main directory.

To make the files accessible globally, the directory where they have been stored
must be in the `PATH` variable.
Alternatively, you can create softlinks to those files in a directory, 
which is already recognised by `PATH`, e.g. `~/bin` in my case.
The configure script also lets you create softlinks for the tools contained within.

The scripts will search for configuration settings in the following order of directories:
(1) the path to the script itself 
(2) the user's home directory
(3) the `.config` directory in the user's home directory
(4) the current working directory, i.e. from where the script is called.
If it does not find the file `.g16.toolsrc`, then it will also look for `g16.tools.rc`.
The last found file will be applied.

## Utilities

This reposity comes with the following scripts (and files):

 * `g16.chk2xyz.sh` 
   A tool to convert a checkpoint file to an xyz file.
   This formats the `chk` first to a `fchk`. 
   
 * `g16.getenergy.sh`
   This tool finds energy statements from Gaussian 16 calculations,
   or finds energy statements from all G16 log files in the current directory.

 * `g16.getfreq.sh`
   This tool summarises a frequency calculation and extracts the thermochemistry data.

 * `g16.submit.sh`
   This tool parses and then submits a Gaussian 16 inputfile to a queueing system.

 * `g16.testroute.sh`
   This tool parses a Gaussian 16 inputfile and tests for syntax errors with the
   Gaussian 16 utility `testrt`.

 * `g16.freqinput.sh`
   This tool reads in a Gaussian 16 inputfile and adds relevant keywords for a frequency calculation.

 * `g16.ircinput.sh`
   This tool reads in a Gaussian 16 inputfile from a frequncy calculation 
   and adds relevant keywords for an IRC calculation, 
   then writes two new inputfiles (for forward and reverse direction).

 * `g16.optinput.sh`
   This tool reads in a Gaussian 16 inputfile preferably from an IRC calculation 
   and writes an input file for a subsequent structure optimisation.

 * `g16.spinput.sh`
   This tool reads in a Gaussian 16 inputfile and writes an input file for a subsequent calculation.

 * `g16.prepare.sh`
   This tool reads in a file containing a set of cartesian coordinates (might be a Gaussian input file)
   and writes a Gaussian inputfile with predefined keywords.
   More keywords can be added with commandline options, too.
   The script can now interface to Turbomole and GFN-xTB coord files, too.

 * `g16.wrapper.sh`
   This tool provides Gaussian environment at runtime to execute Gaussian utilities interactively.

 * `g16.dissolve.sh`
   This tool parses a Gaussian 16 input file and adds keywords for solvent corrections.

 * `g16.nbo6prop.sh`
   This tool parses a Gaussian 16 input file and prepares a new input file for an NBO6 property run.
   Apart from Gaussian, this requires an istallation of NBO6. 
   (I do not have access to NBO7, so I cannot test whether this will still work with that version.)

 * `g16.tools.rc`
   This file contains the settings for the scripts.

All of the scripts come with a `-h` switch to give a summary of the available options.

A reference card (or cheat-sheet) with a summary can be found as a
pdf-file in the [docs](./docs) directory.

## License (GNU General Public License v3.0)

tools-for-g16.bash - A collection of tools for the help with Gaussian 16.
Copyright (C) 2019-2020 Martin C Schwarzer

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

See [LICENSE](LICENSE) to see the full text.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Martin (0.3.2, 2020-01-16)
