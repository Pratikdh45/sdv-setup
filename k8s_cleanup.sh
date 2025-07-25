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

# --- Additions start here ---

# 7. Clean up Helm
echo "Cleaning up Helm installations and configuration..."
# Remove Helm binary if it's in a common location like /usr/local/bin
if command -v helm &> /dev/null; then
    echo "Attempting to remove Helm binary..."
    # Check if helm is in a user-writable path or /usr/local/bin
    HELM_PATH=$(command -v helm)
    if [[ "$HELM_PATH" == "/usr/local/bin/helm" || "$HELM_PATH" == "$HOME/bin/helm" || "$HELM_PATH" == "$HOME/.local/bin/helm" ]]; then
        sudo rm -f "$HELM_PATH" || true
    else
        echo "Helm binary found at $HELM_PATH, but it's not a common user or local install path. Manual removal might be needed."
    fi
fi
# Remove Helm configuration directories
rm -rf ~/.helm || true
rm -rf ~/.cache/helm || true
rm -rf ~/.config/helm || true

# 8. Clean up Python CNI-related downloads (assuming common locations)
echo "Cleaning up Python CNI-related downloads..."
# This is a bit speculative as Python CNI components aren't always installed in a standard way.
# Common places might be virtual environments or directly in /usr/local/lib/pythonX.Y/dist-packages/
# We'll look for common CNI library names if installed via pip.
# Note: This will only remove packages installed via pip, not system-level Python packages unless forced.
# Use 'pip freeze' to list installed packages and then 'pip uninstall'
# This section assumes you want to remove Python packages that are specifically related to CNI setup.
# You might need to adjust the package names based on what you installed.
echo "Checking for and removing common Python CNI-related packages..."
for pkg in cni netaddr; do # Add more package names if you know them
    if pip show "$pkg" &> /dev/null; then
        echo "Uninstalling Python package: $pkg"
        pip uninstall -y "$pkg" || true
    fi
done
# Remove any specific CNI script directories if known (e.g., if you cloned a repo)
# Example: If you cloned a CNI project into your home directory
# rm -rf ~/some-cni-project-directory || true


# 9. More thorough Docker cleanup (beyond just stopping/disabling)
echo "Performing more thorough Docker cleanup (removes all images, containers, volumes, networks)..."
# Stop all running containers
sudo docker stop $(sudo docker ps -aq) || true
# Remove all containers
sudo docker rm $(sudo docker ps -aq) || true
# Remove all images
sudo docker rmi $(sudo docker images -aq) || true
# Remove all volumes
sudo docker volume rm $(sudo docker volume ls -q) || true
# Remove all networks (except bridge, host, none)
sudo docker network rm $(sudo docker network ls -q | grep -v "bridge\|host\|none" | awk '{print $1}') || true
# Prune all unused Docker data
sudo docker system prune -a -f --volumes || true
# Remove Docker data directories
echo "Removing Docker data directories..."
sudo rm -rf /var/lib/docker || true
sudo rm -rf /etc/docker || true # Docker configuration directory
sudo rm -rf /var/run/docker.sock || true # Docker socket

# 10. Optional: Clean up containerd data (uncomment with caution if you have other containers)
# This is already covered in step 3 by stopping/disabling and then in step 4 by removing /var/lib/kubelet which often contains containerd data.
# However, if containerd was installed independently, its data might reside elsewhere.
echo "Removing Containerd data directories (use with caution if you have other containers managed by containerd)..."
sudo rm -rf /var/lib/containerd || true # For Containerd



sudo rm -rf /usr/local/bin/python3.12
sudo rm -rf /usr/local/lib/python3.12
sudo rm -rf /usr/local/include/python3.12
sudo rm -rf /usr/local/share/man/man1/python3.12.1

#Also remove source files if you built from /usr/src/Python-3.12.x
sudo rm -rf /usr/src/Python-3.12.*


# --- Additions end here ---

echo "Kubernetes cleanup complete."
echo "Rebooting the system to ensure all changes take effect..."


# Reboot the system to ensure all changes take effect
sudo reboot

echo "Thank you so much see you in a minute :)"