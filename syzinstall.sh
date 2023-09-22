#!/bin/bash
#birdsitex://@sickthecat

# Stop on any error
set -e

# Update and install dependencies
echo "Updating system and installing dependencies..."
apt-get update
apt-get install -y \
    flex bison libc6-dev libc6-dev-i386 \
    linux-libc-dev linux-libc-dev:i386 \
    g++ git libelf-dev make

# Install Go
echo "Installing Go..."
wget https://dl.google.com/go/go1.17.3.linux-amd64.tar.gz
tar -xvf go1.17.3.linux-amd64.tar.gz
mv go /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin

# Build Linux Kernel
echo "Cloning and building Linux Kernel..."
mkdir ~/linux && cd ~/linux
git clone https://github.com/torvalds/linux.git
cd linux
git checkout v5.12
cp /boot/config-$(uname -r) .config
make olddefconfig
scripts/config --disable CONFIG_KCOV
scripts/config --enable CONFIG_KASAN
scripts/config --enable CONFIG_KASAN_INLINE
make -j$(nproc)

# Install QEMU
echo "Installing QEMU..."
apt-get install -y qemu-system-x86

# Clone and build syzkaller
echo "Cloning and building syzkaller..."
go get -u -d github.com/google/syzkaller/...
cd ~/go/src/github.com/google/syzkaller
make generate
make

# Create working directory for syzkaller
echo "Creating syzkaller working directory..."
mkdir ~/syzkaller-workdir

# Create configuration file for syzkaller
echo "Creating configuration for syzkaller..."
cat <<EOL > ~/syzkaller-workdir/syz.config
{
    "target": "linux/amd64",
    "http": "127.0.0.1:56741",
    "workdir": "/root/syzkaller-workdir",
    "kernel_obj": "/root/linux",
    "image": "/root/stretch.img",
    "sshkey": "/root/.ssh/id_rsa",
    "syzkaller": "/root/go/src/github.com/google/syzkaller",
    "procs": 2,
    "type": "qemu",
    "vm": {
        "count": 4,
        "kernel": "/root/linux/arch/x86/boot/bzImage",
        "cpu": 2,
        "mem": 2048
    }
}
EOL

echo "Syzkaller setup is complete. You can now run syzkaller."
