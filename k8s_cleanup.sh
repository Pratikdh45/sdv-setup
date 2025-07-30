#!/bin/bash

# --- Log Setup ---
LOG_DIR="$(dirname "$0")/logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/cleanup-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

# Redirect all output to both the log file and the console
exec &> >(tee -a "$LOG_FILE")
#!/bin/bash

echo "Starting Kubernetes cleanup process..."

# 1. Run kubeadm reset to gracefully shut down Kubernetes components
echo "Running kubeadm reset..."
sudo kubeadm reset -f || true # Use || true to prevent script from exiting if reset fails on a partially configured system

# 2. Stop and disable Kubernetes services
echo "Stopping and disabling kubelet service..."
sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true

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

# Calico specific interfaces
echo "Cleaning up Calico CNI network interfaces..."
# Bring down and delete the main Calico tunnel interface (if used)
sudo ip link set tunl0 down || true
sudo ip link del tunl0 || true

# Find and delete any 'cali' interfaces (e.g., caliABCD, cali01234)
# Calico creates ephemeral 'cali' interfaces for each pod.
# This loop finds and deletes them.
for iface in $(ip link show | grep -oE 'cali[a-f0-9]+'); do
    echo "  Bringing down and deleting Calico interface: $iface"
    sudo ip link set "$iface" down || true
    sudo ip link del "$iface" || true
done


echo " Step 2: Delete any leftover Calico pods"
kubectl delete pods -n kube-system -l k8s-app=calico-node --ignore-not-found

echo " Step 3: Delete Calico CRDs"
calico_crds=$(kubectl get crds | grep 'projectcalico.org' | awk '{print $1}')
for crd in $calico_crds; do
  kubectl delete crd "$crd" --ignore-not-found
done

echo " Step 4: Delete Calico-related ConfigMaps and Secrets"
kubectl delete configmap -n kube-system calico-config --ignore-not-found
kubectl delete secret -n kube-system calico-etcd-secrets --ignore-not-found

echo " Step 5: Remove Calico CNI plugin files"
rm -rf /etc/cni/net.d/*calico*
rm -rf /opt/cni/bin/calico*
rm -rf /var/lib/cni/
rm -rf /var/run/calico


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


# 8. Clean up Python CNI-related downloads (assuming common locations)
# echo "Cleaning up Python CNI-related downloads..."
# This is a bit speculative as Python CNI components aren't always installed in a standard way.
# Common places might be virtual environments or directly in /usr/local/lib/pythonX.Y/dist-packages/
# We'll look for common CNI library names if installed via pip.
# Note: This will only remove packages installed via pip, not system-level Python packages unless forced.
# Use 'pip freeze' to list installed packages and then 'pip uninstall'
# This section assumes you want to remove Python packages that are specifically related to CNI setup.
# You might need to adjust the package names based on what you installed.
# echo "Checking for and removing common Python CNI-related packages..."
# for pkg in cni netaddr; do # Add more package names if you know them
#     if pip show "$pkg" &> /dev/null; then
#         echo "Uninstalling Python package: $pkg"
#         pip uninstall -y "$pkg" || true
#     fi
# done
# Remove any specific CNI script directories if known (e.g., if you cloned a repo)
# Example: If you cloned a CNI project into your home directory
# rm -rf ~/some-cni-project-directory || true


echo "Removing Docker data directories..."
sudo rm -rf /var/lib/docker || true
sudo rm -rf /etc/docker || true # Docker configuration directory
sudo rm -rf /var/run/docker.sock || true # Docker socket

# 10. Optional: Clean up containerd data (uncomment with caution if you have other containers)
# This is already covered in step 3 by stopping/disabling and then in step 4 by removing /var/lib/kubelet which often contains containerd data.
# However, if containerd was installed independently, its data might reside elsewhere.
echo "Removing Containerd data directories (use with caution if you have other containers managed by containerd)..."
sudo rm -rf /var/lib/containerd || true # For Containerd


echo "Kubernetes cleanup complete."
echo "Rebooting the system to ensure all changes take effect..."