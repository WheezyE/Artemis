#!/bin/bash

### Build Artemis for Raspberry Pi (for Raspbian Buster or Raspbian Stretch)
# raspbian_build.sh
# Author: Eric (KI7POL)
# Credits: MarcoDT (testing, trouble-shooting, guidance).  Keith (N7ACW) (inspiration).  Jason (KM4ACK) (inspiration).
# Version: 0.2 (June 10, 2024)
# Description: Install pre-requisites for building Artemis on Linux, then build Artemis from source

clear
echo "======= Build Artemis for Linux ======="
echo
echo "This script will help you build distributable Artemis executable binaries for Raspbian."
echo
echo "We will prepare a virtual python environment, then make your Artemis binary."
echo
read -n 1 -s -r -p "Press any key to continue (more instructions to follow) ..."
clear

# We need to install Artemis' pip requirements.  To build a compact Artemis exe, we should have a fresh python environment.

### User-defined variables
PYTHVER='3.12.4' # Specify a version of Python to install into your PyEnv virtual environment (to build Artemis from).
PYQTVER='new'

### Static Variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # Store current location of this bash script
BUILDENV="artemis3_python"$PYTHVER"pyqt"$PYQTVER
TSTART=`date +%s` # Log the start time of the script

exec > >(tee "$DIR/raspbian_build_debug.log") 2>&1 # Make a log of this script's output
sudo apt-get update -y
sudo apt-get upgrade -y

######################################### Install PyEnv #########################################
### Install pyenv so we can build Artemis from a fresh virtual Python (apart from Raspbian's System Python)

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


######################################### Install Python 3.x.x Inside Pyenv #########################################
### We will install our Artemis requirements pip modules inside of this virtualenv.

# Check to see if Python 3.x.x is already installed in pyenv.  If so, skip Python 3.x.x installation.
if ! [ -d "/$HOME/.pyenv/versions/$PYTHVER/" ]; then
    echo "Installing Python" $PYTHVER "within Pyenv now..." >&2
    sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl
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


###################################### Install Artemis Requirements Into Our Pyenv ######################################
pyenv activate $BUILDENV # Activate the new Python 3.x.x virtualenv so we can start installing python pip modules in it
cp building/Linux/build_linux.sh .
sudo chmod +x build_linux.sh
./build_linux.sh

sudo chmod -R 755 output/artemis
sudo rm output/Artemis output/_ArtemisUpdater # We'll just remove these redundant output folders so users don't get confused

TEND=`date +%s` # Log the end time of the script
TTOTAL=$((TEND-TSTART))
echo '(Script completed in' $TTOTAL 'seconds)' # Report how long it took to install requirements and build Artemis


######################################### Clean Up #########################################

pyenv deactivate # The virtualenv may also be deactivated when we close the terminal window
pyenv global system # Set the active Python version back to System Python (instead of PyEnv Python 3.7.x)

echo
read -p "Would you like to remove the build pre-requisites we installed? (y/n) `echo $'\n '`(Removing these files will free up about 200 MB, but keeping the files will make re-running this script take much less time.  We will not delete PyEnv which is another 200 MB, but you can delete its folder manually to remove it if you like.) `echo $'\n> '`" REMOVEFILES
if [ $REMOVEFILES = "y" ] || [ $REMOVEFILES = "Y" ]; then
    sudo rm -rf /home/pi/.pyenv/versions/$BUILDENV
    sudo rm -rf /home/pi/.pyenv/versions/$PYTHVER/envs/$BUILDENV
fi

######################################### Notes #########################################

### Run Artemis from a shortcut, from File Manager, or with the './Artemis' command in the terminal.  Follow the on-screen prompts to download the database and audio files.

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

### Future work
# See if PyQt5 install can be sped up with --no-tools and other conditions.
#

### Approximate installation times:
# RPi 4B (2GB)  ???. "Raspberry Pi 4 Model B Rev 1.2"
# RPi 3B+ 3.5 hours. "Raspberry Pi 3 Model B Plus Rev 1.3"
# RPi 3B  ??? hours. "Raspberry Pi 3 Model B Rev 1.2"
# Rpi 2B  12? hours.
# Rpi 0W  12  hours. "Raspberry Pi Zero W Rev 1.1"
# Find model using 'cat /sys/firmware/devicetree/base/model'

### Other commands
#python -V # You can test which version of python has priority now on your system if you like
#python -m test # You can run python diagnostics if you want to check the integrity of your new python.  My test for Python 3.7.0 took 56 minutes on the Pi3B+ and resulted in a "== Tests result: FAILURE == ... 6 tests failed: test_asyncio test_ftplib test_imaplib test_nntplib test_poplib test_ssl" but my Artemis 3.2.0 build still worked.


##################################### Error Messages and Workarounds ##############################

