#!/bin/bash
# Post-instalación de Void Linux con i3 + LXDM.
# Perfil de portátil Intel (EliteBook 840 G6: Whiskey Lake, UHD 620, 16 GB):
# zram de hasta 4 GiB, swap de disco chico, TLP, modesetting y VA-API.

configure_memory() {
	local ram_gb zram_percent zram_max swap_gb root_fs
	while true; do
		read -r -p "RAM instalada en GB (2, 4, 8 o más): " ram_gb
		case "$ram_gb" in
			2) zram_percent=50; zram_max=1024; swap_gb=2; break ;;
			4) zram_percent=50; zram_max=2048; swap_gb=4; break ;;
			8) zram_percent=25; zram_max=2048; swap_gb=8; break ;;
			*[!0-9]*|'') echo "Ingrese 2, 4, 8 o una cantidad entera mayor." ;;
			*)
				if [ "$ram_gb" -gt 8 ]; then
					# 16 GB o más: zram de 4 GiB y swap de disco solo como red.
					zram_percent=25
					zram_max=4096
					swap_gb=4
					break
				fi
				echo "Ingrese 2, 4, 8 o una cantidad entera mayor."
				;;
		esac
	done

	echo "ZRAM: ${zram_percent}% de la RAM, con tope de ${zram_max} MiB."
	sudo install -d /etc/sv/zramen
	sudo tee /etc/sv/zramen/conf >/dev/null <<EOF
export ZRAM_COMP_ALGORITHM='lz4'
export ZRAM_PRIORITY=100
export ZRAM_SIZE=$zram_percent
export ZRAM_MAX_SIZE=$zram_max
EOF

	sudo tee /etc/sysctl.d/99-zram.conf >/dev/null <<'EOF'
vm.swappiness = 180
vm.page-cluster = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
	sudo sysctl --system >/dev/null

	if [ ! -e /swapfile ]; then
		root_fs=$(findmnt -n -o FSTYPE /)
		if [ "$root_fs" = btrfs ]; then
			echo "No se creó /swapfile automáticamente en Btrfs. Configure una swapfile Btrfs válida antes de hibernar."
		else
			echo "Creando /swapfile de ${swap_gb} GiB..."
			if sudo dd if=/dev/zero of=/swapfile bs=1M count=$((swap_gb * 1024)) status=progress &&
				sudo chmod 600 /swapfile &&
				sudo mkswap /swapfile &&
				sudo swapon /swapfile; then
				if ! grep -qE '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab; then
					echo '/swapfile none swap defaults,pri=10 0 0' | sudo tee -a /etc/fstab >/dev/null
				fi
			else
				sudo swapoff /swapfile 2>/dev/null || true
				sudo rm -f /swapfile
				echo "No se pudo activar /swapfile; revise el filesystem y configure swap manualmente."
			fi
		fi
	else
		echo "Ya existe /swapfile; no se sobrescribió."
	fi

	echo "La suspensión a RAM queda a cargo de elogind. La hibernación pide un swap del tamaño de la RAM y resume/resume_offset."
}

