#!/bin/bash

# Set default configuration variables
OUT_DIR="out"
CONFIG_FILE="CONFIGS/clang/config-x86_64"
CLANG="/usr/bin/clang"
LLVM=1
LLVM_IAS=1

# Git configuration
git config --global user.email "xealea@xeadev.my.id"
git config --global user.name "lea"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debian)
            PACKAGE_TYPE="debian"
            shift
            ;;
        --archlinux)
            PACKAGE_TYPE="archlinux"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Out dir
mkdir -p $OUT_DIR

# Set configuration file in kernel source directory
cp "$CONFIG_FILE" out/.config

# Build kernel and headers
if [ "$PACKAGE_TYPE" == "archlinux" ]; then
    make O="$OUT_DIR" ARCH=x86_64 CC="$CLANG" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" -j$(nproc) all
else
    make O="$OUT_DIR" ARCH=x86_64 CC="$CLANG" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" -j$(nproc) bindeb-pkg
fi

# Check if kernel image and headers exist
if ! [[ -f "$OUT_DIR/arch/x86_64/boot/bzImage" && -d "$OUT_DIR/usr/include" ]]; then
    echo "Build failed. Missing kernel image or headers."
    exit 1
fi

# Create package
if [ "$PACKAGE_TYPE" == "debian" ]; then
    echo "Creating Debian package..."
    if [ ! -d "$OUT_DIR/debian" ]; then
        mkdir -p "$OUT_DIR/debian"
    fi
    cp "$OUT_DIR/../linux-headers-$(make O="$OUT_DIR" kernelrelease)_$(make O="$OUT_DIR" kernelversion)-$(make O="$OUT_DIR" kernelminor)_amd64.deb" "$OUT_DIR/debian/"
    cp "$OUT_DIR/../linux-image-$(make O="$OUT_DIR" kernelrelease)_$(make O="$OUT_DIR" kernelversion)-$(make O="$OUT_DIR" kernelminor)_amd64.deb" "$OUT_DIR/debian/"
    # Push debian packages to remote repository
    git add "$OUT_DIR/debian/*"
    git commit -m "Add Debian kernel packages for release $(make O="$OUT_DIR" kernelrelease)"
    git push https://"$GITHUB_TOKEN"@github.com/Brew-Tea/index.tea.kernel.git master
else
    echo "Creating Arch Linux package..."
    mkdir -p "$OUT_DIR/archlinux/usr/lib/modules/$(make O="$OUT_DIR" kernelrelease)/{build,source}"
    cp -a "$OUT_DIR/usr/include" "$OUT_DIR/archlinux/usr/"
    cp -a "$OUT_DIR/usr/src/linux-headers-$(make O="$OUT_DIR" kernelrelease)" "$OUT_DIR/archlinux/usr/src/"
    cp -a "$OUT_DIR/arch/x86_64/boot/bzImage" "$OUT_DIR/archlinux/boot/"
    tar -C "$OUT_DIR/archlinux" -cJf "$OUT_DIR/linux-$(make O="$OUT_DIR" kernelrelease)-x86_64.tar.zst"    
fi

# Upload Arch Linux package
if [ "$PACKAGE_TYPE" == "archlinux" ]; then
    echo "Uploading Arch Linux package..."
    if [ ! -d "archlinux" ]; then
        mkdir -p archlinux
    fi
    cp "$OUT_DIR/linux-$(make O="$OUT_DIR" kernelrelease)-x86_64.tar.zst" "archlinux/"
    # Push Arch Linux package to remote repository
    git add "archlinux/*"
    git commit -m "Add Arch Linux kernel package for release $(make O="$OUT_DIR" kernelrelease)"
    git push https://"$GITHUB_TOKEN"@github.com/Brew-Tea/index.tea.kernel.git master
fi
