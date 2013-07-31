#!/bin/bash

DISTROS=(
    # "debian:squeeze"
    # "ubuntu:maverick"
    "centos:5"
    "fedora:14"
)

ARCH=amd64
TARGET=${TARGET:-.}
PASSWORD=${PASSWORD:-supersecurepassword}
KEY=${KEY:-$HOME/.ssh/id_dsa.pub}
DISTRO_NAME=""
DEVICE=""

exec 2> /tmp/$$.log
set -x

trap do_exit ERR

function do_exit {
    echo "ERROR: Couldn't build distro ${1}-${2}... error log ($$.log):"

    tail -n 20 /tmp/$$.log

    if [ -e /tmp/${DISTRO_NAME} ]; then
	umount /tmp/${DISTRO_NAME}
	rmdir /tmp/${DISTRO_NAME}
    fi

    umount ${DEVICE} > /dev/null 2>&1

    [ ! -z "${DEVICE}" ] && losetup -d ${DEVICE} 1>/dev/null 2>&1
#    [ -e ${TARGET}/${DISTRO_NAME}.raw ] && rm ${TARGET}/${DISTRO_NAME}.raw 
    [ -e ${TARGET}/${DISTRO_NAME}.qcow2 ] && rm ${TARGET}/${DISTRO_NAME}.qcow2 
    [ -e ${TARGET}/${DISTRO_NAME}-initrd ] && rm ${TARGET}/${DISTRO_NAME}-initrd 
    [ -e ${TARGET}/${DISTRO_NAME}-linux ] && rm ${TARGET}/${DISTRO_NAME}-linux

    exit 1
}

for distro in ${DISTROS[@]}; do
    vendor=${distro%%:*}
    flavor=${distro##*:}
    DISTRO_NAME=${vendor}-${flavor}

    echo "Building $DISTRO_NAME"

    echo " - Creating file system"
    dd if=/dev/zero of=${TARGET}/${DISTRO_NAME}.raw bs=1024 count=500K >&2 || do_exit $vendor $distro
    mke2fs -F -j ${TARGET}/${DISTRO_NAME}.raw >&2 || do_exit $vendor $distro xx
    
    mkdir -p /tmp/${DISTRO_NAME}
    losetup -f ${TARGET}/${DISTRO_NAME}.raw >&2 || do_exit $vendor $distro

    DEVICE=`losetup -a | grep "${DISTRO_NAME}.raw" | tail -1 | cut -d: -f1`

    echo " - Mounted raw image on ${DEVICE}"

    mount -t ext3 ${DEVICE} /tmp/${DISTRO_NAME} >&2 || do_exit $vendor $distro $DEVICE

    echo " - Bootstrapping file system"
    case ${vendor} in
	debian|ubuntu)
	    debootstrap --include=openssh-server ${flavor} \
		/tmp/${DISTRO_NAME} http://mirrors.kernel.org/${vendor} >&2 || do_exit $vendor $distro $DEVICE
	    wget -q http://mirrors.kernel.org/${vendor}/dists/${flavor}/main/installer-${ARCH}/current/images/netboot/${vendor}-installer/${ARCH}/initrd.gz -O ${TARGET}/${DISTRO_NAME}-initrd
	    wget -q http://mirrors.kernel.org/${vendor}/dists/${flavor}/main/installer-${ARCH}/current/images/netboot/${vendor}-installer/${ARCH}/linux -O ${TARGET}/${DISTRO_NAME}-linux
	    ;;
	fedora|centos)
	    mock_arch=$ARCH
	    mock_dist=$vendor
	    [ $mock_arch == "amd64" ] && mock_arch=x86_64
	    [ $mock_dist == "centos" ] && mock_dist=epel

	    mock -r ${mock_dist}-${flavor}-${mock_arch} --init >&2 || do_exit $vendor $distro $DEVICE
	    mock -r ${mock_dist}-${flavor}-${mock_arch} --install openssh-server

	    if [ "$vendor" == "fedora" ]; then
		url="http://mirrors.kernel.org/fedora/releases/${flavor}/Fedora/${mock_arch}/os/images/pxeboot"
	    else # epel/centos
		url="http://mirrors.kernel.org/centos/${flavor}/os/${mock_arch}/images/pxeboot"
	    fi

	    wget -q $url/initrd.img -O ${TARGET}/${DISTRO_NAME}-initrd
	    wget -q $url/vmlinuz -O ${TARGET}/${DISTRO_NAME}-linux

	    # hackity hack hack hack.  Mock, I hate you
	    tar -cf - /var/lib/mock/${mock_dist}-${flavor}-${mock_arch}/root | tar -C /tmp/${DISTRO_NAME} --strip-components=5 -xf -
	    ;;
	*)
	    echo "Don't know how to make a distro from vendor ${vendor}"
	    exit 1
	    ;;
    esac

    mkdir -p /tmp/${DISTRO_NAME}/root/.ssh
    chmod 700 /tmp/${DISTRO_NAME}/root/.ssh
    if [ -e ${KEY} ]; then
	cat ${KEY} > /tmp/${DISTRO_NAME}/root/.ssh/authorized_keys

    fi

    if [ -x /tmp/${DISTRO_NAME}/usr/sbin/chpasswd ]; then
	cmd="echo root:${PASSWORD} | chpasswd root"
	chroot /tmp/${DISTRO_NAME} /bin/bash -c "echo root:${PASSWORD} | /usr/sbin/chpasswd root"
    fi

    echo " - Unmounting"
    umount /tmp/${DISTRO_NAME}
    rmdir /tmp/${DISTRO_NAME}

    losetup -d ${DEVICE}

    echo " - Converting image"
    qemu-img convert -c -O qcow2 ${TARGET}/${DISTRO_NAME}.raw ${TARGET}/${DISTRO_NAME}.qcow2
    rm ${TARGET}/${DISTRO_NAME}.raw
done

echo $$.log