write_hardware_tuning() {
	echo "Aplicando ajustes de UHD 620, TLP y la tapa..."

	sudo tee /etc/modprobe.d/i915.conf >/dev/null <<'EOF'
# UHD 620 (Whiskey Lake). HuC para video, FBC para consumo, PSR apagado por parpadeo del panel.
options i915 enable_guc=2 enable_fbc=1 enable_psr=0
EOF

	sudo install -d /etc/dracut.conf.d
	sudo tee /etc/dracut.conf.d/intel.conf >/dev/null <<'EOF'
hostonly="yes"
early_microcode="yes"
force_drivers+=" i915 "
EOF

	sudo install -d /etc/tlp.d
	sudo tee /etc/tlp.d/01-elitebook.conf >/dev/null <<'EOF'
# TLP 1.9+: _AC = rendimiento, _BAT = equilibrado (batería), _SAV = ahorro.
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_SCALING_GOVERNOR_ON_SAV=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_ENERGY_PERF_POLICY_ON_SAV=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_BOOST_ON_SAV=0
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_SAV=0
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=balanced
PLATFORM_PROFILE_ON_SAV=low-power
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
USB_AUTOSUSPEND=1
EOF

	if compgen -G '/sys/class/power_supply/BAT*/charge_control_end_threshold' >/dev/null; then
		sudo tee -a /etc/tlp.d/01-elitebook.conf >/dev/null <<'EOF'
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
EOF
		echo "Umbral de carga 75-80 % activo: el kernel expone charge_control en la batería."
	else
		echo "Esta máquina no expone umbrales de carga. TLP no limitará el 100 %."
	fi

	tmp=$(mktemp)
	cat >"$tmp" <<'EOF'
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp ac, /usr/bin/tlp bat, /usr/bin/tlp start, /usr/bin/tlp performance, /usr/bin/tlp balanced, /usr/bin/tlp power-saver
EOF
	if sudo visudo -cf "$tmp" >/dev/null; then
		sudo install -m 440 "$tmp" /etc/sudoers.d/tlp-modes
	else
		echo "No se instaló /etc/sudoers.d/tlp-modes: visudo rechazó la sintaxis."
	fi
	rm -f "$tmp"

	sudo install -d /etc/elogind/logind.conf.d
	sudo tee /etc/elogind/logind.conf.d/lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
IdleAction=suspend
IdleActionSec=20min
EOF

	if ! grep -q '^LIBVA_DRIVER_NAME=' /etc/environment 2>/dev/null; then
		echo 'LIBVA_DRIVER_NAME=iHD' | sudo tee -a /etc/environment >/dev/null
	fi
}

setup_pipewire() {
	sudo install -d /etc/pipewire/pipewire.conf.d /etc/alsa/conf.d
	if [ -f /usr/share/examples/wireplumber/10-wireplumber.conf ]; then
		sudo ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
	fi
	if [ -f /usr/share/examples/pipewire/20-pipewire-pulse.conf ]; then
		sudo ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
	fi
	if [ -f /usr/share/alsa/alsa.conf.d/50-pipewire.conf ]; then
		sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
	fi
	if [ -f /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ]; then
		sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
	fi
}

setup_fstrim() {
	sudo install -d /etc/cron.weekly
	sudo tee /etc/cron.weekly/fstrim >/dev/null <<'EOF'
#!/bin/sh
fstrim -A
EOF
	sudo chmod 755 /etc/cron.weekly/fstrim
}

setup_groups() {
	local g have=""
	for g in audio video storage network bluetooth input; do
		if getent group "$g" >/dev/null; then
			have="${have:+$have,}$g"
		fi
	done
	if [ -n "$have" ]; then
		sudo usermod -aG "$have" "$USER"
		echo "Grupos de $USER: $have"
	fi
}

setup_fish_shell() {
	local fish_bin=/usr/bin/fish user uid home
	if [ ! -x "$fish_bin" ]; then
		echo "fish no quedó instalado; las cuentas siguen con su shell actual."
		return
	fi
	if ! grep -qx "$fish_bin" /etc/shells; then
		echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
	fi
	while IFS=: read -r user _ uid _ _ home _; do
		if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] && [ -d "$home" ]; then
			sudo chsh -s "$fish_bin" "$user"
			echo "Shell de $user: $fish_bin"
		fi
	done < /etc/passwd
}

enable_service() {
	local name="$1"
	if [ -d "/etc/sv/$name" ]; then
		sudo ln -sf "/etc/sv/$name" /var/service/
	else
		echo "No se encontró /etc/sv/$name; el servicio no se activó."
	fi
}

reconfigure_kernel() {
	local kpkg found=0
	while read -r kpkg; do
		[ -n "$kpkg" ] || continue
		found=1
		echo "Regenerando initramfs de $kpkg..."
		sudo xbps-reconfigure -f "$kpkg"
	done < <(xbps-query -l | sed -n 's/^ii[[:space:]]\+\(linux[0-9][0-9.]*\)-.*/\1/p')
	if [ "$found" -eq 0 ]; then
		echo "No se detectó el paquete del kernel. Ejecute xbps-reconfigure -f linuxX.Y para cargar intel-ucode."
	fi
}

