#!/usr/bin/env bash

echo "Building Linux target ..."

echo "Installing requirements ..."
pip install -r requirements.txt
pip install nuitka==2.3

echo "Building with Nuitka ..."
python -m nuitka app.py \
  --standalone \
  --onefile \
  --show-modules \
  --assume-yes-for-downloads \
  --enable-plugin=pyside6 \
  --noinclude-dlls=libQt6Charts* \
  --noinclude-dlls=libQt6Quick3D* \
  --noinclude-dlls=libQt6Sensors* \
  --noinclude-dlls=libQt6Test* \
  --noinclude-dlls=libQt6WebEngine* \
  --include-qt-plugins=styles \
  --include-qt-plugins=qml \
  --include-qt-plugins=multimedia \
  --include-data-files=./artemis/resources.py=./artemis/resources.py \
  --include-data-files=./config/qtquickcontrols2.conf=./config/qtquickcontrols2.conf \
  --include-data-files=./building/Linux/create_shortcut.sh=./create_shortcut.sh \
  --include-data-files=./images/artemis_icon.svg=./images/artemis_icon.svg \
  --force-stderr-spec="{TEMP}/artemis.err.log" \
  --force-stdout-spec="{TEMP}/artemis.out.log"

echo "Building Linux target finished."

chmod 755 app.bin
chmod 755 ./building/Linux/create_shortcut.sh

mkdir app.onefile-dist
mv app.bin ./app.onefile-dist/app.bin
cp ./building/Linux/create_shortcut.sh ./app.onefile-dist/create_shortcut.sh
cp -r images ./app.onefile-dist/images
cp LICENSE ./app.onefile-dist/LICENSE
cp README.md ./app.onefile-dist/README.md
cp CHANGELOG.md ./app.onefile-dist/CHANGELOG.md
