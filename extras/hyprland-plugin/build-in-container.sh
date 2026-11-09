set -e
dnf -y -q install gcc-c++ pkgconf-pkg-config >/dev/null 2>&1 # 
cp /src/sdegler-hyprland.repo /etc/yum.repos.d/
dnf -y -q install hyprland-devel >/dev/null 2>&1 || dnf -y install hyprland-devel 2>&1 | tail -20
rpm -q hyprland-devel
cd /src
g++ -shared -fPIC -std=c++26 -O2 -o minimize-to-event.so minimize-to-event.cpp $(pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon xcb) -lxcb 2>&1 | grep -E "error|Error" | head -30
ls -la minimize-to-event.so
