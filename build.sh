#!/bin/bash

#build the bootloader image

. ./common.sh
. ./image_utils.sh
. ./shim_utils.sh

print_help() {
  echo "Usage: ./build.sh output_path shim_path rootfs_dir"
  echo "Valid named arguments (specify with 'key=value'):"
  echo "  quiet - Don't use progress indicators which may clog up log files."
  echo "  arch  - Set this to 'arm64' to specify that the shim is for an ARM chromebook."
}

assert_root
assert_deps "cpio binwalk pcregrep realpath cgpt mkfs.ext4 mkfs.ext2 fdisk lz4"
assert_args "$3"
parse_args "$@"

output_path=$(realpath -m "${1}")
shim_path=$(realpath -m "${2}")
rootfs_dir=$(realpath -m "${3}")

echo "reading the shim image"
initramfs_dir=/tmp/shim_initramfs
kernel_img=/tmp/kernel.img
rm -rf $initramfs_dir $kernel_img
extract_initramfs_full $shim_path $initramfs_dir $kernel_img "${args['arch']}"

echo "patching initramfs"
patch_initramfs $initramfs_dir

echo "creating disk image"
rootfs_size=$(du -sm $rootfs_dir | cut -f 1)
rootfs_part_size=$(($rootfs_size * 12 / 10 + 5))
#create a 20mb bootloader partition
#rootfs partition is 20% larger than its contents
create_image $output_path 20 $rootfs_part_size

echo "creating loop device for the image"
image_loop=$(create_loop ${output_path})

echo "creating partitions on the disk image"
create_partitions $image_loop $kernel_img

echo "copying data into the image"
populate_partitions $image_loop $initramfs_dir $rootfs_dir "${args['quiet']}"
rm -rf $initramfs_dir $kernel_img

echo "cleaning up loop devices"
losetup -d $image_loop
echo "done"