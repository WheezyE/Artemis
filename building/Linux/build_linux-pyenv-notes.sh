#!/bin/bash

### Build Artemis for Linux within PyEnv (for systems like the Raspberry Pi)
# build_linux-pyenv.sh
# Author: Eric (KI7POL)
# Credits: MarcoDT (testing, trouble-shooting, guidance).  Keith (N7ACW) (inspiration).  Jason (KM4ACK) (inspiration).
# Version: 0.2 (June 10, 2024)
# Description: Install pre-requisites for building Artemis on Linux within a pyenv, then build Artemis from source
# We need to install Artemis' pip requirements.  To build a compact Artemis exe, we should build within a fresh python environment.

clear
echo "======= Build Artemis for Linux ======="
echo
echo "This script will help you build distributable Artemis executable binaries Linux."
echo
echo "We will prepare a virtual python environment, then make your Artemis binary."
echo
read -n 1 -s -r -p "Press any key to continue (more instructions to follow) ..."
clear

### User-defined variables
PYTHVER='3.12.4' # Specify a version of Python to install into your PyEnv virtual environment (to build Artemis from).

### Static Variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # Store current location of this bash script
BUILDENV="artemis3_python"$PYTHVER
TSTART=`date +%s` # log this script's start time

exec > >(tee "$DIR/build_linux-pyenv_debug.log") 2>&1 # log this script's output
sudo apt-get update -y && sudo apt-get upgrade -y

######################################### Install PyEnv #########################################
### Install pyenv so we can build Artemis from a fresh virtual Python (apart from any System Python setup which might be configured to run part of a Linux OS)

export PYENV_ROOT="$HOME/.pyenv" # Needed to help this if statement find PyEnv if it's already installed.
export PATH="$PYENV_ROOT/bin:$PATH" # Both of these exports are also needed later in this script.

if hash pyenv 2>/dev/null; then
    echo "Pyenv is already installed, skipping pyenv installation..." >&2
else
    echo "Installing pyenv now..." >&2
    
    curl https://pyenv.run | bash
    # Pyenv needs to be initialized whenever SHELL is loaded, so add these values to .bashrc
    sudo echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    sudo echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
fi

# Initialize pyenv so this instance of SHELL can find PyEnv (so we don't have to restart SHELL).
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"


### Install Python 3.x.x & pip modules Inside Pyenv/virtualenv
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev openssl

# Check to see if Python 3.x.x is already installed in pyenv.  If so, skip Python 3.x.x installation.
if ! [ -d "/$HOME/.pyenv/versions/$PYTHVER/" ]; then
    echo "Installing Python" $PYTHVER "within Pyenv now..." >&2
    env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install -v $PYTHVER
else
    echo "Python" $PYTHVER "is already installed within Pyenv, skipping Python installation..." >&2
fi
pyenv global $PYTHVER # Make your python 3.x.x environment the default whenever "python" is typed (instead of System python)

### Create our new python virtual environment using Python 3.x.x (we will activate it as soon as we need it)
# Check to see if we've already made a Python 3.x.x virtual environment named (for example) 'artemis3_py3.7.0_pyqtnew'
if ! [ -d "/$HOME/.pyenv/versions/$PYTHVER/envs/$BUILDENV" ]; then
    echo 'Creating a Python' $PYTHVER 'virtual environment named' $BUILDENV '...' >&2
    pyenv virtualenv $PYTHVER $BUILDENV
else
    echo 'A virtual environment with Python' $PYTHVER 'named' $BUILDENV 'was found. We will install pip modules here...' >&2
fi


###################################### Build Artemis With Our Pyenv ######################################
# Clone Artemis repo
sudo apt install -y git p7zip-full
git clone https://github.com/AresValley/Artemis.git
cd Artemis

# Install some nuitka dependencies for our system
sudo apt install -y patchelf # needed to build '--standalone' with nuitka
sudo apt install -y ccache # nuitka-recommended package to speed up re-compilation of identical code

# Install Artemis build dependencies (pip modules) inside of our new Python 3.x.x virtualenv, then build Artemis
pyenv activate $BUILDENV 
cp building/Linux/build_linux.sh .
sudo chmod +x build_linux.sh
./build_linux.sh

# Zip contents of our Artemis build folder for distribution
cd app.dist
7z a -r ../Artemis-Linux-x86_64-4.0.3.7z *
7z a -tzip -r ../Artemis-Linux-x86_64-4.0.3.zip *
cd ..

# Install some Artemis 4 runtime dependencies
sudo apt install -y libxcb-cursor0 libva-dev

TEND=`date +%s` # Log the end time of the script
TTOTAL=$((TEND-TSTART))
echo '(Script completed in' $TTOTAL 'seconds)' # Report how long it took to install requirements and build Artemis


######################################### Clean Up #########################################

pyenv deactivate # The virtualenv may also be deactivated when we close the terminal window
pyenv global system # Set the active Python version back to System Python (instead of PyEnv Python 3.7.x)

echo
read -p "Would you like to remove the build pre-requisites we installed? (y/n) `echo $'\n '`(Removing these files will free up about 200 MB, but keeping the files will make re-running this script take much less time.  We will not delete PyEnv which is another 200 MB, but you can delete its folder manually to remove it if you like.) `echo $'\n> '`" REMOVEFILES
if [ $REMOVEFILES = "y" ] || [ $REMOVEFILES = "Y" ]; then
    rm -rf ~/Downloads/Artemis/app.build
    rm -rf ~/Downloads/Artemis/app.dist
    sudo rm -rf /home/pi/.pyenv/versions/$BUILDENV
    sudo rm -rf /home/pi/.pyenv/versions/$PYTHVER/envs/$BUILDENV
fi

######################################### Notes #########################################
### Other Resources
# Python Virtual Environments https://www.youtube.com/watch?v=N5vscPTWKOk
# Python VirtEnv reduces built EXE file sizes https://stackoverflow.com/questions/47692213/reducing-size-of-pyinstaller-exe
# Setuptools error: "ModuleNotFoundError: No module named 'pkg_resources.py2_warn'" https://github.com/pypa/setuptools/issues/1963
# Trouble-shooting pyinstaller https://github.com/pyinstaller/pyinstaller/wiki/How-to-Report-Bugs#make-sure-everything-is-packaged-correctly
# Using pyinstaller with venv: https://pyinstaller.readthedocs.io/en/stable/development/venv.html
# Learning Pyenv https://realpython.com/intro-to-pyenv/
# Search Debian apt-get repo for missing packages https://www.debian.org/distrib/packages#search_contents
# https://www.cyberciti.biz/faq/howto-check-if-a-directory-exists-in-a-bash-shellscript/
# https://pyinstaller.readthedocs.io/en/stable/development/venv.html
# https://stackoverflow.com/questions/16931244/checking-if-output-of-a-command-contains-a-certain-string-in-a-shell-script
# PyQt5 build instructions: https://www.riverbankcomputing.com/static/Docs/PyQt5/building_with_configure.html

### Other commands
#python -V # You can test which version of python has priority now on your system if you like
#python -m test # You can run python diagnostics if you want to check the integrity of your new python.  My test for Python 3.7.0 took 56 minutes on the Pi3B+ and resulted in a "== Tests result: FAILURE == ... 6 tests failed: test_asyncio test_ftplib test_imaplib test_nntplib test_poplib test_ssl" but my Artemis 3.2.0 build still worked.
