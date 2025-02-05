#!/bin/bash

host_name="ensure-pc"
bootmode="idk"

netcheck(){
    ping -c 4 www.archlinuxcn.org > /dev/null 2> /dev/null
    if [ "$?" != "0" ]; then
        dialog --title "Network Connection Error!" --backtitle "Ensure Linux Installer" --yesno "Connect Network through iwctl?" 6 35
        if [ "$?" != "0" ]; then
            exit 0
        fi
        clear
        iwctl
        netcheck
    fi
    return
}

diskutil(){
    while true
    do
        let opts=$(dialog --title "Disk Configation Tools" --backtitle "Ensure Linux Installer" --stdout --menu "Pick a choice" 16 35 5 1 "Run cfdisk tool" 2 "Run fdisk tool" 3 "read disk info" 4 "Run cfdisk with /dev/sda" 5 "Run fdisk with /dev/sda" 6 "Done")
        if [ $opts = "1" ]; then
            #diskid=0;
            #let diskid=$(dialog --stdout --inputbox "Input your disk:" 10 25 "/dev/sda")
            dialog --clear
            read -p "Disk name:" diskid
            cfdisk $diskid
        elif [ $opts = "2" ]; then
            #diskid=0;
            #let diskid=$(dialog --stdout --inputbox "Input your disk:" 10 25 "/dev/sda")
            dialog --clear
            read -p "Disk name:" diskid
            echo "Use disk $diskid."
            fdisk $diskid
        elif [ $opts = "3" ]; then
            dialog --title "Disk Information" --backtitle "Ensure Linux Installer" --msgbox "$(lsblk -l)" 40 120
        elif [ $opts = "4" ]; then
            diskid=0;
            cfdisk /dev/sda
        elif [ $opts = "5" ]; then
            diskid=0;
            fdisk /dev/sda
        elif [ $opts = "6" ]; then
            break
        fi
    done
}

dialog --title "Welcome!" --backtitle "Ensure Linux Installer" --yesno "Welcome to use Ensure Linux!\nDo you want to continue?" 6 35

if [ "$?" != "0" ]; then
    exit 0
fi

# 1. Check Network is ok?
dialog --title "Please wait..." --backtitle "Ensure Linux Installer" --infobox "Checking Network Connection..." 5 40
netcheck
# 2. Update Mirror List
dialog --title "Switch to USTC Mirror?" --backtitle "Ensure Linux Installer" --yesno "Switch to USTC Mirror can let China users get speeds." 6 35

if [ "$?" == "0" ]; then
    #   cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    #   echo 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
fi

dialog --title "Please wait..." --backtitle "Ensure Linux Installer" --infobox "Updating Mirror List..." 5 30
pacman -Sy > /dev/null
if [ "$?" != "0" ]; then
    dialog --title "Error!" --backtitle "Ensure Linux Installer" --msgbox "Installion not yet." 5 24
    exit 0
fi
# 3. Configure disk
dialog --title "Disk Information" --backtitle "Ensure Linux Installer" --msgbox "$(lsblk -f)" 40 120
diskutil

# 4. Check UEFI or BIOS
dmesg | grep "EFI v" > /dev/null
if [ "$?" == "0" ]; then
    # UEFI Boot
    bootmode="UEFI"
else
    # MBR Boot
    bootmode="MBR"
fi

# 5. Mount DiskPart
rootpart=$(dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "Root part path\nBoot Mode:$bootmode" 8 45 "")
if [ $rootpart != "" ]; then
    mkfs.btrfs $rootpart
    echo "Mount $rootpart to /"
    mount $rootpart /mnt
fi
swapart=$(dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "Select SWAP Part:\nTIPS:IF YOU NOT, KEEP IT NULL." 8 45 "")
if [ $swapart != "" ]; then
    mkswap $swapart
    swapon $swapart
fi
if [ $bootmode = "UEFI" ]; then
    espart=$(dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "Select ESP Part:" 8 45 "")
    if [ $espart != "" ]; then
        mkdir /mnt/boot
        mount $espart /mnt/boot
    fi
fi
# 6. Install
pacstrap -K /mnt base &> /dev/null &
for i in {1..22} ;do echo $i;sleep 0.75;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Base System..." 10 45
wait
for i in {22..25} ;do echo $i;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Base System..." 10 45

pacstrap -K /mnt linux &> /dev/null &
for i in {25..46} ;do echo $i;sleep 0.75;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Linux Kernel.." 10 45
wait
for i in {46..50} ;do echo $i;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Linux Kernel..." 10 45

pacstrap -K /mnt linux-headers &> /dev/null &
for i in {50..73} ;do echo $i;sleep 0.75;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Kernel Headers.." 10 45
wait
for i in {73..75} ;do echo $i;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Linux Kernel Headers..." 10 45

pacstrap -K /mnt linux-firmware &> /dev/null &
for i in {75..97} ;do echo $i;sleep 0.75;done | dialog --title "Installing..." --backtitle "Ensure Linux Installer" --gauge "Installing Kernel Firmware.." 10 45
wait
for i in {97..100} ;do echo $i;done | dialog --title "Installing System..." --backtitle "Ensure Linux Installer" --gauge "Installing Linux Kernel Firmware..." 10 45

