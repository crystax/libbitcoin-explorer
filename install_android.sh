#!/bin/bash


ANDROID_GCC_VERSION=6
NDK_ICU_VERSION=56.1
NDK_BOOST_VERSION=1.61.0
NDK_DEFAULT_ABIS="armeabi-v7a x86 mips armeabi-v7a-hard arm64-v8a x86_64 mips64"


# $1 -- error message
android_error()
{
    echo "*** ERROR: $@" 1>&2
}

# $1 -- abi
android_target_for_abi()
{
    local abi=$1
    local target

    case $abi in
        armeabi-v7a|armeabi-v7a-hard)
            target=arm-linux-androideabi
            ;;
        arm64-v8a)
            target=aarch64-linux-android
            ;;
        x86)
            target=i686-linux-android
            ;;
        x86_64)
            target=x86_64-linux-android
            ;;
        mips)
            target=mipsel-linux-android
            ;;
        mips64)
            target=mips64el-linux-android
            ;;
        *)
            error "Unsupported ABI: '$abi'"
            exit 1
    esac

    echo $target
}

# $1 -- abi
android_arch_for_abi()
{
    local abi=$1
    local arch
    
    case $abi in
        armeabi*)
            arch=arm
            ;;
        arm64*)
            arch=arm64
            ;;
        *)
            arch=$abi
    esac

    echo $arch
}

# $1 -- abi
android_api_level_for_abi()
{
    local abi=$1
    local apilevel=16
    
    case $abi in
        arm64*|x86_64|mips64)
            apilevel=21
            ;;
    esac

    echo $apilevel
}

# $1 -- abi
android_sysroot_for_abi()
{
    local abi=$1
    local api_level=$(android_api_level_for_abi $abi)
    local arch=$(android_arch_for_abi $abi)
    echo "$NDK_DIR/platforms/android-$api_level/arch-$arch"
}

# $1 -- abi
android_cflags_for_abi()
{
    local abi=$1
    local cflags="--sysroot=$(android_sysroot_for_abi $abi) -fPIE -pie"

    case $abi in
        armeabi-v7a)
            cflags="$cflags -mthumb -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"
            ;;
        armeabi-v7a-hard)
            cflags="$cflags -mthumb -march=armv7-a -mfpu=vfpv3-d16 -mhard-float"
            ;;
    esac

    echo $cflags
}

# $1 -- abi
android_ldflags_for_abi()
{
    local abi=$1
    local ldflags="-L$NDK_DIR/sources/crystax/libs/$abi"

    case $abi in
        armeabi-v7a)
            ldflags="$ldflags -Wl,--fix-cortex-a8"
            ;;
        armeabi-v7a-hard)
            ldflags="$ldflags -Wl,--fix-cortex-a8 -Wl,--no-warn-mismatch"
            ;;
    esac

    echo $ldflags
}

# $1 -- abi
android_cross_for_abi()
{
    local abi=$1
    local host_tag=$(uname -s | tr '[A-Z]' '[a-z]')-$(uname -m)
    local target=$(android_target_for_abi $abi)
    local tc_name=$target

    if [[ ($abi == x86) || ($abi == x86_64) ]]; then
        tc_name=$abi
    fi
    
    echo $NDK_DIR/toolchains/${tc_name}-${ANDROID_GCC_VERSION}/prebuilt/${host_tag}/bin/${target}
}

# $1 -- abi
android_gcc_for_abi()
{
    echo $(android_cross_for_abi $abi)-gcc
}

# $1 -- abi
android_gxx_for_abi()
{
    echo $(android_cross_for_abi $abi)-g++
}

# $1 -- abi
android_ar_for_abi()
{
    echo $(android_cross_for_abi $abi)-ar
}

# $1 -- abi
android_ranlib_for_abi()
{
    echo $(android_cross_for_abi $abi)-ranlib
}

# $1 -- abi
android_readelf_for_abi()
{
    echo $(android_cross_for_abi $abi)-readelf
}

