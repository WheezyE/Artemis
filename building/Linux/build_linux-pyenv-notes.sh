#!/bin/bash

### Build Artemis for Linux within PyEnv (for systems like the Raspberry Pi)
# build_linux-pyenv.sh
# Author: Eric (KI7POL)
# Credits: MarcoDT (testing, trouble-shooting, guidance).  Keith (N7ACW) (inspiration).  Jason (KM4ACK) (inspiration).
# Version: 0.2 (June 10, 2024)
# Description: Install pre-requisites for building Artemis on Linux within a pyenv, then build Artemis from source
# Details: We might need to install Artemis' pip requirements on a system that uses Python to run its OS.  To build an Artemis binary, we should build within a fresh python virtual environment.

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
PYTHVER='3.11.0' # Specify a version of Python to install into your PyEnv virtual environment (to build Artemis from).

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
./build_linux.sh # can try modifying nuitka build parameters here to get build to run

### NOTES ON BUILDING ON RPI ### python3.12.4
# Tried original build parameters (gcc 12): ./app.bin returns "Segmentation fault"
# Tried use LTO compilation (add --lto=yes to build_linux.sh) (gcc 12): "Segmentation fault"
# Tried original build parameters (clang): "Segmentation fault"
# Sources : 
# Tried original build parameters (gcc 12) [sudo apt remove gcc && sudo apt install gcc-11 && sudo ln -s /usr/bin/gcc-11 /usr/bin/gcc]: "Segmentation fault"

### NOTES ON BUILDING ON DEBIAN X64 ### python3.12.4
# Tried original build parameters (gcc 11): SUCCESS
# Tried original build parameters + LTO compilation (add --lto=yes to build_linux.sh): "Segmentation fault"
# Tried original build parameters + --clang (clang 14.0.0-1ubuntu1.1): "Segmentation fault (core dumped)"
# Tried --onefile (instead of --standalone): doesn't run, not terminal output

### NOTES ON BUILDING ON RPI ### python3.11.0
# Tried original build parameters (gcc 11): SUCCESS

# Zip contents of our Artemis build folder for distribution
7z a -r Artemis-Linux-ARM64-4.0.3.7z app.dist\*
7z a -tzip -r Artemis-Linux-ARM64-4.0.3.zip app.dist\*

# Install some Artemis 4 runtime dependencies (avoid "Segmentation fault" on run of "./app.bin")
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
    rm -rf app.dist/ app.build/
    rm -rf ${HOME}/.pyenv/versions/${BUILDENV}/ ${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}/
fi

######################################### Notes #########################################
### Other Resources
# Python Virtual Environments https://www.youtube.com/watch?v=N5vscPTWKOk
# Python VirtEnv reduces built EXE file sizes https://stackoverflow.com/questions/47692213/reducing-size-of-pyinstaller-exe
# Nuitka built apps "Segmentation fault" https://stackoverflow.com/questions/35163523/script-compiled-with-nuitka-raises-segmentation-fault

### Other commands
#python -V # You can test which version of python has priority now on your system if you like
#python -m test # You can run python diagnostics if you want to check the integrity of your new python.  My test for Python 3.7.0 took 56 minutes on the Pi3B+ and resulted in a "== Tests result: FAILURE == ... 6 tests failed: test_asyncio test_ftplib test_imaplib test_nntplib test_poplib test_ssl" but my Artemis 3.2.0 build still worked.