write_firefox_policy() {
	sudo install -d /etc/firefox/policies
	sudo tee /etc/firefox/policies/policies.json >/dev/null <<'EOF'
{
  "policies": {
    "Preferences": {
      "media.ffmpeg.vaapi.enabled": {
        "Value": true,
        "Status": "default"
      },
      "gfx.webrender.all": {
        "Value": true,
        "Status": "default"
      }
    }
  }
}
EOF
}

rt=$(pwd)
enable_bt=0
install_firefox=0

clear

echo "***********************************************"
echo " Post Instal de Void"
echo " Escritorio  i3 + Lxdm"
echo " NOTA: la clave puede ser solicitada en varias"
echo " oportunidades por cuestiones de TimeOut"
echo " el usuario debe pertenecer al grupo wheel"
echo "***********************************************"
echo ""
echo ""
sleep 2s
echo "Introduzca contraseña para continuar"
sudo -k
if sudo true; then
	clear
	echo "Iniciando Instalación..."
	sleep 2s
else
	clear
	echo "Debe introduccir contraseña para continuar"
	exit 1
fi

echo "Actualizando el sistema..."
if ! sudo xbps-install -Syu -y; then
	echo "Falló la actualización del sistema."
	exit 1
fi

echo "Agregando repositorios nonfree y multilib..."
if ! sudo xbps-install -y void-repo-multilib void-repo-multilib-nonfree void-repo-nonfree; then
	echo "No se pudieron habilitar los repositorios."
	exit 1
fi
sudo xbps-install -S

echo "Instalando paquetes base, escritorio y soporte del EliteBook..."
base_pkgs=(
	at-spi2-core xdg-user-dirs NetworkManager gvfs 7zip nano htop fastfetch
	lm_sensors zramen tlp tlp-rdw thermald snooze
	intel-ucode sof-firmware linux-firmware-intel linux-firmware-network
	intel-video-accel libva-utils
	brightnessctl xf86-input-libinput bolt fwupd nvme-cli smartmontools
	network-manager-applet xorg xinit elogind lxdm pluma xarchiver octoxbps xtools
	polkit-gnome
	i3-gaps i3blocks i3lock i3status rofi dunst ImageMagick feh font-awesome6
	noto-fonts-ttf clearine alsa-utils pipewire pipewire-pulse wireplumber
	alsa-pipewire libspa-bluetooth pamixer bluez pavucontrol upower picom playerctl
	xterm lxappearance pcmanfm xautolock papirus-icon-theme scrot
	gtk-theme-united-gnome st sysstat alacritty ntp fish
)

if ! sudo xbps-install -y "${base_pkgs[@]}"; then
	echo "Falló la instalación de paquetes. Revise el nombre que rechazó xbps."
	exit 1
fi

if xbps-query xf86-video-intel >/dev/null 2>&1; then
	echo "Quitando xf86-video-intel: UHD 620 usa el driver modesetting de Xorg."
	sudo xbps-remove -y xf86-video-intel || true
fi

configure_memory
write_hardware_tuning
setup_pipewire
setup_fstrim
setup_groups
setup_fish_shell
reconfigure_kernel

#Ofimatica
clear
echo "Paquetes de Oficina"
echo "-------------------"
echo "1. Abiword + Gnumeric"
echo "2. Libreoffice"
echo "3. Sin Paquetes de Oficina"
read o
spell="aspell hunspell-es_ES"
case $o in
	1)
		o="abiword gnumeric $spell"
		;;
	2)
		o="libreoffice libreoffice-i18n-es $spell"
		;;
	*)
		echo "Se ha omitido la instalación de paquetes de Oficina"
		o=""
		;;
esac

clear
echo "Navegadores"
echo "-------------------"
echo "1. Firefox - recomendado"
echo "2. Chromium"
echo "3. Midori"
echo "4. Dillo (navegador gráfico minimalista)"
read w
case $w in
	1)
		w="firefox-esr firefox-esr-i18n-es-AR"
		install_firefox=1
		;;
	2)
		w="chromium"
		;;
	3)
		w="midori"
		;;
	4)
		w="dillo"
		;;
	*)
		echo "Se ha omitido la instalación del navegador"
		w=""
		;;
esac