# $1 -- abi
android_cpp_for_abi()
{
    local abi=$1
    
    echo $(android_gcc_for_abi $abi) $(android_cflags_for_abi $abi) -E
}




# $1 -- list of ABIs to build
# $2 -- configure options
android_build_qrencode()
{
    local ndk_abis=$1
    local configure_options="$2 --with-pic --without-tools"
    local src_dir=`pwd`

    for abi in $ndk_abis; do
        local build_dir="./build/$abi"
        local install_dir="$PREFIX/$abi"
	mkdir -p $build_dir
        cd $build_dir
        export CC=$(android_gcc_for_abi $abi)
        export CXX=$(android_gxx_for_abi $abi)
        export CPP=$(android_cpp_for_abi $abi)
        export CXXCPP=$CPP
        export AR=$(android_ar_for_abi $abi)
        export RANLIB=$(android_ranlib_for_abi $abi)
        export READELF=$(android_readelf_for_abi $abi)
        export CFLAGS=$(android_cflags_for_abi $abi)
        export LDFLAGS=$(android_ldflags_for_abi $abi)
        echo "Building for abi: $abi"
        echo "             CC:  $CC"
        echo "            CXX:  $CXX"
        echo "            CPP:  $CPP"
        echo "          CXXPP:  $CXXCPP"
        echo "             AR:  $AR"
        echo "         RANLIB:  $RANLIB"
        echo "        READELF:  $READELF"
        echo "         CFLAGS:  $CFLAGS"
        echo "        LDFLAGS:  $LDFLAGS"
	$src_dir/configure --prefix=$install_dir --host=$(android_target_for_abi $abi) $configure_options
	make -j $PARALLELISM
	make install
        cd $src_dir
    done
}


# $1 -- abi
boost_include_dir_for_abi()
{
    local abi=$1
    #local dir=$NDK_DIR/sources/boost+icu/$NDK_BOOST_VERSION/include
    local dir=$NDK_DIR/sources/boost/$NDK_BOOST_VERSION/include
    echo $dir
}

# $1 -- abi
boost_lib_dir_for_abi()
{
    local abi=$1
    #local dir=$NDK_DIR/sources/boost+icu/$NDK_BOOST_VERSION/libs/$abi/gnu-$ANDROID_GCC_VERSION
    local dir=$NDK_DIR/sources/boost/$NDK_BOOST_VERSION/libs/$abi/gnu-$ANDROID_GCC_VERSION
    echo $dir
}

# no params
ndk_includes()
{
    # -I$NDK_DIR/sources/icu/$NDK_ICU_VERSION/include
    local includes="-I$(boost_include_dir_for_abi $abi)"
    echo $includes
}

# $1 -- abi
ndk_stl_includes_for_abi()
{
    local abi=$1
    local ver=$ANDROID_GCC_VERSION
    local stl_includes="-I$NDK_DIR/sources/cxx-stl/gnu-libstdc++/$ver/include -I$NDK_DIR/sources/cxx-stl/gnu-libstdc++/$ver/libs/$abi/include"
    echo $stl_includes
}

# $1 -- abi
ndk_stl_lib_path_for_abi()
{
    local abi=$1
    echo "$NDK_DIR/sources/cxx-stl/gnu-libstdc++/$ANDROID_GCC_VERSION/libs/$abi"
}

# $1 -- abi
ndk_lib_paths_for_abi()
{
    # -L$NDK_DIR/sources/icu/$NDK_ICU_VERSION/libs/$abi
    echo "-L$(boost_lib_dir_for_abi $abi) -L$(ndk_stl_lib_path_for_abi $abi)"
}

# $1 -- abi
cxx_ldflags_for_abi()
{
    local abi=$1
    local ldflags=$(android_ldflags_for_abi $abi)
    if [[ $abi == arm64-v8a ]]; then
        ldflags="$ldflags -Wl,-rpath-link,$(boost_lib_dir_for_abi $abi) -Wl,-rpath-link,$(ndk_stl_lib_path_for_abi $abi) -Wl,-rpath-link,$(android_sysroot_for_abi $abi)/usr/lib"
    fi

    echo $ldflags
}


