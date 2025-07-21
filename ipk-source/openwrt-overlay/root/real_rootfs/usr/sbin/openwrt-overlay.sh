#!/bin/sh

newroot() {
    /bin/echo "Begin mount fix process to make a usable userspace for OpenWRT Subsystem"

    # Forcefully unmount /etc
    /bin/echo "Unmounting the bind at /etc"
    /bin/umount -lf /etc

    # Remount root filesystem as read-write
    /bin/echo "Remounting / as read-write"
    /bin/mount -o remount,rw /
    
    # Make mount namespaces private
    mount --make-rprivate /

    # Ensure necessary directories exist for overlay and pivot_root
    /bin/echo "Creating new overlay system"
    if [ ! -d /usrdata/rootfs ]; then
        mkdir -p /usrdata/rootfs
    fi
    if [ ! -d /usrdata/rootfs-workdir ]; then
        mkdir -p /usrdata/rootfs-workdir
    fi
    if [ ! -d /rootfs ]; then
        mkdir -p /rootfs
    fi

    # Mount the new overlay filesystem
    /bin/mount -t overlay overlay -o lowerdir=/,upperdir=/usrdata/rootfs,workdir=/usrdata/rootfs-workdir /rootfs

    # Create the real_rootfs directory in the new root
    if [ ! -d /rootfs/real_rootfs ]; then
        mkdir -p /rootfs/real_rootfs
    fi

    /bin/echo "Pivoting Root / to /rootfs; Be back soon!!"
    /sbin/pivot_root /rootfs /rootfs/real_rootfs >/dev/null 2>&1

    # Move the mounted filesystems to the new locations
    /bin/echo "Setting up final shared mounts"
    /bin/mount --bind /real_rootfs/sys /sys
    /bin/mount --bind /real_rootfs/proc /proc
    /bin/mount --bind /real_rootfs/tmp /tmp
    /bin/mount --bind /real_rootfs/dev /dev
    /bin/mount --bind /real_rootfs/firmware /firmware
    /bin/mount --bind /real_rootfs/usrdata /usrdata
    /bin/mount --bind /real_rootfs/persist /persist
    /bin/mount --bind /real_rootfs/cache /cache
    /bin/mount --bind /real_rootfs/data /data
    /bin/mount --bind /real_rootfs/run /run
    /bin/mount --bind /real_rootfs/etc/machine-id /etc/machine-id
    /bin/mount --bind /real_rootfs/var/volatile /var/volatile
    /bin/mount --bind /real_rootfs/systemrw /systemrw
    /bin/mount --bind /etc /real_rootfs/etc
    
    # Final remount of orginal rootfs as RO
    /bin/mount -o remount,ro /real_rootfs
    echo "Complete"
}

newroot

