#! /bin/bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo FAILED COMMAND: $previous_command' EXIT

#-------------------------------------------------------------------------------------------
# This WIP script will download packages for, configure, 
# build and install a Windows on ARM64 GCC cross-compiler.
# See: http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler
#-------------------------------------------------------------------------------------------

#TARGET_ARCH=x86_64
TARGET_ARCH=aarch64
INSTALL_PATH=~/cross
BUILD_DIR=build-$TARGET_ARCH
TARGET=$TARGET_ARCH-w64-mingw32
CONFIGURATION_OPTIONS="--disable-multilib --disable-threads --disable-shared --disable-gcov"
PARALLEL_MAKE=-j6
# BINUTILS_VERSION=binutils-2.40
# GCC_VERSION=gcc-12.2.0
BINUTILS_VERSION=binutils-master
GCC_VERSION=gcc-master
MINGW_VERSION=mingw-w64-master
MPFR_VERSION=mpfr-4.1.0
GMP_VERSION=gmp-6.2.1
MPC_VERSION=mpc-1.2.1
ISL_VERSION=isl-0.24
NEWLIB_VERSION=newlib-4.1.0
WGET_OPTIONS="-nc -P downloads"
BINUTILS_REPO=https://github.com/ZacWalk/binutils-woarm64.git
GCC_REPO=https://github.com/ZacWalk/gcc-woarm64.git
MINGW_REPO=https://github.com/ZacWalk/mingw-woarm64.git

export PATH=$INSTALL_PATH/bin:$PATH

download_sources()
{
        # Download packages
        # wget $WGET_OPTIONS https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
        # wget $WGET_OPTIONS https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz

        wget $WGET_OPTIONS https://gcc.gnu.org/pub/gcc/infrastructure/$MPFR_VERSION.tar.bz2
        wget $WGET_OPTIONS https://gcc.gnu.org/pub/gcc/infrastructure/$GMP_VERSION.tar.bz2
        wget $WGET_OPTIONS https://gcc.gnu.org/pub/gcc/infrastructure/$MPC_VERSION.tar.gz
        wget $WGET_OPTIONS https://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2

        # Extract everything
        mkdir -p code
        cd code
        for f in ../downloads/*.tar*; do tar xf $f --skip-old-files; done

        git clone "$BINUTILS_REPO" "$BINUTILS_VERSION"  || git -C "$BINUTILS_VERSION" pull
        git clone "$GCC_REPO" "$GCC_VERSION" || git -C "$GCC_VERSION" pull
        git clone "$MINGW_REPO" "$MINGW_VERSION" || git -C "$MINGW_VERSION" pull

        # Symbolic links for deps
        cd $GCC_VERSION
        ln -sf `ls -1d ../mpfr-*/` mpfr
        ln -sf `ls -1d ../gmp-*/` gmp
        ln -sf `ls -1d ../mpc-*/` mpc
        ln -sf `ls -1d ../isl-*/` isl
        cd ../..
}

build_compiler()
{
        mkdir -p $BUILD_DIR

        # Build Binutils
        mkdir -p $BUILD_DIR/binutils
        cd $BUILD_DIR/binutils
        ../../code/$BINUTILS_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
        make $PARALLEL_MAKE
        make install
        cd ../..

        # Build C/C++ Compilers
        mkdir -p $BUILD_DIR/gcc
        cd $BUILD_DIR/gcc
        ../../code/$GCC_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET \
                --enable-languages=c,c++,fortran \
                --disable-sjlj-exceptions \
                --disable-libunwind-exceptions \
                --enable-decimal-float=no \
                $CONFIGURATION_OPTIONS
        make $PARALLEL_MAKE all-gcc
        make install-gcc
        cd ../..
}

build_mingw()
{
        # mingw headers
        mkdir -p $BUILD_DIR/mingw-headers
        cd $BUILD_DIR/mingw-headers
        ../../code/$MINGW_VERSION/mingw-w64-headers/configure --prefix=$INSTALL_PATH/$TARGET --host=$TARGET --with-default-msvcrt=msvcrt
        make
        make install
        cd ../..

        # Symlink for gcc
        ln -sf $INSTALL_PATH/$TARGET $INSTALL_PATH/mingw

        # Build mingw
        mkdir -p $BUILD_DIR/mingw
        cd $BUILD_DIR/mingw
        ../../code/$MINGW_VERSION/mingw-w64-crt/configure \
                --build=x86_64-linux-gnu \
                --with-sysroot=$INSTALL_PATH \
                --prefix=$INSTALL_PATH/$TARGET \
                --host=$TARGET \
                --enable-libarm64 --disable-lib32 --disable-lib64 --disable-libarm32 \
                --with-default-msvcrt=msvcrt --without-runtime
        make $PARALLEL_MAKE
        make install
        cd ../..
}


build_libgcc()
{
        # Build Libgcc
        cd $BUILD_DIR/gcc
        make $PARALLEL_MAKE all-target-libgcc
        make install-target-libgcc
        cd ../..
}

build_libstdcpp()
{
        # Build libstdc++
        cd $BUILD_DIR/gcc
        make $PARALLEL_MAKE all-target-libstdc++-v3
        make install-target-libstdc++-v3
        cd ../..
}

build_libgfortran()
{
        # Build libgfortran++
        cd $BUILD_DIR/gcc
        make $PARALLEL_MAKE all-target-libgfortran
        make install-target-libgfortran
        cd ../..
}

build_remaining()
{
        # Build the rest of GCC
        cd $BUILD_DIR/gcc
        make $PARALLEL_MAKE all
        make install
        cd ../..
}

download_sources
build_compiler
build_mingw
build_libgcc
build_libstdcpp
build_libgfortran
#build_remaining

trap - EXIT
echo 'Success!'
