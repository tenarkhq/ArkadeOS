# ISO test only (T022): answers every installer question, so the install runs
# by itself in the VM. Prepended to iso/arkadeos.ks.
text
lang en_US.UTF-8
keyboard us
timezone Europe/Budapest --utc
zerombr
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
