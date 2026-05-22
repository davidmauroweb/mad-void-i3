### Por Adolfo David Mauro mail: davidmauroweb@gmail.com
ram=$(free -g | awk '/^Mem:/{print $2}')

opt8() {
    echo "--- Configurando optimizaciones para 8GB de RAM y CPU ---"
    
    # Optimizar sysctl para evitar congelamientos por Docker escribiendo en disco
    sudo mkdir -p /etc/sysctl.d
    sudo tee /etc/sysctl.d/99-docker-ram.conf <<EOF
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.max_map_count = 262144
EOF

    # Configurar ZRAMEN (Compresión de RAM usando algoritmo ZSTD)
    sudo mkdir -p /etc/zramen
    sudo tee /etc/zramen/zramen.conf <<EOF
# Usar ZSTD para el mejor ratio de compresión en desarrollo
ALGORITHM=zstd
# Asignar el 100% de la RAM física como espacio ZRAM comprimido
SIZE_FACTOR=1
EOF

echo "Configurando Swap de 8GB..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=8192
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

}

opt2(){
echo "--- Configurando optimizaciones agresivas para CPU ATOM y 2GB de RAM ---"

# 1. Configurar Sysctl para usar ZRAM de forma inmediata y prioritaria
sudo mkdir -p /etc/sysctl.d
sudo tee /etc/sysctl.d/99-low-ram-atom.conf <<EOF
vm.swappiness = 100
vm.dirty_background_ratio = 3
vm.dirty_ratio = 6
vm.vfs_cache_pressure = 50
EOF

# 2. Configurar ZRAMEN con algoritmo ultra-rápido (LZ4) y factor x1.5 (3GB virtuales)
sudo mkdir -p /etc/zramen
sudo tee /etc/zramen/zramen.conf <<EOF
# LZ4 es vital para no saturar al procesador Atom
ALGORITHM=lz4
# Crea 3GB de swap en RAM (1.5 * 2GB físicos)
SIZE_FACTOR=1.5
EOF

echo "Configurando Swap de 4GB..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
}

if [ "$ram" -gt 4 ]; then
opt8
else
opt2
fi



rt=$(pwd)

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


#base grafica 
echo "Agregando Repositorios NonFree"
for pkg in void-repo-multilib void-repo-multilib-nonfree void-repo-nonfree
do
	sudo xbps-install -Sy $pkg
done

echo "intalacion de base"
for pkg in at-spi2-core base-devel xdg-user-dirs NetworkManager gvfs p7zip nano htop neofetch cpupower lm_sensors zramen tlp auto-cpufreq
do
	sudo xbps-install -Sy $pkg
done

echo "instalacion de accesorios graficos"
for pkg in network-manager-applet xorg xinit elogind lxdm  pluma xarchiver octoxbps xtools xf86-video-intel
do
	sudo xbps-install -Sy $pkg
done
echo "intalacion de i3"
for pkg in i3-gaps i3blocks i3lock i3status rofi dunst ImageMagick feh font-awesome6 noto-fonts-ttf clearine alsa-utils pulseaudio pulseaudio-utils alsa-plugins-pulseaudio pamixer volumeicon bluez pavucontrol upower picom
do
	sudo xbps-install -Sy $pkg
done
echo "Software extra"
for pkg in xterm lxappearance pcmanfm xautolock papirus-icon-theme scrot gtk-theme-united-gnome st sysstat alacritty ntpd
do
	sudo xbps-install -Sy $pkg
done

optimizacion

