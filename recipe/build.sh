#!/bin/bash

set -e # Abort on error.

export PING_SLEEP=30s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$WORKDIR/build.out

touch $BUILD_OUTPUT

dump_output() {
   echo Tailing the last 500 lines of output:
   tail -500 $BUILD_OUTPUT
}
error_handler() {
  echo ERROR: An error was encountered with the build.
  dump_output
  exit 1
}

# If an error occurs, run our error handler to output a tail of the build.
trap 'error_handler' ERR

# Set up a repeating loop to send some output to Travis.
bash -c "while true; do echo \$(date) - building ...; sleep $PING_SLEEP; done" &
PING_LOOP_PID=$!

## START BUILD
# Get rid of any `.la` from defaults.
rm -rf $PREFIX/lib/*.la

# Force python bindings to not be built.
unset PYTHON

export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib -L$PREFIX/lib"
export CPPFLAGS="$CPPFLAGS -I$PREFIX/include"

# Filter out -std=.* from CXXFLAGS as it disrupts checks for C++ language levels.
re='(.*[[:space:]])\-std\=[^[:space:]]*(.*)'
if [[ "${CXXFLAGS}" =~ $re ]]; then
    export CXXFLAGS="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
fi

# `--without-pam` was removed.
# See https://github.com/conda-forge/gdal-feedstock/pull/47 for the discussion.

bash configure --prefix=$PREFIX \
            --host=$HOST \
            --with-curl \
            --with-dods-root=$PREFIX \
            --with-expat=$PREFIX \
            --with-freexl=$PREFIX \
            --with-geos=$PREFIX/bin/geos-config \
            --with-hdf4=$PREFIX \
            --with-hdf5=$PREFIX \
            --with-jpeg=$PREFIX \
            --with-kea=$PREFIX/bin/kea-config \
            --with-libjson-c=$PREFIX \
            --with-libz=$PREFIX \
            --with-libkml=$PREFIX \
            --with-libtiff=$PREFIX \
            --with-liblzma=yes \
            --with-netcdf=$PREFIX \
            --with-openjpeg=$PREFIX \
            --with-poppler=$PREFIX \
            --with-pcre \
            --with-pg=$PREFIX/bin/pg_config \
            --with-png=$PREFIX \
            --with-spatialite=$PREFIX \
            --with-sqlite3=$PREFIX \
            --with-static-proj4=$PREFIX \
            --with-xerces=$PREFIX \
            --with-xml2=$PREFIX \
            --without-python \
            --verbose \
            $OPTS

make -j $CPU_COUNT ${VERBOSE_AT} >> $BUILD_OUTPUT 2>&1
make install >> $BUILD_OUTPUT 2>&1

# Make sure GDAL_DATA and set and still present in the package.
# https://github.com/conda/conda-recipes/pull/267
ACTIVATE_DIR=$PREFIX/etc/conda/activate.d
DEACTIVATE_DIR=$PREFIX/etc/conda/deactivate.d
mkdir -p $ACTIVATE_DIR
mkdir -p $DEACTIVATE_DIR

cp $RECIPE_DIR/scripts/activate.sh $ACTIVATE_DIR/gdal-activate.sh
cp $RECIPE_DIR/scripts/deactivate.sh $DEACTIVATE_DIR/gdal-deactivate.sh
## END BUILD

# The build finished without returning an error so dump a tail of the output.
dump_output

# Nicely terminate the ping output loop.
kill $PING_LOOP_PID