### NOTE!!! Artemis must be built by running "pyinstaller Artemis.spec" WHILE THE TERMINAL'S WORKING DIRECTORY IS INSIDE THE "/Artemis/spec_files/Linux" folder!  If you try to build the Artemis.spec while not in the working directory (for example, by being inside "~/Downloads/ArtemisTestBuild/" and running "PyInstaller ~/Downloads/Artemis/spec_files/Linux/Artemis.spec") then Artemis will build ok but then crash when you try to run the Artemis executable: "FileNotFoundError: [Errno 2] No such file or directory: '/tmp/_MEIaHNect/download_db_window.ui'". Said another way, you MUST cd into the "Artemis/spec_files/Linux" directory BEFORE running the "pyinstaller Artemis.spec" command!

### If you get: "[1449] Error loading Python lib '/tmp/_MEIATNM1X/libpython3.7m.so.1.0': dlopen: /lib/arm-linux-gnueabihf/libc.so.6: version `GLIBC_2.28' not found (required by /tmp/_MEIATNM1X/libpython3.7m.so.1.0)" Try updating GLIBC with "sudo apt-get install libc6".  If this doesn't work, this error might be due to your running a pre-compiled Artemis binary that was built on a newer Linux OS than the one you are running.  If this is the case, then use this build script to build Artemis for your system.

### If you get errors installing newer PyQt5 modules with pip or troubles compiling Artemis like: "ModuleNotFoundError: No module named 'pkg_resources.py2_warn'", you might try upgrading pip, installing a different version of pip setuptools (newer or older), and then reinstalling pyinstaller.  That error may show up for setuptools newer than 44.0.0.  Therefore, try: "python3.7 -m pip install --upgrade 'setuptools==44.0.0'"

### If you get the error "bash: PyInstaller: command not found" when trying to build Artemis, then run the commands below (or reload shell or just close and re-open the terminal).  After that, ensure pyenv is also reinitialized by activating your virtual env again.
#eval "$(pyenv init -)"
#eval "$(pyenv virtualenv-init -)"
#pyenv activate YOUR_BUILD_ENVIRONMENT_HERE

### We need to install python inside of pyenv with '--enable-shared' or else we will get this when trying to build Artemis on Stretch "OSError: Python library not found: libpython3.7m.so, libpython3.7mu.so.1.0, libpython3.7.so.1.0, libpython3.7m.so.1.0"

### If you get "libf77blas.so.3: cannot open shared object file: No such file or directory" during Artemis compile, make sure 'libatlas-base-dev' was installed with apt-get (this error is caused by NumPy).

### NumPy 1.17.2 errors on Stretch if it is not installed with "--no-cache-dir --no-binary :all:".  "Original error was: /lib/arm-linux-gnueabihf/libm.so.6: version `GLIBC_2.27' not found (required by /home/pi/.pyenv/versions/artemis3_py370_pyqt5122/lib/python3.7/site-packages/numpy/core/_multiarray_umath.cpython-37m-arm-linux-gnueabihf.so)"

### If we installed our pip modules inside of System Python (ie we didn't run 'pyenv activate YOUR_VIRTUAL_ENV_NAME_HERE'), then we would end up with a final Artemis file that was 1.3GB and which would error when trying to copy itself from build/PKG-00.pkg into its final dist/Artemis EXE, with error message "raise SystemError("objcopy Failure: %s" % stderr)  SystemError: objcopy Failure:  objcopy: out of memory allocating 536870912 bytes after a total of 0 bytes".  However, since we're building a fresh Python environment to install ONLY our needed Artemis modules inside of, we will not get this error and we will build an Artemis EXE that is about 97.1 MB.

### On Raspbian Stretch (not Buster), any Pyinstaller version >= 3.5 will cause PyQt5.sip (sip.so) to be incorrectly installed into the main directory within the Artemis exe (and not into the PyQt5 folder within the exe, where sip should be), so that Artemis will build without errors but will error when run ("ModuleNotFoundError: No module named 'PyQt5.sip'").  Therefore, PyInstaller 3.4 should be used on Raspbian Stretch (earlier PyInstaller versions don't install correctly on Stretch anyway).  This error might be fixable on Stretch with a custom-written PyInstaller hook for sip if you need to use a newer PyInstaller version on Raspbian Stretch, but I haven't tested this.  Raspbian Buster does not have this problem with PyInstaller and sip for some reason, so that any PyInstaller version should be fine.
	
### If we try to install PyQt5 (using pip or by building from source) without having Qt5 installed on our system, then we will get errors related to qmake: “Error: Use the --qmake argument to explicitly specify a working Qt qmake. qmake not compatible for building PyQt5”  Qt5 doesn't come pre-installed on Raspbian Buster for Raspberry Pi 0-2 (but does on newer Pi's running Raspbian Buster).  Install it with "sudo apt-get install qt5-default"

### If you get build errors with Artemis on Raspbian Buster, you might consider a different PyInstaller version built from source - Either the newest development version ("python3.7 -m pip install https://github.com/pyinstaller/pyinstaller/archive/develop.zip"), or an older version ("python3.7 -m pip install --upgrade 'PyInstaller==3.5'").

### If you type ./Artemis in the terminal and Artemis runs, but looks all grey when it runs and gives you a "Missing theme folder" dialog box error, then make sure that, when you are running the ./Artemis command, your terminal's working directory is the same directory that houses the Artemis executable file: For example, while terminal is in the "/opt/" directory, if you run "Artemis/./Artemis" then you'll get the theme folder error, but if you cd to the "/opt/Artemis/" directory and run "./Artemis", then this may fix the theme folder error.

