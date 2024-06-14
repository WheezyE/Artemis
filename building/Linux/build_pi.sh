#!/bin/bash

### Run build_linux.sh within a PyEnv (for systems like the Raspberry Pi)
# build_pi.sh
# Author: Eric (KI7POL)
# Credits: MarcoDT (testing, trouble-shooting, guidance).  Keith (N7ACW) (inspiration).  Jason (KM4ACK) (inspiration).
# Version: 0.2 (June 13, 2024)
# Description: Install pyenv so we can build Artemis from a fresh virtual Python (apart from any System Python setup which might be configured to run part of a Linux OS)

clear
echo "======= Build Artemis for Linux ======="
echo ""
echo "This script will help you build distributable Artemis executable binaries for Linux."
echo ""
echo "We will prepare a virtual python environment, download the Artemis repo, then make your Artemis binary."
echo ""
read -n 1 -s -r -p "Press any key to continue ..."
clear

# >>>>>>>> User-defined variables <<<<<<<<
PYTHVER='3.11.0' # Python version to install within PyEnv. Nuitka might fail to build Artemis with newer versions of python.
ARTEMISVER='4.0.3'

# Static variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # Store current location of this bash script
BUILDENV="artemis3_python"$PYTHVER
TSTART=`date +%s` # log this script's start time

# Pre-run stuff
exec > >(tee "${DIR}/build_linux-pyenv_debug.log") 2>&1 # logging
sudo apt update -y && sudo apt upgrade -y

################################ Install PyEnv ################################
if hash pyenv 2>/dev/null; then
    echo "Pyenv is already installed, skipping pyenv installation..." >&2
else
    echo "Installing pyenv now..." >&2
    curl https://pyenv.run | bash
    # Initialize Pyenv whenever shell is loaded
    sudo echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    sudo echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    # Also initialize Pyenv for this instance of shell 
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# Install some Python deps & build packages
sudo apt install -y make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev openssl # to-do: see which packages aren't needed anymore

# Install Python 3.x.x for pyenv
if ! [ -d "/${HOME}/.pyenv/versions/${PYTHVER}/" ]; then
    echo "Installing Python ${PYTHVER} within Pyenv now..."
    env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install -v ${PYTHVER}
else
    echo "Python ${PYTHVER} is already installed within Pyenv, skipping Python installation..."
fi

# Create our new Python 3.x.x virtual environment (activate before use)
if ! [ -d "/${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}" ]; then
    echo "Creating a Python ${PYTHVER} virtual environment named ${BUILDENV} ..."
    pyenv virtualenv ${PYTHVER} ${BUILDENV}
    pyenv activate ${BUILDENV}
    python -m pip install --upgrade pip # upgrade pip
else
    echo "A virtual environment with Python ${PYTHVER} named ${BUILDENV} was found. We will install pip modules here..."
fi

##################### Build Artemis from Repo using Pyenv #####################
# Clone Artemis repo
sudo apt install -y git p7zip-full
git clone https://github.com/AresValley/Artemis.git
cd Artemis

# Install some nuitka dependencies
sudo apt install -y patchelf # needed for '--standalone' build in nuitka
sudo apt install -y ccache # re-compilation of identical code in nuitka

# Build Artemis from source
pyenv activate ${BUILDENV}
cp building/Linux/build_linux.sh .
sudo chmod +x build_linux.sh
./build_linux.sh # modify nuitka build parameters here

# Zip Artemis build folder for distribution
zip -r Artemis-Linux-arm64-${ARTEMISVER}.zip app.dist/*

# Install Artemis 4 Pi runtime dependencies (avoid "Segmentation fault" on run of "./app.bin")
sudo apt install -y libxcb-cursor0 libva-dev

TEND=`date +%s` # Log the end time of the script
TTOTAL=$((TEND-TSTART))
echo "(Script completed in ${TTOTAL} seconds)" # Report how long it took to install requirements and build Artemis

################################## Clean Up ###################################
pyenv deactivate # pyenv virtualenv can also be deactivated by closing the terminal window

read -p "Would you like to remove the build pre-requisites we installed? (y/n) `echo $'\n '`(Removing these files will free up about 200 MB, but keeping the files will make re-running this script take much less time.  We will not delete PyEnv which is another 200 MB, but you can delete its folder manually to remove it if you like.) `echo $'\n> '`" REMOVEFILES
if [ ${REMOVEFILES} = "y" ] || [ ${REMOVEFILES} = "Y" ]; then
    rm -rf app.dist/ app.build/
    rm -rf ${HOME}/.pyenv/versions/${BUILDENV}/ ${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}/
fi

#################################### Notes ####################################
# Last built successfully on RPi4 (bookworm aarch64 kernel 6.6.31+rpt-rpi-v8, gcc-11 & gcc-12, python 3.11.0 within pyenv).
# Can also pass --onefile argument to nuitka by editing build_linux.sh

### Other commands
#python -V # You can test which version of python has priority now on your system if you like
#python -m test # You can run python diagnostics if you want to check the integrity an installed python.  Testing Python 3.7.0 on Pi3B+ took 56 minutes and resulted in a "== Tests result: FAILURE == ... 6 tests failed: test_asyncio test_ftplib test_imaplib test_nntplib test_poplib test_ssl" but Artemis 3.2.0 build still worked.
#pyenv global $PYTHVER # run pyenv's Python 3.x.x by default whenever "python" is typed into terminal (instead of running System python)
#pyenv global system # set the active Python version back to System Python (instead of PyEnv Python 3.7.x)
