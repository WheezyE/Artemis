#!/bin/bash

### Runs the build_linux.sh script within a PyEnv (for OS's with a "System python" installation, like the Raspberry Pi)
# build_pi.sh
# Author: Eric (KI7POL)
# Credits: MarcoDT (Artemis sourcecode, testing, guidance, encouragement).  Keith (N7ACW) (inspiration).
# Version: 0.2 (June 17, 2024)

clear
echo -e "This script installs pyenv, installs a python virtual environment into pyenv,\nthen builds an Artemis binary using build_linux.sh."

# >>>>>>>> User-defined variables <<<<<<<<
PYTHVER='3.11.0' # Python version to install within PyEnv. Nuitka might fail to build Artemis with python > v3.11.

# Static variables
if [ $(pwd | grep -P "${HOME}/.*Artemis/building/Linux") ]; then
    cd ../.. #if we are running this script from the "building/Linux/" directory then change to repo root directory instead
fi
REPODIR="$(pwd)" # Store current directory
BUILDENV="artemis_python${PYTHVER}"
TSTART=`date +%s` # log this script's start time

# Pre-run stuff
#exec > >(tee "${THISDIR}/build_linux-pyenv_debug.log") 2>&1 # logging
export DEBIAN_FRONTEND=noninteractive  #don't ask for user input
sudo apt-get -y update && sudo apt-get -y -o Dpkg::Options::="--force-confold" upgrade #upgrade silently and keep any old configs

################################ Install PyEnv ################################
if hash pyenv 2>/dev/null; then
    echo "Pyenv is already installed, skipping pyenv installation..."
else
    echo "Installing pyenv now..."
    curl https://pyenv.run | bash
    # Initialize Pyenv whenever termianl is opened in the future
    sudo echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    sudo echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    sudo echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
fi
# Initialize Pyenv for this script (required for scripts even if already in ~/.bashrc)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install some Python deps & build packages
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
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
if [ ! -d "${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}" ]; then
    echo "Creating a Python ${PYTHVER} virtual environment named ${BUILDENV} ..."
    pyenv virtualenv ${PYTHVER} ${BUILDENV}
    pyenv activate ${BUILDENV}
    python -m pip install --upgrade pip # upgrade pip
else
    echo -e "A virtual environment with Python ${PYTHVER} named ${BUILDENV}\nwas found on this system. We will configure this and build Artemis from here.\nIf Artemis build fails, consider deleting this with\n\"rm -rf ${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}\" ..."
fi

##################### Build Artemis from Repo using Pyenv #####################
# Activate pyenv build environment
sudo apt-get install -y patchelf ccache # nuitka dependencies: needed for '--standalone' build & speeding up re-compilation
pyenv activate ${BUILDENV}

# Build Artemis from source
cd ${REPODIR}
echo "Current directory is:" $(pwd)
sudo chmod +x building/Linux/build_linux.sh
building/Linux/./build_linux.sh # can modify nuitka build parameters here

# Install Artemis 4 Pi runtime dependencies (avoid "Segmentation fault" on run of "./app.bin")
sudo apt-get install -y libxcb-cursor0 libva-dev

TEND=`date +%s` # Log the end time of the script
TTOTAL=$((TEND-TSTART))
echo "(Script completed in ${TTOTAL} seconds)" # Report how long it took to install requirements and build Artemis

################################## Clean Up ###################################
pyenv deactivate # pyenv virtualenv can also be deactivated by closing the terminal window

read -t 5 -rep $'\nRemove the python build environment & cached build files? (y/n - default n)\n(~200 MB of cached files make future builds faster)' REMOVEFILES
if [ "${REMOVEFILES}" = "y" ] || [ "${REMOVEFILES}" = "Y" ]; then
    rm -rf ${REPODIR}/app.dist/ ${REPODIR}/app.build/ ${REPODIR}/app.bin
    rm -rf ${HOME}/.pyenv/versions/${BUILDENV}/ ${HOME}/.pyenv/versions/${PYTHVER}/envs/${BUILDENV}/
fi

read -t 5 -rep $'\nRemove pyenv? (y/n - default n)' REMOVEPYENV
if [ "${REMOVEPYENV}" = "y" ] || [ "${REMOVEPYENV}" = "Y" ]; then
    rm -rf ${HOME}/.pyenv/
    echo "You may also wish to remove these lines from your ~/.bashrc file:"
    echo '    export PYENV_ROOT="$HOME/.pyenv"'
    echo '    export PATH="$PYENV_ROOT/bin:$PATH"'
    echo '    eval "$(pyenv init -)"'
    echo '    eval "$(pyenv virtualenv-init -)"'
fi

#################################### Notes ####################################
# Last built successfully on RPi4 (bookworm aarch64 kernel 6.6.31+rpt-rpi-v8, gcc-11 & gcc-12, python 3.11.0 within pyenv).

### Other commands
#python -V # You can test which version of python has priority now on your system if you like
#python -m test # You can run python diagnostics if you want to check the integrity an installed python.  Testing Python 3.7.0 on Pi3B+ took 56 minutes and resulted in a "== Tests result: FAILURE == ... 6 tests failed: test_asyncio test_ftplib test_imaplib test_nntplib test_poplib test_ssl" but Artemis 3.2.0 build still worked.
#pyenv global $PYTHVER # run pyenv's Python 3.x.x by default whenever "python" is typed into terminal (instead of running System python)
#pyenv global system # set the active Python version back to System Python (instead of PyEnv Python 3.7.x)
