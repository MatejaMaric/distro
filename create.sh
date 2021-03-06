#!/bin/bash
echo "Make sure you have build-essentials, musl, kernel-headers-musl, grub, libisoburn(xorriso), cpio and wget installed!"

KERNEL_VERSION=5.8.2
KERNEL_DIRECTORY=linux-$KERNEL_VERSION
KERNEL_ARCHIVE=$KERNEL_DIRECTORY.tar.xz
KERNEL_URL=https://www.kernel.org/pub/linux/kernel/v5.x/$KERNEL_ARCHIVE

BUSYBOX_VERSION=1.32.0
BUSYBOX_DIRECTORY=busybox-$BUSYBOX_VERSION
BUSYBOX_ARCHIVE=$BUSYBOX_DIRECTORY.tar.bz2
BUSYBOX_URL=https://busybox.net/downloads/$BUSYBOX_ARCHIVE

[[ ! -d ml-src ]] && mkdir ml-src
cd ml-src

#DOWNLOAD SOURCE
[[ ! -f $KERNEL_ARCHIVE ]] && wget $KERNEL_URL
[[ ! -f $BUSYBOX_ARCHIVE ]] && wget $BUSYBOX_URL

[[ ! -d $KERNEL_DIRECTORY ]] && tar xf $KERNEL_ARCHIVE
[[ ! -d $BUSYBOX_DIRECTORY ]] && tar xf $BUSYBOX_ARCHIVE

#COMPILING
cd $KERNEL_DIRECTORY
[[ ! -f .config ]] && make defconfig
#Set OS name
sed -i "s/CONFIG_DEFAULT_HOSTNAME=\"(none)\"/CONFIG_DEFAULT_HOSTNAME=\"MatejaOS\"/" .config
make -j`nproc`
cp ./arch/x86/boot/bzImage ../vmlinux
cd ..

cd $BUSYBOX_DIRECTORY
[[ ! -f .config ]] && make defconfig
#BusyBox static linking
sed -i "s/# CONFIG_STATIC is not set/CONFIG_STATIC=y/" .config
sed -i "s/gcc/musl-gcc/" Makefile
make -j`nproc`
cp busybox ..
cd ..

#INITRAMFS
[[ ! -d initramfs-root ]] && mkdir initramfs-root
cd initramfs-root

#Filesystem Hierarchy Standard
mkdir -p ./{bin,boot,dev,etc/{opt,sgml,X11,xml},home,lib,media,mnt,opt,sbin,srv,tmp,usr/{bin,include,lib,local,sbin,share,src},proc,root,run,sys,var/{cache,lib,lock,log,mail,opt,run,spool/mail,tmp}}

#Basic Initramfs Directory Structure
#mkdir --parents ./{bin,dev,etc,lib,lib64,mnt/root,proc,root,sbin,sys}

#Link tools to busybox
cd bin
cp ../../busybox .
for i in `./busybox --list`
do
  ln -s busybox $i
done
cd ..

#initramfs init script
cat > ./init << EOF
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sysfs /sys

#Disable kernel messages
echo 0 > /proc/sys/kernel/printk

#Dynamic devices
mdev -s

echo 1 > /proc/sys/kernel/sysrq

echo "Welcome to MatejaOS!"

echo "You can turn off the system using SysRq."
echo "echo s > /proc/sysrq-trigger"
echo "echo o > /proc/sysrq-trigger"

while true
do
    #Job control for BusyBox shell
	setsid cttyhack sh
	sleep 1
done

##FOR FUTURE USE (SWITCH ROOT TO HARD DRIVE)
#mkdir /mnt/root
#rescue_shell() {
#    echo "Something went wrong. Dropping to a shell."
#    exec sh
#}
#cmdline() {
#    local value
#    value=" $(cat /proc/cmdline) "
#    value="${value##* ${1}=}"
#    value="${value%% *}"
#    [ "${value}" != "" ] && echo "${value}"
#}
## Mount the root filesystem.
#mount -o ro $(findfs $(cmdline root)) /mnt/root || rescue_shell
## Clean up.
#umount /proc
#umount /sys
## Switch to hard drive
#exec switch_root /mnt/root /sbin/init
EOF
chmod +x init

#create initramfs
find . | cpio --create --format=newc > ../initramfs

cd ..

#CREATE ISO
mkdir -p iso-dir/boot/grub
cp vmlinux initramfs iso-dir/boot/
cat > iso-dir/boot/grub/grub.cfg << EOF
set timeout=3
set default=0
menuentry 'MatejaOS' {
  linux  /boot/vmlinux
  initrd /boot/initramfs
}
EOF
grub-mkrescue -o ../ml.iso iso-dir

echo "Finished!"
echo "You can boot the iso file with command:"
echo "qemu-system-x86_64 -m 512 -cdrom ml.iso -boot d"
