#!/bin/bash

for OPTION in $@
do
    case $OPTION in
    linux)
        if [[ ! -z "$OS" ]]; then echo "OS cannot be set twice"; exit 1; fi
        OS=linux
    ;;

    mingw64)
        if [[ ! -z "$OS" ]]; then echo "OS cannot be set twice"; exit 1; fi
        OS=mingw64
    ;;

    osx)
        if [[ ! -z "$OS" ]]; then echo "OS cannot be set twice"; exit 1; fi
        OS=osx
    ;;

    debug)
        if [[ ! -z "$BUILD_TYPE" ]]; then echo "Build type cannot be set twice"; exit 2; fi
        BUILD_TYPE=debug
        OPTIONS="DEBUG=1 $OPTIONS"
    ;;

    release)
        if [[ ! -z "$BUILD_TYPE" ]]; then echo "Build type cannot be set twice"; exit 2; fi
        BUILD_TYPE=release
    ;;

    *)
        OPTIONS="$OPTIONS $OPTION"
    esac
done


# Set target platform parameters
case $OS in
linux)
;;

mingw64)
    if [[ -z "$QMAKE_PATH" ]]; then QMAKE_PATH="/usr/x86_64-w64-mingw32/host/bin/"; fi
    SPEC="-spec win32-g++"
;;

osx)
;;

*)
    echo "You must specify between linux, mingw64, and osx."
    exit
esac

# Use release as default build type
if [[ -z "$BUILD_TYPE" ]]
then
    BUILD_TYPE=release
fi

if [[ -z $(git diff --shortstat) ]]
then
    COMMIT_HASH=$(git rev-parse HEAD)
else
    COMMIT_HASH="N/A"
fi

echo "Building using commit hash $COMMIT_HASH..."
echo "#pragma once" > BuildInfo.h.tmp
echo "#define COMMIT_HASH \"$COMMIT_HASH\"" >> BuildInfo.h.tmp

if [[ ! -f BuildInfo.h ]]
then
    touch BuildInfo.h
fi

if [[ -z $(diff BuildInfo.h BuildInfo.h.tmp) ]]
then
    rm BuildInfo.h.tmp
else
    mv BuildInfo.h.tmp BuildInfo.h
fi

CURRENT_DIR=$(pwd)

set -x
set -e

cd deps/logger
make OS=$OS $OPTIONS

cd ../CoinClasses
make OS=$OS $OPTIONS

cd ../CoinQ
make OS=$OS $OPTIONS

cd ../CoinDB
make lib OS=$OS $OPTIONS

cd $CURRENT_DIR
${QMAKE_PATH}qmake $SPEC CONFIG+=$BUILD_TYPE && make $OPTIONS

if [[ "$OS" == "osx" ]]
then
    if [[ -e build/$BUILD_TYPE/CoinVault.app/Contents/Resources/qt.conf ]]
    then
        rm build/$BUILD_TYPE/CoinVault.app/Contents/Resources/qt.conf
    fi
    ${MACDEPLOYQT_PATH}macdeployqt $(find ./build/$BUILD_TYPE -name *.app)
fi