clear
echo "Multimedia"
echo "-------------------"
echo "1. VLC"
echo "2. mpv + audacious"
read m
case $m in
	1)
		m="vlc"
		;;
	2)
		m="mpv audacious"
		;;
	*)
		echo "Se ha omitido la instalación reproductores multimedia"
		m=""
		;;
esac

if [ -n "${o}${w}${m}" ]; then
	echo "Instalando los paquetes seleccionados..."
	sudo xbps-install -y $o $w $m
fi

if [ "$install_firefox" -eq 1 ]; then
	write_firefox_policy
fi

clear
echo "Aplicando configuraciones..."
sleep 2s

xdg-user-dirs-update

clear
echo "XBPS-Src - para instalar software extra "
echo "Visitar https://github.com/void-linux/void-packages para mas info"
echo "-----------------------------------------------------------------"
echo "1. Si"
echo "2. No"
read m
case $m in
	1)
		sudo xbps-install -y base-devel git
		cd
		git clone https://github.com/void-linux/void-packages.git
		cd void-packages
		./xbps-src binary-bootstrap
		;;
	*)
		echo "Se ha omitido la instalación de XBPS-Src"
		;;
esac

clear
echo "Impresoras "
echo "Instalar soporte de impresion CUPS?"
echo "-----------------------------------------------------------------"
echo "1. Si"
echo "2. No"
read m
case $m in
	1)
		sudo xbps-install -y cups cups-filters gutenprint foomatic-db foomatic-db-nonfree avahi hplip brother-brlaser nss-mdns system-config-printer cups-pk-helper
		enable_service cupsd
		enable_service avahi-daemon
		;;
	*)
		echo "Se ha omitido la instalación de CUPS"
		;;
esac

clear
echo "Bluetooth"
echo "Activar bluetoothd al arranque e instalar blueman?"
echo "-----------------------------------------------------------------"
echo "1. Si"
echo "2. No"
read m
case $m in
	1)
		sudo xbps-install -y blueman
		enable_bt=1
		;;
	*)
		echo "bluetoothd no se activará al arranque."
		;;
esac

clear
echo "Instalamos Docker? (ingresar 1 para instalar)"
read d
case $d in
	1)
		echo "Instalando Docker y Docker Compose..."
		sudo xbps-install -y moby docker-cli docker-compose shadow
		sudo usermod -aG docker "$USER"
		echo "Docker quedó instalado y el usuario está en el grupo docker."
		echo "Los servicios no arrancan con el sistema. Para usarlos:"
		echo "  sudo ln -sf /etc/sv/containerd /var/service/"
		echo "  sudo ln -sf /etc/sv/docker /var/service/"
		echo "Reinicie la sesión para usar docker sin sudo."
		;;
	*)
		echo "Se ha omitido la instalación de Docker"
		;;
esac

echo "Activando servicios"
cd "$rt"
sudo cp lxdm.conf /etc/lxdm/
mkdir -p ~/Fondosvs ~/.config
cp bg* ~/Fondosvs/
sudo mkdir -p /usr/share/backgrounds
sudo cp bg* /usr/share/backgrounds/
cp nanorc ~/.nanorc
cp "$rt/config/picom.conf" ~/.config/picom.conf
cp Xresources ~/.Xresources
cp -R Scripts ~/
cp -R config/i3 ~/.config/
cp -R config/rofi ~/.config/
cp -R config/clearine ~/.config/
cp -R config/gtk-3.0 ~/.config/
chmod +x ~/.config/i3/scripts/power-profiles ~/.config/i3/scripts/ppd-status

enable_service dbus
enable_service NetworkManager
enable_service elogind
enable_service lxdm
enable_service zramen
enable_service tlp
enable_service thermald
enable_service isc-ntpd
enable_service snooze-weekly
enable_service boltd
if [ "$enable_bt" -eq 1 ]; then
	enable_service bluetoothd
fi

echo ""
echo "Instalacion de VoidBsp Completada"
echo ""
echo "Reinicie para cargar microcódigo, grupos, TLP e i915."
echo "Compruebe video con: vainfo"
echo "Compruebe energía con: sudo tlp-stat -s"
echo ""
echo "## Colocar imagenes en la carpeta Fondosvs para la seleccion aleatoria al inicio ##"
echo ""
echo "Pulse cualquiera tecla para continuar..."
read tecla
clear
