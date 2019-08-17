#!/bin/sh

apt update
apt install -y xorriso cpio

echo "Extracting image"
mkdir -p /tmp/isofiles/
xorriso -osirrox on -indev /debian.iso -extract / /tmp/isofiles/

echo "Decompressing initrd"
cd /tmp
chmod +w -R isofiles/install.amd/
gunzip isofiles/install.amd/initrd.gz
echo "Adding preseed config"
cp /files/files/preseed.cfg .
echo preseed.cfg | cpio -H newc -o -A -F isofiles/install.amd/initrd
gzip isofiles/install.amd/initrd
chmod -w -R isofiles/install.amd/


cd isofiles
sed -i "s/^default installgui/\#default installgui/g" isolinux/gtk.cfg
sed -i '1s/^/default install\n/' isolinux/txt.cfg
sed -i '/menu/a      menu default' isolinux/txt.cfg
sed -i "s/timeout 0/timeout 5/g" isolinux/isolinux.cfg

sed -i '1s/^/set timeout=1\n/' boot/grub/grub.cfg
sed -i '1s/^/set default=\"1\"\n/' boot/grub/grub.cfg

echo "Building new bootable image"
orig_iso=/debian.iso
new_files=/tmp/isofiles
new_iso=/files/images/debian.iso
mbr_template=isohdpfx.bin

# Extract MBR template file to disk
dd if="$orig_iso" bs=1 count=432 of="$mbr_template"

# Create the new ISO image
xorriso -as mkisofs \
   -r -V 'Debian 9.9.0 amd64 n' \
   -o "$new_iso" \
   -J -J -joliet-long -cache-inodes \
   -isohybrid-mbr "$mbr_template" \
   -b isolinux/isolinux.bin \
   -c isolinux/boot.cat \
   -boot-load-size 4 -boot-info-table -no-emul-boot \
   -eltorito-alt-boot \
   -e boot/grub/efi.img \
   -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
   "$new_files"
