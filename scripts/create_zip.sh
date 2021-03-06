#!/bin/bash

# This file is part of Espruino, a JavaScript interpreter for Microcontrollers
#
# Copyright (C) 2013 Gordon Williams <gw@pur3.co.uk>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# ----------------------------------------------------------------------------------------
# Creates a Zip file of all common Espruino builds
# ----------------------------------------------------------------------------------------

cd `dirname $0`
cd .. # Espruino

VERSION=`sed -ne "s/^.*JS_VERSION.*\"\(.*\)\"/\1/p" src/jsutils.h | head -1`
echo "VERSION $VERSION"
DIR=`pwd`
ZIPDIR=$DIR/zipcontents
ZIPFILE=$DIR/archives/espruino_${VERSION}.zip
rm -rf $ZIPDIR
mkdir $ZIPDIR


# Setup ESP8266
#export ESP8266_SDK_ROOT=$DIR/esp_iot_sdk_v2.0.0.p1
#export PATH=$PATH:$DIR/xtensa-lx106-elf/bin/
rm -rf esp_iot_sdk_v2.0.0*
rm -rf xtensa-lx106-elf
source scripts/provision.sh ESP8266_BOARD
# ESP32
#export ESP_IDF_PATH=$DIR/esp-idf
#export ESP_APP_TEMPLATE_PATH=$DIR/app
#export PATH=$PATH:$DIR/xtensa-esp32-elf/bin/
rm -rf esp-idf
rm -rf app
rm -rf xtensa-esp32-elf
source scripts/provision.sh ESP32



echo ------------------------------------------------------
echo                          Building Version $VERSION
echo ------------------------------------------------------
for BOARDNAME in PICO_1V3_CC3000 PICO_1V3_WIZ ESPRUINO_1V3 ESPRUINO_1V3_WIZ ESPRUINOWIFI PUCKJS NUCLEOF401RE NUCLEOF411RE STM32VLDISCOVERY STM32F3DISCOVERY STM32F4DISCOVERY OLIMEXINO_STM32 HYSTM32_24 HYSTM32_28 HYSTM32_32 RASPBERRYPI MICROBIT ESP8266_BOARD ESP8266_4MB RUUVITAG ESP32 WIO_LTE
do
  echo ------------------------------
  echo                  $BOARDNAME
  echo ------------------------------
  EXTRADEFS=
  EXTRANAME=
  if [ "$BOARDNAME" == "ESPRUINO_1V3" ]; then
    BOARDNAME=ESPRUINOBOARD
    EXTRADEFS=CC3000=1
  fi
  if [ "$BOARDNAME" == "ESPRUINO_1V3_WIZ" ]; then
    BOARDNAME=ESPRUINOBOARD
    EXTRADEFS=WIZNET=1
    EXTRANAME=_wiznet
  fi
  if [ "$BOARDNAME" == "PICO_1V3_CC3000" ]; then
    BOARDNAME=PICO_R1_3
    EXTRADEFS=CC3000=1
    EXTRANAME=_cc3000
  fi
  if [ "$BOARDNAME" == "PICO_1V3_WIZ" ]; then
    BOARDNAME=PICO_R1_3
    EXTRADEFS=WIZNET=1
    EXTRANAME=_wiznet
  fi

  # actually build
  ESP_BINARY_NAME=`python scripts/get_board_info.py $BOARDNAME "common.get_board_binary_name(board)"`
  if [ "$BOARDNAME" == "PUCKJS" ]; then
    ESP_BINARY_NAME=`basename $ESP_BINARY_NAME .hex`.zip
    EXTRADEFS=DFU_UPDATE_BUILD=1
  fi
  if [ "$BOARDNAME" == "RUUVITAG" ]; then
    ESP_BINARY_NAME=`basename $ESP_BINARY_NAME .hex`.zip
    EXTRADEFS=DFU_UPDATE_BUILD=1
  fi

  echo "Building $ESP_BINARY_NAME"
  echo
  rm -f $BINARY_NAME
  if [ "$BOARDNAME" == "ESPRUINOBOARD" ]; then
    bash -c "$EXTRADEFS scripts/create_espruino_image_1v3.sh" || { echo "Build of $BOARDNAME failed" ; exit 1; }
  elif [ "$BOARDNAME" == "PICO_R1_3" ]; then
    bash -c "$EXTRADEFS scripts/create_pico_image_1v3.sh" || { echo "Build of $BOARDNAME failed" ; exit 1; }
  elif [ "$BOARDNAME" == "ESPRUINOWIFI" ]; then
    bash -c "$EXTRADEFS scripts/create_espruinowifi_image.sh" || { echo "Build of $BOARDNAME failed" ; exit 1; }
  else
    bash -c "$EXTRADEFS RELEASE=1 BOARD=$BOARDNAME make clean"
    bash -c "$EXTRADEFS RELEASE=1 BOARD=$BOARDNAME make" || { echo "Build of $BOARDNAME failed" ; exit 1; }
  fi
  # rename binary if needed
  if [ -n "$EXTRANAME" ]; then
    NEW_BINARY_NAME=`basename ${ESP_BINARY_NAME} .bin`$EXTRANAME.bin
  else
    NEW_BINARY_NAME=${ESP_BINARY_NAME}
  fi
  # copy...
  if [ "$BOARDNAME" == "ESP8266_BOARD" ]; then
    tar -C $ZIPDIR -xzf ${ESP_BINARY_NAME}.tgz || { echo "Build of $BOARDNAME failed" ; exit 1; }
    # build a combined image
    bash -c "$EXTRADEFS RELEASE=1 BOARD=$BOARDNAME make combined" || { echo "Build of $BOARDNAME failed" ; exit 1; }
    cp ${ESP_BINARY_NAME}_combined_512.bin $ZIPDIR || { echo "Build of $BOARDNAME failed" ; exit 1; }
  elif [ "$BOARDNAME" == "ESP8266_4MB" ]; then
    tar -C $ZIPDIR -xzf ${ESP_BINARY_NAME}.tgz || { echo "Build of $BOARDNAME failed" ; exit 1; }
  else
    echo Copying ${ESP_BINARY_NAME} to $ZIPDIR/$NEW_BINARY_NAME
    cp ${ESP_BINARY_NAME} $ZIPDIR/$NEW_BINARY_NAME || { echo "Build of $BOARDNAME failed" ; exit 1; }
    if [ "$BOARDNAME" == "ESP32" ]; then
      tar -C $ZIPDIR -xzf  `basename $ESP_BINARY_NAME .bin`.tgz || { echo "Build of $BOARDNAME failed" ; exit 1; }
    fi
  fi
done



cd $DIR

sed 's/$/\r/' dist_readme.txt | sed "s/#v##/$VERSION/" > $ZIPDIR/readme.txt
bash scripts/extract_changelog.sh | sed 's/$/\r/' > $ZIPDIR/changelog.txt
#bash scripts/extract_todo.sh  >  $ZIPDIR/todo.txt
python scripts/build_docs.py  || { echo 'Build failed' ; exit 1; }
mv $DIR/functions.html $ZIPDIR/functions.html
cp $DIR/dist_licences.txt $ZIPDIR/licences.txt

rm -f $ZIPFILE
cd zipcontents
echo zip -r $ZIPFILE *
zip -r $ZIPFILE *
