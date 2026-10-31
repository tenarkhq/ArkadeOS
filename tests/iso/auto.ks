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

# T054: what the installer found of the Intel RST array on the test disks
# (run.sh), kept for the check on the installed system.
%pre --log=/tmp/arkadeos-rst-pre.log
cat /proc/mdstat
mdadm --detail --scan
mdadm --detail-platform 2>&1 | head -5
%end

%post --nochroot
{
    echo "== before the installer"; cat /tmp/arkadeos-rst-pre.log
    echo "== installer storage"; grep -i -E "imsm|md12[0-9]|mdraid|BIOSRAID" /tmp/storage.log | head -40
    echo "== now"; cat /proc/mdstat
} > /mnt/sysimage/var/log/arkadeos-rst.txt 2>&1 || true
%end
