#!/bin/bash
#
# Thanks to Tkkg1994 and djb77 for the script
#
# MoRoKernel Build Script v1.6
#

# SETUP
# -----
export ARCH=arm64
export SUBARCH=arm64
export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-
#export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-linaro-6.3/bin/aarch64-
#export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-cortex_a53-linux-gnueabi-GNU-6.3.0/bin/aarch64-cortex_a53-linux-gnueabi-
#export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-ubertc-6.3.1-20170503/bin/aarch64-linux-android-
#export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-sabermod-7.0/bin/aarch64-
#export BUILD_CROSS_COMPILE=/home/moro/kernel/toolchains/aarch64-sabermod-5.4/bin/aarch64-
export CROSS_COMPILE=$BUILD_CROSS_COMPILE
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`


RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts/exynos
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include
PAGE_SIZE=2048
DTB_PADDING=0

DEFCONFIG=moro_defconfig
DEFCONFIG_S8PLUS=moro-dream2_defconfig
DEFCONFIG_S8=moro-dream_defconfig

export K_VERSION="v1.0"
export REVISION="RC"
export KBUILD_BUILD_VERSION="1"
S8DEVICE="S8"
KERNEL="MoRoStock"
DREAM2_LOG=S8Plus_build.log
DREAM_LOG=S8_build.log
PORT=0


# FUNCTIONS
# ---------
FUNC_DELETE_PLACEHOLDERS()
{
	find . -name \.placeholder -type f -delete
        echo "Placeholders Deleted from Ramdisk"
        echo ""
}

FUNC_CLEAN_DTB()
{
	if ! [ -d $RDIR/arch/$ARCH/boot/dts ] ; then
		echo "no directory : "$RDIR/arch/$ARCH/boot/dts""
	else
		echo "rm files in : "$RDIR/arch/$ARCH/boot/dts/*.dtb""
		rm $RDIR/arch/$ARCH/boot/dts/*.dtb
		rm $RDIR/arch/$ARCH/boot/dtb/*.dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-zImage
	fi
}

FUNC_BUILD_KERNEL()
{
	echo ""
        echo "build common config="$KERNEL_DEFCONFIG ""
        echo "build variant config="$MODEL ""

	cp -f $RDIR/arch/$ARCH/configs/$DEFCONFIG $RDIR/arch/$ARCH/configs/tmp_defconfig
	cat $RDIR/arch/$ARCH/configs/$KERNEL_DEFCONFIG >> $RDIR/arch/$ARCH/configs/tmp_defconfig

	FUNC_CLEAN_DTB

	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			tmp_defconfig || exit -1
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo ""

	rm -f $RDIR/arch/$ARCH/configs/tmp_defconfig
}

FUNC_BUILD_DTB()
{
	[ -f "$DTCTOOL" ] || {
		echo "You need to run ./build.sh first!"
		exit 1
	}
	case $MODEL in
	G950)
		DTSFILES="exynos8895-dreamlte_eur_open_00 exynos8895-dreamlte_eur_open_01
			exynos8895-dreamlte_eur_open_02 exynos8895-dreamlte_eur_open_03
			exynos8895-dreamlte_eur_open_04 exynos8895-dreamlte_eur_open_05
			exynos8895-dreamlte_eur_open_07 exynos8895-dreamlte_eur_open_08
			exynos8895-dreamlte_eur_open_09 exynos8895-dreamlte_eur_open_10"
		;;
	G955)
		DTSFILES="exynos8895-dream2lte_eur_open_01 exynos8895-dream2lte_eur_open_02
			exynos8895-dream2lte_eur_open_03 exynos8895-dream2lte_eur_open_04
			exynos8895-dream2lte_eur_open_05 exynos8895-dream2lte_eur_open_06
			exynos8895-dream2lte_eur_open_07 exynos8895-dream2lte_eur_open_08
			exynos8895-dream2lte_eur_open_09 exynos8895-dream2lte_eur_open_10"
		;;
	*)
		echo "Unknown device: $MODEL"
		exit 1
		;;
	esac

	mkdir -p $OUTDIR $DTBDIR
	cd $DTBDIR || {
		echo "Unable to cd to $DTBDIR!"
		exit 1
	}
	rm -f ./*
	echo "Processing dts files."
	for dts in $DTSFILES; do
		echo "=> Processing: ${dts}.dts"
		${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
		echo "=> Generating: ${dts}.dtb"
		$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
	done
	echo "Generating dtb.img."
	$RDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
	echo "Done."
}

FUNC_BUILD_RAMDISK()
{
	echo ""
	echo "Building Ramdisk"
	mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
	mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb
	
	cd $RDIR/build
	mkdir temp
	cp -rf aik/. temp
	cp -rf ramdisk/. temp
	
	rm -f temp/split_img/boot.img-zImage
	rm -f temp/split_img/boot.img-dtb
	mv $RDIR/arch/$ARCH/boot/boot.img-zImage temp/split_img/boot.img-zImage
	mv $RDIR/arch/$ARCH/boot/boot.img-dtb temp/split_img/boot.img-dtb
	cd temp

	case $MODEL in
	G955)
		echo "Ramdisk for G955"
		;;
	G950)
		echo "Ramdisk for G950"
		sed -i 's/G955/G950/g' ramdisk/default.prop
		sed -i 's/dream2/dream/g' ramdisk/default.prop
		sed -i 's/dream2/dream/g' ramdisk/property_contexts
		sed -i 's/dream2/dream/g' ramdisk/service_contexts
		sed -i 's/SRPPH16A001KU/SRPPK02A001KU/g' split_img/boot.img-board
		;;
	esac

		echo "Done"

	./repackimg.sh

	cp -f image-new.img $RDIR/build
	cd ..
	rm -rf temp
	echo SEANDROIDENFORCE >> image-new.img
	mv image-new.img $MODEL-boot.img
}

FUNC_BUILD_FLASHABLES()
{
	cd $RDIR/build
	mkdir temp2
	cp -rf zip/common/. temp2
    	#cp -rf zip/$MODEL/. temp2
    	mv *.img temp2/
	cd temp2
	echo ""
	echo "Compressing kernels..."
	tar cv *.img | xz -9 > kernel.tar.xz
	mv kernel.tar.xz moro/
	rm -f *.img
	if [ $prompt == "3" ]; then
	    zip -9 -r ../$KERNEL-$DEVICE-N-$K_VERSION.zip *
	else
	    zip -9 -r ../$KERNEL-$MODEL-$DEVICE-N-$K_VERSION.zip *
	fi
	cd ..
    	rm -rf temp2
}



# MAIN PROGRAM
# ------------

MAIN()
{

(
	START_TIME=`date +%s`
	FUNC_DELETE_PLACEHOLDERS
	FUNC_BUILD_KERNEL
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	FUNC_BUILD_FLASHABLES
	END_TIME=`date +%s`
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time is $ELAPSED_TIME seconds"
	echo ""
) 2>&1 | tee -a ./$LOG

	echo "Your flasheable release can be found in the build folder"
	echo ""
}

MAIN2()
{

(
	START_TIME=`date +%s`
	FUNC_DELETE_PLACEHOLDERS
	FUNC_BUILD_KERNEL
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	END_TIME=`date +%s`
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time is $ELAPSED_TIME seconds"
	echo ""
) 2>&1 | tee -a ./$LOG

	echo "Your flasheable release can be found in the build folder"
	echo ""
}


# PROGRAM START
# -------------
clear
echo "***********************"
echo "MoRoKernel Build Script"
echo "***********************"
echo ""
echo ""
echo "Build Kernel for:"
echo ""
echo "(1) S8 SM-G950F"
echo "(2) S8 Plus SM-G955F"
echo "(3) S8 + S8 Plus"
echo ""
read -p "Select an option to compile the kernel " prompt


if [ $prompt == "1" ]; then
    MODEL=G950
    DEVICE=$S8DEVICE
    KERNEL_DEFCONFIG=$DEFCONFIG_S8
    LOG=$DREAM_LOG
    export KERNEL_VERSION="$KERNEL-$MODEL-$DEVICE-N-$K_VERSION"
    echo "S8 G950F Selected"
    MAIN
elif [ $prompt == "2" ]; then
    MODEL=G955
    DEVICE=$S8DEVICE
    KERNEL_DEFCONFIG=$DEFCONFIG_S8PLUS
    LOG=$DREAM2_LOG
    export KERNEL_VERSION="$KERNEL-$MODEL-$DEVICE-N-$K_VERSION"
    echo "S8 Plus G955F Selected"
    MAIN
elif [ $prompt == "3" ]; then
    MODEL=G950
    DEVICE=$S8DEVICE
    KERNEL_DEFCONFIG=$DEFCONFIG_S8
    LOG=$DREAM_LOG
    export KERNEL_VERSION="$KERNEL-$MODEL-$DEVICE-N-$K_VERSION"
    echo "S8 + S8 Plus Selected"
    echo "Compiling S8 ..."
    MAIN2
    MODEL=G955
    KERNEL_DEFCONFIG=$DEFCONFIG_S8PLUS
    LOG=$DREAM2_LOG
    export KERNEL_VERSION="$KERNEL-$MODEL-$DEVICE-N-$K_VERSION"
    echo "Compiling S8 Plus ..."
    MAIN
fi


