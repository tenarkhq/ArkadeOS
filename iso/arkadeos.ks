# ArkadeOS installer (T022): Fedora's network installer with this kickstart.
# The user picks language, disk (also "next to Windows", T023) and account as
# usual; the system itself is the ArkadeOS image that fits the graphics card,
# pulled from the registry:
#   NVIDIA GTX 16xx / RTX 20xx or newer (also next to an Intel/AMD iGPU)
#                                                  ->  arkadeos-nvidia
#   AMD or Intel only, or an older NVIDIA card     ->  arkadeos
#   (NVIDIA's driver needs Turing, device id 0x1e00 and up; older cards run
#   on the open nouveau driver of the plain image)
# Boot options override it: arkadeos.image=<name>, arkadeos.tag=<tag>.

# Hardware check before anything is written (T053). A disk mode Linux cannot
# use stops the installer with the steps to fix it; other findings are kept
# and shown after the first login. arkadeos.hwcheck=off skips the stop.
%pre --erroronfail --log=/tmp/arkadeos-hwcheck.log
#!/bin/bash
sys=${ARKADEOS_SYSFS:-/sys}
out=${ARKADEOS_TMP:-/tmp}/arkadeos-hwcheck.txt
: > "${out}"
note() { printf '%s\n%s\n\n' "$1" "$2" >> "${out}"; }
stop=0
grep -qw arkadeos.hwcheck=off "${ARKADEOS_CMDLINE:-/proc/cmdline}" && stop=off
for dev in "${sys}"/bus/pci/devices/*; do
    [ -f "${dev}/class" ] || continue
    class=$(cat "${dev}/class") vendor=$(cat "${dev}/vendor") device=$(cat "${dev}/device")
    case "${class}" in
        0x0104*) [ "${vendor}" = 0x1022 ] && [ "${stop}" = 0 ] && stop=1 ;;
        0x03*)
            if [ "${vendor}" = 0x10de ] && [ $(( device )) -lt $(( 0x1e00 )) ]; then
                note "Older NVIDIA card (before GTX 16 / RTX 20): it runs on the open nouveau driver, games are slower than on Windows." \
                    "Régebbi NVIDIA kártya (GTX 16 / RTX 20 előtti): a nyílt nouveau driverrel megy, a játékok lassabbak, mint Windowson."
            fi
            ;;
        0x0280*|0x0200*)
            if [ ! -e "${dev}/driver" ]; then
                note "Network chip ${vendor#0x}:${device#0x} has no driver yet: use another connection (Ethernet, a USB Wi-Fi adapter) until an update brings one." \
                    "A(z) ${vendor#0x}:${device#0x} hálózati chiphez még nincs driver: addig más kapcsolat kell (Ethernet, USB Wi-Fi adapter), amíg egy frissítés el nem hozza."
            fi
            ;;
    esac
done
if [ "${stop}" = 1 ]; then
    cat <<'MSG'
=====================================================================
The disks are in AMD RAID mode, which Linux cannot use.
A lemezek AMD RAID módban vannak, ezt a Linux nem tudja használni.

Switch the disk mode to AHCI in the BIOS, then start the installer again.
Kapcsold a lemez módját AHCI-ra a BIOS-ban, majd indítsd újra a telepítőt.

If Windows is on this machine, set Windows up for AHCI first, or it will
not start after the switch (no reinstall needed):
Ha Windows is van a gépen, előbb azt készítsd fel AHCI-ra, különben a váltás
után nem indul el (újratelepítés nem kell):
 1. If BitLocker is on: save the recovery key (aka.ms/myrecoverykey) and
    suspend BitLocker (Control Panel > BitLocker > Suspend protection).
    Ha be van kapcsolva a BitLocker: mentsd el a helyreállító kulcsot
    (aka.ms/myrecoverykey), és függeszd fel a BitLockert.
 2. In Windows, as administrator: bcdedit /set {current} safeboot minimal
    Windowsban, rendszergazdaként: bcdedit /set {current} safeboot minimal
 3. Restart into the BIOS, set the disk mode (SATA / RAID mode) to AHCI.
    Újraindítás a BIOS-ba, a lemez módja (SATA / RAID mode) legyen AHCI.
 4. Windows starts in safe mode; as administrator:
    bcdedit /deletevalue {current} safeboot, then restart.
    A Windows csökkentett módban indul; rendszergazdaként:
    bcdedit /deletevalue {current} safeboot, majd újraindítás.
 5. Windows works normally again: start the ArkadeOS installer.
    A Windows újra rendesen megy: indítsd az ArkadeOS telepítőt.
=====================================================================
MSG
    exit 1
fi
sb=$(ls "${sys}"/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1)
if [ -n "${sb}" ] && [ "$(od -An -t u1 -j 4 -N 1 "${sb}" | tr -d ' ')" = 1 ]; then
    note "Secure Boot is on: at the first restart a blue screen asks to enroll a key: Enroll MOK, Continue, Yes, password universalblue." \
        "A Secure Boot be van kapcsolva: az első újraindításkor egy kék képernyő kulcs felvételét kéri: Enroll MOK, Continue, Yes, jelszó: universalblue."
fi
[ -e "${sys}/class/tpm/tpm0" ] || note "No TPM found: disk encryption asks for its password at every start." \
    "Nincs TPM: a lemeztitkosítás minden induláskor kéri a jelszavát."
fs=$(cat "${ARKADEOS_LSBLK:-/dev/null}" 2>/dev/null || true)
[ -n "${ARKADEOS_LSBLK:-}" ] || fs=$(lsblk -nro FSTYPE 2>/dev/null)
if echo "${fs}" | grep -qx BitLocker; then
    note "Windows is encrypted with BitLocker: save its recovery key before installing next to it." \
        "A Windows BitLockerrel titkosított: a mellé telepítés előtt mentsd el a helyreállító kulcsát."
fi
cat "${out}"
%end

%pre --erroronfail --log=/tmp/arkadeos-pre.log
#!/bin/bash
tag=@TAG@
image=
for arg in $(cat "${ARKADEOS_CMDLINE:-/proc/cmdline}"); do
    case "${arg}" in
        arkadeos.tag=*) tag=${arg#*=} ;;
        arkadeos.image=*) image=${arg#*=} ;;
    esac
done
if [ -z "${image}" ]; then
    image=arkadeos
    for dev in "${ARKADEOS_SYSFS:-/sys}"/bus/pci/devices/*; do
        case "$(cat "${dev}/class")" in
            0x03*)
                if [ "$(cat "${dev}/vendor")" = 0x10de ] && [ $(( $(cat "${dev}/device") )) -ge $(( 0x1e00 )) ]; then
                    image=arkadeos-nvidia
                fi
                ;;
        esac
    done
fi
ref="ghcr.io/tenarkhq/${image}:${tag}"
echo "ArkadeOS image: ${ref}"
echo "${ref}" > "${ARKADEOS_TMP:-/tmp}/arkadeos-image"
# The installer pulls with Fedora's trust settings; the installed system
# checks ArkadeOS's signature from then on (bootc switch below).
echo "ostreecontainer --url=${ref} --transport=registry --no-signature-verification" > "${ARKADEOS_TMP:-/tmp}/arkadeos-image.ks"
# The installer does not read the image's kernel arguments
# (/usr/lib/bootc/kargs.d/10-arkadeos.toml): the boot screen and its disk
# password prompt need them from the first start on.
echo 'bootloader --append="rhgb quiet splash"' >> "${ARKADEOS_TMP:-/tmp}/arkadeos-image.ks"
# It starts to the login screen, also when the installer ran in text mode.
echo 'xconfig --startxonboot' >> "${ARKADEOS_TMP:-/tmp}/arkadeos-image.ks"
# The installed system learns the image and the hardware check's findings
# here: a %post inside the new system cannot read the installer's /tmp, and
# outside it the deployment's /etc is elsewhere.
{
    echo "%post --erroronfail --log=/var/log/arkadeos-install-info.log"
    echo "mkdir -p /etc/arkadeos"
    echo "echo '${ref}' > /etc/arkadeos/installed-image"
    if [ -s "${ARKADEOS_TMP:-/tmp}/arkadeos-hwcheck.txt" ]; then
        echo "base64 -d > /etc/arkadeos/hardware-check.txt <<'HWCHECK'"
        base64 "${ARKADEOS_TMP:-/tmp}/arkadeos-hwcheck.txt"
        echo "HWCHECK"
    fi
    echo "%end"
} > "${ARKADEOS_TMP:-/tmp}/arkadeos-info.ks"
%end

%include /tmp/arkadeos-image.ks
%include /tmp/arkadeos-info.ks


%post --erroronfail --log=/var/log/arkadeos-install-chroot.log
ref=$(cat /etc/arkadeos/installed-image)
test -n "${ref}"
# Updates come from the registry, with ArkadeOS's signature checked.
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry "${ref}"
# Secure Boot: queue the keys the drivers are signed with (Bazzite's and the
# ArkadeOS module key, T047). At the first reboot a blue screen (MokManager)
# asks: Enroll MOK -> Continue -> Yes, password universalblue.
if mokutil --sb-state 2>/dev/null | grep -q enabled; then
    mokutil --timeout -1 || true
    printf 'universalblue\nuniversalblue\n' |
        mokutil --import /etc/pki/akmods/certs/akmods-ublue.der /etc/pki/arkadeos/arkadeos-mok.der || true
    mkdir -p /var/lib/arkadeos && touch /var/lib/arkadeos/mok-queued
fi
# The hardware clock keeps local time, as Windows does: no clock jump after
# switching between the two (10-31, Roland: local time, not UTC).
printf '0.0 0 0.0\n0\nLOCAL\n' > /etc/adjtime
%end