### Similar to the theme folder error, if you run Artemis from terminal while your working directory is outside the folder that houses the Artemis executable file, then downloading the database may create a "Data" folder outside of the folder where the Artemis executable is.  Just close Artemis, move the Data folder into the Artemis folder, run the Artemis exe again from a shortcut or from File Manager, or from terminal (but in the correct working directory) and everything should work.

### If you get this error: "QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to '/tmp/runtime-root'", log out of your Pi then log back in.  This may be a problem with the EXE getting confused by pyenv if pyenv is still active when the EXE is first run.  Pyenv activates automatically by being inside the ~/Environments/artemis3_py370_pyqt5122/ directory.


################################# Working installations and console outputs ########################
### My Raspberry Pi 3B+ build specs (Raspbian Buster)
#python3.7 -O -m PyInstaller --clean Artemis.spec

#323 INFO: PyInstaller: 3.5 # Also successfully tested with Pyinstaller 3.6
#323 INFO: Python: 3.7.0
#328 INFO: Platform: Linux-4.19.97-v7+-armv7l-with-debian-10.3
#335 INFO: UPX is not available.


#pip list

#Package         Version   
#--------------- ----------
#aiohttp         3.6.2     
#altgraph        0.17      
#async-timeout   3.0.1     
#attrs           19.3.0    
#certifi         2020.4.5.1
#chardet         3.0.4     
#idna            2.9       
#multidict       4.7.5     
#numpy           1.17.2    
#pandas          1.0.3     
#pip             10.0.1    
#pygame          1.9.6     
#PyInstaller     3.6       
#PyQt5           5.12.2    
#PyQt5-sip       4.19.17   
#python-dateutil 2.8.1     
#pytz            2019.3    
#QtAwesome       0.7.0     
#QtPy            1.9.0     
#setuptools      39.0.1    
#six             1.14.0    
#urllib3         1.24.3    
#yarl            1.4.2


### Terminal output on RPi3B+ (Buster) for our build
#spec_files/Linux $ dist/./Artemis
#pygame 1.9.6
#Hello from the pygame community. https://www.pygame.org/contribute.html
#libEGL warning: DRI2: failed to authenticate
#qt5ct: using qt5ct plugin
#qt5ct: D-Bus global menu: no
#[Artemis then launches]



### Terminal output on RPi3B (not plus) (Stretch) for our build
#(artemis3_pyqt5122) pi@raspberrypi:~/Downloads/Artemis/spec_files/Linux/dist $ ./Artemis 
#pygame 1.9.6
#Hello from the pygame community. https://www.pygame.org/contribute.html
#libEGL warning: DRI2: failed to authenticate
#[Artemis then launches]

#NOTE: This RPi3B Stretch build will run on Buster, but only will display fonts correctly if we rename our Buster /etc/fonts/ directory, copy the Stretch fonts directory into Buster, and run ./Artemis as sudo.  I am investigating whether this may be due to old PyInstaller installing weirdly.
#[on stretch] sudo cp -L -r /etc/fonts /media/pi/ENFAIN/fonts_stretch
#[on buster] sudo mv /etc/fonts /etc/fonts.bak
#[on buster] sudo cp -L -r /media/pi/ENFAIN/fonts_stretch /etc/fonts
#https://askubuntu.com/questions/1098809/ubuntu-18-10-fontconfig

#(artemis3_pyqt5122) pi@raspberrypi:~/Downloads/Artemis/spec_files/Linux/dist $ pip list
#Package         Version
#--------------- ----------
#aiohttp         3.6.2
#altgraph        0.17
#async-timeout   3.0.1
#attrs           19.3.0
#certifi         2020.4.5.1
#chardet         3.0.4
#future          0.18.2
#idna            2.9
#macholib        1.14
#multidict       4.7.5
#numpy           1.17.2
#pandas          1.0.3
#pefile          2019.4.18
#pip             20.1
#pygame          1.9.6
#PyInstaller     3.4
#PyQt5           5.12.2
#PyQt5-sip       4.19.17
#python-dateutil 2.8.1
#pytz            2020.1
#QtAwesome       0.7.1
#QtPy            1.9.0
#setuptools      44.0.0
#six             1.14.0
#urllib3         1.24.3
#wheel           0.34.2
#yarl            1.4.2


### Terminal output on RPi4B for our build
#pi@raspberrypi:~/Desktop/Artemis3 Pi3B+ $ ./Artemis 
#pygame 1.9.6
#Hello from the pygame community. https://www.pygame.org/contribute.html
#qt5ct: using qt5ct plugin
#qt5ct: D-Bus global menu: no
#[Artemis then launches]


### Terminal output on RPi4B for the official Linux build
#pi@raspberrypi:~/Downloads/artemis $ ./Artemis 
#bash: ./Artemis: cannot execute binary file: Exec format error
#pi@raspberrypi:~/Downloads/artemis $ ./_ArtemisUpdater 
#bash: ./_ArtemisUpdater: cannot execute binary file: Exec format error
#[Artemis doesn't launch]
