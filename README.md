## mad-void-i3
Proyecto para automatizar la instalacion de i3 en void linux, estilo inspirado en la version de i3 de EndeavourOS

Comprobar que el usuario con el que se ejecuta este script pertenece al grupo wheel y este esta correctamente configurado en /etc/sudoers.

"

...

root ALL=(ALL:ALL) ALL

#%wheel ALL=(ALL:ALL) ALL -> pide clave y tiene timeout

#%wheel ALL=(ALL:ALL) NOPASSWD: ALL -> nunca pide clave

...

"

## Atajos de Teclado

Win + Espacio = Rofi (lanzador de aplicaciones)

Win + Enter = Xterm (Terminal)

Win + Alt + Espacio = PcmanFM (Administrador de archivos)

Win + n = Firefox

Win + Alt + q = Administrador de secion, bloquear equipo, cerrar secion, reiniciar, apagar.

Win + [1..0] = Cambio de espacios de trabajo

Win + Alt + [1..0] = Mover ventana activa al espacio de trabajo...

Win + s = Ventana flotante (presionando nuevamente vuelve a modo tilin)

Win + arrastrar con mouse = Mover ventanas flotantes

Win + f = Ventana en pantalla completa


Ademas debería funcionar los accesos s las teclas especiales de volumen y reproducción de audio.

Demas configuraciones de acceso de teclado en ~/.config/i3/config

## Barra Superior

En la barra superior se encuentran 4 iconos:

Cambio Fondo de pantalla, selecciona aleatoriamente imagenes ubicadas en ~/Fondosvs

Firefox

PcmanFM

Pospone 30 minutos el protector de pantalla (se puede cambiar el tiempo en ~/.config/i3/i3blocks.conf en el sector [time]

Continuado unos esta la información de algunos datos del sistema como uso de la partición /, uso de memoria, temperatura, uso de la red, y estado de la batería.

Estos scripts se encuentran en ~/.config/i3/scripts.

Por último la hora y el tray con el gestor de redes, Octoxbps para gestionar software, y el control de volumen

Por consultas o sugerencias enviar mail a davidmauroweb@gmail.com.

Gracias!
