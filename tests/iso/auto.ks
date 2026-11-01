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
# (run.sh, rst-disks.sh), kept for the check on the installed system.
%pre --log=/tmp/arkadeos-rst-pre.log
cat /proc/mdstat
mdadm --detail --scan
mdadm -v --detail-platform 2>&1 | head -25
mdadm -E /dev/sda 2>&1 | head -30
%end

%post --nochroot
{
    echo "== before the installer"; cat /tmp/arkadeos-rst-pre.log
    echo "== installer storage"; grep -i -E "Volume0|mdbiosraidarray" /tmp/storage.log | head -20
    grep -i -E "imsm|md12[0-9]|mdraid|BIOSRAID" /tmp/storage.log | head -40
    echo "== now"; cat /proc/mdstat
} > /tmp/arkadeos-rst.txt 2>&1
# T065: what the installer showed of the system's download.
{ grep -h "ArkadeOS download" /tmp/*.log; journalctl -b --no-pager | grep "ArkadeOS download"; } > /tmp/arkadeos-install-progress.txt 2>&1
# Into /etc of the new system: its /var/log only exists from the first boot.
for root in /mnt/sysroot /mnt/sysimage; do
    [ -d "${root}/etc" ] && cp /tmp/arkadeos-rst.txt /tmp/arkadeos-install-progress.txt "${root}/etc/" || true
done
%end
