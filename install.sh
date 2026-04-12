#!/usr/bin/env bash

set -e

echo "🔥 Applying system performance tweaks..."

# -------------------------
# CPU Performance Mode
# -------------------------
echo "⚡ CPU governor -> performance"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee $cpu > /dev/null
done

# -------------------------
# SYSCTL (Network + Memory)
# -------------------------
echo "🌐 Applying sysctl tweaks..."

sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null <<EOF
net.core.netdev_max_backlog=16384
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

sudo sysctl --system

# -------------------------
# ENV VARIABLES (GLOBAL)
# -------------------------
echo "🎮 Setting environment variables..."

PROFILE_FILE="/etc/profile.d/gaming.sh"

sudo tee $PROFILE_FILE > /dev/null <<EOF
export RADV_PERFTEST=gpl,nggc
export mesa_glthread=true
export DXVK_ASYNC=1
export __GL_MaxFramesAllowed=1
export vblank_mode=0
EOF

sudo chmod +x $PROFILE_FILE

# -------------------------
# DONE
# -------------------------
echo "✅ All tweaks applied!"
echo "🔁 Reboot recommended"
