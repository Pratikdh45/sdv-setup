#!/bin/bash

echo "Starting Kubernetes cleanup process..."

# 1. Run kubeadm reset to gracefully shut down Kubernetes components
echo "Running kubeadm reset..."
sudo kubeadm reset -f || true # Use || true to prevent script from exiting if reset fails on a partially configured system

# 2. Stop and disable Kubernetes services
echo "Stopping and disabling kubelet service..."
sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true

# 3. Stop and disable container runtime services (Docker or containerd)
echo "Stopping and disabling container runtime services (Docker/containerd)..."
sudo systemctl stop docker || true
sudo systemctl disable docker || true
sudo systemctl stop containerd || true
sudo systemctl disable containerd || true

# 4. Remove Kubernetes configuration and data directories
echo "Removing Kubernetes configuration and data directories..."
sudo rm -rf /etc/kubernetes/ || true
sudo rm -rf /var/lib/kubelet/ || true
sudo rm -rf /var/lib/etcd/ || true
sudo rm -rf /run/kubernetes/ || true
sudo rm -rf /var/run/kubernetes/ || true

# 5. Clean up CNI network interfaces
echo "Cleaning up CNI network interfaces..."
sudo ip link set cni0 down || true
sudo ip link del cni0 || true
sudo ip link set flannel.1 down || true # For Flannel CNI
sudo ip link del flannel.1 || true

# 6. Remove Kubernetes packages
echo "Purging Kubernetes packages..."
# Attempt for Debian/Ubuntu
if command -v apt-get &> /dev/null; then
    sudo apt-get purge -y kubelet kubeadm kubectl kubernetes-cni || true
    sudo apt-get autoremove -y || true
# Attempt for CentOS/RHEL/Amazon Linux (dnf/yum)
elif command -v dnf &> /dev/null; then
    sudo dnf remove -y kubelet kubeadm kubectl kubernetes-cni || true
elif command -v yum &> /dev/null; then
    sudo yum remove -y kubelet kubeadm kubectl kubernetes-cni || true
fi

# 7. Optional: Clean up Docker/containerd data (uncomment with caution if you have other containers)
# echo "Removing Docker/containerd data directories (use with caution if you have other containers)..."
# sudo rm -rf /var/lib/docker || true # For Docker
# sudo rm -rf /var/lib/containerd || true # For Containerd

echo "Kubernetes cleanup complete."
echo "It is highly recommended to reboot your VM now for a clean state: sudo reboot"