#Ofimatica
clear
echo "Paquetes de Oficina"
echo "-------------------"
echo "1. Abiword + Gnumeric"
echo "2. Libreoffice"
echo "3. Sin Paquetes de Oficina"
read o
spell= "aspell hunspell-es_ES"
case $o in
	1)
		o="abiword gnumeric "$spell
		;;
	2)
		o="libreoffice libreoffice-i18n-es "$spell
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
	w=" firefox-esr firefox-esr-i18n-es-AR"
	;;
	2)
	w=" chromium"
	;;
	3)
	w=" midori"
	;;
	4)
	w=" dillo"
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
        m=" vlc "
        ;;
        2)
        m=" mpv audacious"
        ;;
        *)
        echo "Se ha omitido la instalación reproductores multimedia"
        m=""
        ;;
esac


# Instalo las selecciones
echo "instalaciondo los paquetes seleccionados - Ingrese la clave si es requerida"
sudo xbps-install -Sy $o $w $m

clear
echo "Aplicando configuraciones..."
sleep 2s

#config
xdg-user-dirs-update

echo "copiando archivos de configuracion personal"



clear
echo "XBPS-Src - para instalar software extra "
echo "Visitar https://github.com/void-linux/void-packages para mas info"
echo "-----------------------------------------------------------------"
echo "1. Si"
echo "2. No"
read m
case $m in
        1)
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
	sudo xbps-install -S cups cups-filters gutenprint foomatic-db foomatic-db-nonfree avahi hplip brother-brlaser nss-mdns system-config-printer cups-pk-helper
	sudo ln -s /etc/sv/cupsd /etc/runit/runsvdir/default/
	sudo ln -s /etc/sv/avahi-daemon /var/service
        ;;
        *)
        echo "Se ha omitido la instalación de CUPS"
        ;;
esac

clear
echo "Instalamos Docker? (infresar 1 pasa Instalar)"
read d
case $d in
	1)
	echo "Instalando Docker y Docker Compose..."
	# shadow asegura tener el comando usermod disponible
	sudo xbps-install -y docker docker-compose shadow
	
	echo "Habilitando servicios en Runit..."
	# Habilitar dbus primero (Docker lo requiere para ciertas operaciones de aislamiento)
	sudo ln -sf /etc/sv/containerd /var/service/
    sudo ln -sf /etc/sv/docker /var/service/
	
	echo "Configurando permisos de usuario..."
	# Sintaxis nativa correcta para Void Linux:
	sudo usermod -aG docker $USER
	
	echo "¡Docker instalado correctamente!"
	echo "NOTA: Recordá reiniciar la PC para poder usar Docker sin 'sudo'."
	echo "Listo!, Docker instalado"
	;;
	*)
	echo "Se ha omitido la instalación de Docker"
	;;
esac

#iniciar servicios
echo "Activando Servicios"
cd $rt
sudo cp lxdm.conf /etc/lxdm/
mkdir ~/Fondosvs
cp bg* ~/Fondosvs/
sudo mkdir /usr/share/backgrounds
sudo cp bg* /usr/share/backgrounds/
sudo cp config/conf /etc/sv/zramen
cp nanorc ~/.nanorc
cp /usr/share/examples/picom/picom.sample.conf ~/.config/picom.conf
cp Xresources ~/.Xresources
cp Scripts ~/ -R
cp config/i3 ~/.config -R
cp config/rofi ~/.config -R
cp config/clearine ~/.config -R
cp config/gtk-3.0 ~/.config -R
sudo ln -sf /etc/sv/dbus /var/service/
sudo ln -sf /etc/sv/bluetoothd /var/service/
sudo ln -sf /etc/sv/NetworkManager /var/service/
sudo ln -sf /etc/sv/elogind /var/service/
sudo ln -sf /etc/sv/lxdm /var/service/
sudo ln -sf /etc/sv/zramen /var/service/

sudo ln -sf /etc/sv/tlp /var/service/
sudo ln -sf /etc/sv/auto-cpufreq /var/service/

###

echo "Instalacion de VoidBsp Completada"
echo ""
echo "## Colocar imagenes en la carpeta Fondosvs para la seleccion aleatoria al inicio ##"
echo ""
echo "Pulse cualquiera tecla para continuar..."
read tecla
clear