# $1 -- list of ABIs to build
# $2 -- configure options
android_make_current_directory()
{
    local ndk_abis=$1
    local configure_options="$2 --with-pic"
    local src_dir=`pwd`

    # todo: uncomment
    ./autogen.sh
    
    for abi in $ndk_abis; do
        local build_dir="./build/$abi"
        local install_dir="$PREFIX/$abi"
        local cpp_flags="$(ndk_includes) -I$install_dir/include"
	mkdir -p $build_dir
        cd $build_dir
        export CC=$(android_gcc_for_abi $abi)
        export CPP=$(android_cpp_for_abi $abi)
        export CXX=$(android_gxx_for_abi $abi)
        export CXXCPP=$CPP
        export AR=$(android_ar_for_abi $abi)
        export RANLIB=$(android_ranlib_for_abi $abi)
        export READELF=$(android_readelf_for_abi $abi)
        export CPPFLAGS=$cpp_flags
        export CFLAGS="$cpp_flags $(android_cflags_for_abi $abi)"
        export CXXFLAGS="$CFLAGS $(ndk_stl_includes_for_abi $abi)"
        export LDFLAGS="$(cxx_ldflags_for_abi $abi) $(ndk_lib_paths_for_abi $abi) -L$install_dir/lib"
        export PKG_CONFIG_PATH="$install_dir/lib/pkgconfig:$PKG_CONFIG_PATH"
        export BOOST_CPPFLAGS="-I$(boost_include_dir_for_abi $abi)"
        export BOOST_LDFLAGS="-L$(boost_lib_dir_for_abi $abi)"
        echo "Building for abi:  $abi"
        echo "configure options: $configure_options"
        echo "               CC:  $CC"
        echo "              CPP:  $CPP"
        echo "              CXX:  $CXX"
        echo "            CXXPP:  $CXXCPP"
        echo "               AR:  $AR"
        echo "           RANLIB:  $RANLIB"
        echo "          READELF:  $READELF"
        echo "         CPPFLAGS:  $CPPFLAGS"
        echo "           CFLAGS:  $CFLAGS"
        echo "         CXXFLAGS:  $CXXFLAGS"
        echo "          LDFLAGS:  $LDFLAGS"
        echo "  PKG_CONFIG_PATH:  $PKG_CONFIG_PATH"
        echo "   BOOST_CPPFLAGS:  $BOOST_CPPFLAGS"
        echo "    BOOST_LDFLAGS:  $BOOST_LDFLAGS"
	$src_dir/configure --prefix=$install_dir --host=$(android_target_for_abi $abi) $configure_options
	#make -j $PARALLELISM V=1
	make V=1 LIBS=-lgnustl_shared
	make install
        cd $src_dir
    done
}

android_copy_required_libs_for_abis()
{
    local boost_libs="chrono date_time filesystem iostreams locale program_options regex system thread"
    
    for abi in $NDK_ABIS; do
        local crystax_subdir=$abi
        if [[ ($abi == armeabi-v7a) || ($abi == armeabi-v7a-hard) ]]; then
            crystax_subdir="$abi/thumb"
        fi
        for lib in $boost_libs; do
            cp $NDK_DIR/sources/boost/$NDK_BOOST_VERSION/libs/$abi/gnu-$ANDROID_GCC_VERSION/libboost_${lib}.so $PREFIX/$abi/bin/
        done
        cp "$NDK_DIR/sources/cxx-stl/gnu-libstdc++/$ANDROID_GCC_VERSION/libs/$abi/libgnustl_shared.so" $PREFIX/$abi/bin/
        cp "$NDK_DIR/sources/crystax/libs/$crystax_subdir/libcrystax.so" $PREFIX/$abi/bin/
    done
}