# 6-2 Configation Minimum System
dialog --title "Creating fstab..." --infobox "Please wait..." 5 30
genfstab -U /mnt > /mnt/etc/fstab
# 6-3 Set Locale File
dialog --title "Running locale-gen..." --infobox "Please wait..." 5 30
printf 'en_US.UTF-8 UTF-8\nzh_CN.UTF-8 UTF-8' >> /mnt/etc/locale.gen
arch-chroot /mnt bash -c 'locale-gen > /dev/null'
dialog --title "Setting Locale File" --backtitle "Ensure Linux Installer" --yesno "Do you want to use zh_CN locale?" 8 30
if [ "$?" = "0" ]; then
    # Use Chinese locale
    echo 'zh_CN.UTF-8' > /mnt/etc/locale.conf
else
    # English
    echo 'en_US.UTF-8' > /mnt/etc/locale.conf
fi
# 6-4. Set Host Name & Hosts
dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "Input your host name:" 8 45 "ensure-pc" > /mnt/etc/hostname
if [ "$?" != "0" ]; then
    echo 'mcospc' > /mnt/etc/hostname
fi
echo '127.0.0.1 localhost' >> /mnt/etc/hosts
# 6-5. Setting Up Users
username=$(dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "User Name:" 8 45 "user1")
arch-chroot /mnt bash -c "useradd -m -G wheel $username && passwd $username"
# 6-6. Setting Up Timezone
dialog --title "Setting up timezone..." --infobox "Please wait..." 5 30
arch-chroot /mnt bash -c 'timedatectl set-timezone Asia/Shanghai && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && hwclock --systohc && timedatectl set-ntp true' > /dev/null
# 6-7. Installing Software

arch-chroot /mnt bash -c 'pacman --noconfirm --asdeps -S networkmanager' > /dev/null &
for i in {1..22} ;do echo $i;sleep 0.75;done | dialog --title "Installing software..." --backtitle "Ensure Linux Installer" --gauge "Installing Network..." 10 45
wait
for i in {22..25} ;do echo $i;done | dialog --title "Installing software..." --backtitle "Ensure Linux Installer" --gauge "Installing Network..." 10 45

arch-chroot /mnt bash -c 'pacman --noconfirm --asdeps -S sudo' > /dev/null &
for i in {25..47} ;do echo $i;sleep 0.75;done | dialog --title "Installing software..." --backtitle "Ensure Linux Installer" --gauge "Installing SUDO..." 10 45
wait
for i in {47..50} ;do echo $i;done | dialog --title "Installing..." --backtitle "Ensure Linux Installer" --gauge "Installing SUDO..." 10 45

arch-chroot /mnt bash -c 'pacman --noconfirm --asdeps -S wqy-zenhei wqy-microhei nano' > /dev/null &
for i in {50..73} ;do echo $i;sleep 0.75;done | dialog --title "Installing software..." --backtitle "Ensure Linux Installer" --gauge "Installing Chinese font..." 10 45
wait
for i in {73..75} ;do echo $i;done | dialog --title "Installing..." --backtitle "Ensure Linux Installer" --gauge "Installing Chinese font..." 10 45

arch-chroot /mnt bash -c 'pacman --noconfirm --asdeps -S grub' > /dev/null &
for i in {75..97} ;do echo $i;sleep 0.75;done | dialog --title "Installing software..." --backtitle "Ensure Linux Installer" --gauge "Installing GRUB..." 10 45
wait
for i in {97..100} ;do echo $i;done | dialog --title "Installing..." --backtitle "Ensure Linux Installer" --gauge "Installing GRUB..." 10 45
dialog --title "Installing GRUB Bootloader..." --infobox "Please wait..." 5 30
if [ $bootmode = "UEFI" ]; then
    arch-chroot /mnt bash -c "grub-install --target=x86_64_efi --efi-directory='/boot' --bootloader-id='Ensure Linux' && grub-mkconfig -o /boot/grub/grub.cfg" > /dev/null
else
    grubdisk=$(dialog --stdout --backtitle "Ensure Linux Installer" --inputbox "Install GRUB to:" 8 45 "/dev/sda")
    arch-chroot /mnt bash -c "grub-install $grubdisk && grub-mkconfig -o /boot/grub/grub.cfg" > /dev/null
fi
#6-8. Installing GUI
arch-chroot /mnt bash -c 'pacman -S --noconfirm --asdeps xorg' > /dev/null &
for i in {1..23} ;do echo $i;sleep 0.85;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing Xorg..." 10 45
wait
for i in {23..25} ;do echo $i;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing Xorg..." 10 45
arch-chroot /mnt bash -c 'pacman -S --noconfirm --asdeps xfce4 xfce4-goodies' > /dev/null &
for i in {25..73} ;do echo $i;sleep 0.85;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing xfce4..." 10 45
wait
for i in {73..75} ;do echo $i;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing xfce4..." 10 45
arch-chroot /mnt bash -c 'pacman -S --noconfirm --asdeps lightdm lightdm-gtk-greeter && systemctl enable lightdm' > /dev/null &
for i in {75..97} ;do echo $i;sleep 0.85;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing lightdm..." 10 45
wait
for i in {97..100} ;do echo $i;done | dialog --title "Installing GUI..." --backtitle "Ensure Linux Installer" --gauge "Installing lightdm..." 10 45
# 9. Finished
dialog --backtitle "Ensure Linux Installer" --title "Installion" --msgbox "Installion finished!" 6 25
