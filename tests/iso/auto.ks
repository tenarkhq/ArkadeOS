# ISO test only (T022): answers every installer question, so the install runs
# by itself in the VM. Prepended to iso/arkadeos.ks.
text
lang en_US.UTF-8
keyboard us
timezone Europe/Budapest --utc
zerombr
# Only the first disk is installed to; the Intel RST test disks (run.sh) stay.
ignoredisk --only-use=vda
clearpart --all --initlabel --disklabel=gpt
autopart --type=btrfs --encrypted --passphrase=arkade-luks
rootpw --lock
user --name=arkade --groups=wheel --password=arkade-test --plaintext
sshkey --username=root "@SSHKEY@"
reboot

%post --erroronfail
# The test reaches the installed system over SSH, which ArkadeOS keeps off.
systemctl enable sshd.service
%end

# T026: the app choice of the installer: three apps; MSI is refused, the VM
# is no MSI laptop.
%addon org_arkadeos_apps
firefox heroic qbittorrent msi
%end

# T054: what the installer found of the Intel RST array on the test disks
# (run.sh), kept for the check on the installed system.
%pre --log=/tmp/arkadeos-rst-pre.log
# The two SATA disks (sda, sdb; the install disk is virtio) become an RST
# mirror, as made in the firmware's RST setup, before the installer scans.
if grep -qw mdadm.imsm.test=1 /proc/cmdline && [ -b /dev/sda ] && [ -b /dev/sdb ]; then
    mdadm --create /dev/md/imsm0 --run -e imsm -n 2 /dev/sda /dev/sdb
    mdadm --create /dev/md/Volume0 --run --assume-clean -l 1 -n 2 /dev/md/imsm0
    udevadm settle
fi
cat /proc/mdstat
mdadm --detail --scan
mdadm --detail-platform 2>&1 | head -5
%end

%post --nochroot
{
    echo "== before the installer"; cat /tmp/arkadeos-rst-pre.log
    echo "== installer storage"; grep -i -E "imsm|md12[0-9]|mdraid|BIOSRAID" /tmp/storage.log | head -40
    echo "== now"; cat /proc/mdstat
} > /tmp/arkadeos-rst.txt 2>&1
for root in /mnt/sysroot /mnt/sysimage; do
    [ -d "${root}/var/log" ] && cp /tmp/arkadeos-rst.txt "${root}/var/log/" || true
done
%end
