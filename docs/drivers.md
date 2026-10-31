# Drivers

On Windows, chipset, network and sensor drivers come from the maker's
installers. On Linux they are part of the kernel. ArkadeOS ships the kernel,
the drivers and the firmware together in one image, so a driver never falls
behind the kernel: they always update together (T048).

Every driver in [drivers.list](../system_files/usr/share/arkadeos/drivers.list)
is checked when the image is built (`build_files/61-drivers.sh`). If a kernel
update ever drops one, the build fails and the update never ships.

## Works out of the box

| Area | Chips |
|---|---|
| Chipset | AMD and Intel: built into the kernel, nothing to install |
| Disks | SATA (AHCI), NVMe, Intel VMD, Intel RST RAID (mdadm) |
| Ethernet | Realtek 1G / 2.5G (RTL8125) / 5G (RTL8126), Intel I225/I226 2.5G, Intel 1G, Aquantia/Marvell 10G, Killer; Realtek and ASIX USB adapters |
| Wi-Fi | Intel AX200/AX210/AX211/BE200; Realtek RTL8852BE/CE, RTL8922AE, RTL8822CE, RTL8821CE; MediaTek MT7921/MT7925 (AMD RZ608/RZ616/RZ717); Qualcomm WCN6855/WCN7850; Broadcom (newer, plus the older `wl` driver) |
| USB Wi-Fi | Realtek RTL8812AU, RTL8811AU/8821AU, RTL8822BU, RTL8814AU, RTL8852AU/BU; MediaTek MT7921AU, MT7925 |
| Bluetooth | Intel, Realtek, MediaTek, Qualcomm |
| Graphics | AMD Radeon (Mesa), Intel (i915, Xe / Arc), NVIDIA GTX 16 / RTX 20 and newer (NVIDIA image) |
| Sensors and fans | AMD and Intel processor temperature; ITE (it87), Nuvoton (nct6775, nct6687), ASUS ROG/TUF, Gigabyte mainboard sensors; fan curves in CoolerControl on desktops |
| Controllers | Xbox (USB and Wireless Adapter), DualShock 4, DualSense, Switch Pro, Joy-Con, Steam Controller |
| Laptop makers | ASUS (asusctl), MSI (msi-ec, MControlCenter), Lenovo Legion (LenovoLegionLinux: legion-laptop driver, built with every kernel) and IdeaPad (the kernel's Lenovo drivers) |
| Peripherals | Razer (OpenRazer), Logitech (Solaar, Piper), RGB (OpenRGB), monitors over DDC/CI |

## Needs something first

| What | Why | What to do |
|---|---|---|
| AMD RAID mode in the BIOS | Linux does not support AMD's RAID driver | Back up, then switch the disk mode to AHCI in the BIOS. With Windows on the disk, switch Windows to AHCI first (T053). |
| NVIDIA older than GTX 16 / RTX 20 | The current NVIDIA driver no longer supports them | The installer puts the plain image on them (nouveau). |
| Brand-new Wi-Fi chips | Support arrives with newer kernels | Use Ethernet or a USB adapter from the list until an update brings it. |
| MSI and Lenovo firmware quirks | `msi-ec` and Lenovo's drivers support models by firmware version | Most models work. Others keep the firmware's own modes. |
