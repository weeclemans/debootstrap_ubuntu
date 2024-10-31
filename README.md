# Debootstrap Ubuntu/Debian script

The script to install Ubuntu/Debian on a bare_metal/virtual host is based on the following material:
 - [my old post on installing Debian Squeeze](https://weeclemans.livejournal.com/13071.html)
 - [subrezon's instructions](https://gist.github.com/subrezon/9c04d10635ebbfb737816c5196c8ca24)
 - [wiki page](https://docs.zfsbootmenu.org/en/v2.3.x/guides/ubuntu/noble-uefi.html)

## Install base system

You will need to switch to the root user, edit the shell script you want, specifying the desired parameters (disk used for the installation, username, swapfile size, additional deb packages, ...) and run it.

