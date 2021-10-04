#!/bin/sh
# Options
AUR_HELPER="paru"
ENABLE_32=1
# This should be git cloneable and have it's .config in the root directory
# Optional: include `extra_install.sh' to install additional files in the dotifiles repo
DOTFILES_GIT_HTTP="https://github.com/BlockListed/dotifles-i3.git"
# These have to be compatible with makepkg / your aur helper
PACMAN_OPTS="--noconfirm"
MAKEPKG_OPTS=""
# Git credential cache
ENABLE_GIT_CACHE=1
DEFAULT_FILE_EXPLORER="nemo.desktop"

# Packages
PACMAN_PKGS="zsh ttf-fira-code zsh-autosuggestions zsh-syntax-highlighting zsh-completions \
  networkmanager network-manager-applet networkmanager-openvpn \
  xorg xorg-xinit xorg-xrandr arandr \
  pipewire pipewire-pulse \
  lightdm lightdm-slick-greeter \
  i3-gaps sxhkd xss-lock scrot dunst \
  gnome \
  firefox chromium \
  neovim atom node npm rustup \
  python python-pip python2 python2-pip\
  pavucontrol \
  cups cups-pdf \
  obs-studio lutris \
  lxappearance \
  xxhash"
PACMAN_PKGS_ARTIX_OPENRC="artix-archlinux-support \
  lighdm-openrc networkmanager-openrc \
  pipewire-openrc cups-openrc"
AUR_PKGS="brother-mfc-j5320dw \
  chrome-gnome-shell appimagelauncher \
  isw timeshift-bin timeshift-autosnap nordvpn-bin \
  proton-ge-custom-bin lutris-wine-meta \
  vscodium-bin \
  obs-nvfbc \
  yaru-colors-gtk-theme yaru-colors-icon-theme yaru-icon-theme yaru-gnome-shell-theme \
  polybar picom-ibhagwan-git \
  spaceship-prompt"
AUR_PKGS_ARCH_SYSTEMD="optimus-manager"
AUR_PKGS_ARTIX_OPENRC="optimus-manager-openrc-git \
  nordvpn-openrc"
# These are install as root
PIP_PKGS="neovim"
PIP2_PKGS="neovim"

# Variables are defined here for more overview
ARTIX=0
OPENRC=0
SETUP_INSTALL=1
SETUP_DOTFILES=1

update() {
  sudo pacman $PACMAN_OPTS -Syu
  $AUR_HELPER $PACMAN_OPTS $MAKEPKG_OPTS -Syu
}

is_artix() {
  if [ -e /etc/artix-release ]; then
    ARTIX=1
    echo 1
  fi
}

is_openrc() {
  if [ -e /usr/bin/rc-update ] || [ -e /usr/bin/rc-status ] || [ -e /etc/rc.conf ]; then
    OPENRC=1
    echo 1
  fi
}

install_paru() {
  cd ~/.cache
  mkdir aur
  cd aur

  git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && \
  makepkg $PACMAN_OPTS $MAKEPKG_OPTS -si
}

clean_exit() {
  rm -rf ~/.cache
  exit
}

test_sudo() {
  sudo test
}

setup_dotfiles() {
  if [ $SETUP_DOTFILES -eq 1 ];then
    if [ -n $DOTFILES_GIT_HTTP ]; then
      mkdir ~/.cache
      cd ~/.cache

      git clone --depth=1 $DOTFILES_GIT_HTTP dotfiles
      if ! [ -d ./dotfiles ]; then
        echo "Git failed (retry only dotfiles with \`./install_arch.sh --dotfiles')"
      clean_exit
      fi
      cp -r .config ~
      if [ -e ./extra_install.sh ]; then
        sh ./extra_install.sh
      fi
    fi
  fi
}

setup_install() {
  if [ $SETUP_INSTALL -eq 1 ]; then
    # Install packages, if on normal arch and not OPENRC / artix
    if [ $ARTIX -eq 0 ] && [ $OPENRC -eq 0 ]; then
      sudo pacman $PACMAN_OPTS -S $PACMAN_PKGS
      $AUR_HELPER $PACMAN_OPTS $MAKEPKG_OPTS -S $AUR_PKGS $AUR_PKGS_ARCH_SYSTEMD
    fi

    # Install different packages, if on artix with OPENRC
    if [ $ARTIX -eq 1 ] && [ $OPENRC -eq 1 ]; then
      sudo pacman $PACMAN_OPTS -S $PACMAN_PKGS $PACMAN_PKGS_ARTIX_OPENRC
      $AUR_HELPER $PACMAN_OPTS $MAKEPKG_OPTS -S $AUR_PKGS $AUR_PKGS_ARTIX_OPENRC
    fi

    # Echo ERROR, if on artix w/o OPENRC
    if [ $ARTIX -eq 1 ] && [ $OPENRC -eq 0 ]; then
      echo "Non OPENRC/Systemd is currenty not supported."
      clean_exit
    fi
    if [ -n $PIP_PKGS ]; then
      sudo pip install $PIP_PKGS
    fi
    if [ -n $PIP2_PKGS ]; then
      sudo pip2 install $PIP2_PKGS
    fi

  fi
}

setup_multilib() {
  # Multilib setup commands from https://stackoverflow.com/a/34516165

  if [ $ARTIX -eq 0 ]; then
    sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  fi

  # Improvement recommended, currently don't have artix installed, so can't test.
  if [ $ARTIX -eq 1 ]; then
    sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf
  fi
}

setup_git_cache() {
  git config --global credential.helper cache
}

setup_mime() {
  if [ -n $DEFAULT_FILE_EXPLORER ]; then
    xdg-mime default nemo.desktop node/directory
  fi
}

# Check configs
test_sudo
is_artix
is_openrc

if [ "$1" == "" ]; then
  return
fi
while true; do
  case $1 in
    "--dotfiles")
      SETUP_INSTALL=0
      SETUP_DOTFILES=1
      ;;
    "--install")
      SETUP_INSTALL=1
      SETUP_DOTFILES=0
      ;;
    *)
      return
      ;;
  esac
  shift
done

if [ ! -e /usr/bin/git ]; then
  sudo pacman -S git
fi

if [ $ENABLE_GIT_CACHE -eq 1 ]; then
  setup_git_cache
fi

if [ $AUR_HELPER == "paru" ] && [ ! -e /usr/bin/paru ]; then
  install_paru
fi

# Setup Multilib/Lib32
if [ $ENABLE_32 -eq 1 ]; then
  enable_32
fi

setup_install
setup_dotfiles
setup_mime

clean_exit
