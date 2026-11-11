set -e
dnf -y -q install gcc-c++ pkgconf-pkg-config cairo-devel pango-devel >/dev/null 2>&1
cp /build/sdegler-hyprland.repo /etc/yum.repos.d/
dnf -y -q install hyprland-devel-0.57.1 >/dev/null 2>&1 || dnf -y install hyprland-devel-0.57.1 2>&1 | tail -20
rpm -q hyprland-devel
cd /src/hyprland-plugins/hyprbars
g++ -shared -fPIC -std=c++26 -O2 -Wno-narrowing -o /build/hyprbars.so *.cpp $(pkg-config --cflags --libs pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon cairo pangocairo) 2>&1 | grep -E "error" | head -30
ls -la /build/hyprbars.so
