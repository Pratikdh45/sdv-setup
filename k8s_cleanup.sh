#!/bin/bash

# --- Log Setup ---
LOG_DIR="$(dirname "$0")/logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/cleanup-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

# Redirect all output to both the log file and the console
exec &> >(tee -a "$LOG_FILE")

echo "Starting full Kubernetes and application cleanup..."
echo "Log file for this run: $LOG_FILE"
echo "----------------------------------------------------"

# --- Phase 1: Application & Kubernetes Resource Cleanup ---
echo "PHASE 1: Deleting Kubernetes resources (Namespace, PV, StorageClass)..."
kubectl delete namespace sdv --ignore-not-found --timeout=2m || echo "  Namespace 'sdv' not found or could not be deleted."
# kubectl delete pv mysql-pv --ignore-not-found --timeout=30s || echo "  PersistentVolume 'mysql-pv' not found or could not be deleted."
kubectl delete storageclass local-storage --ignore-not-found --timeout=30s || echo "  StorageClass 'local-storage' not found or could not be deleted."
echo "----------------------------------------------------"


# --- Phase 2: Kubernetes Cluster Teardown ---
echo "PHASE 2: Resetting the Kubernetes cluster..."
sudo kubeadm reset -f || echo "  'kubeadm reset' failed. This may be expected if the node was not a cluster member."
echo "----------------------------------------------------"


# --- Phase 3: CNI and Network Interface Cleanup ---
echo "PHASE 3: Cleaning up CNI configuration and network interfaces..."
echo "  Removing CNI configuration files..."
sudo rm -rf /etc/cni/net.d/*
echo "  Cleaning up Calico network interfaces..."
for iface in $(ip link show | grep -oE 'cali[a-f0-9]+|tunl0'); do
    echo "    Bringing down and deleting interface: $iface"
    sudo ip link set "$iface" down || true
    sudo ip link del "$iface" || true
done
echo "  Cleaning up other common CNI interfaces (flannel, cni0)..."
sudo ip link set flannel.1 down || true && sudo ip link del flannel.1 || true
sudo ip link set cni0 down || true && sudo ip link del cni0 || true
echo "----------------------------------------------------"


# --- Phase 4: Service & Container Runtime Purge ---
echo "PHASE 4: Stopping services and purging container runtime..."
echo "  Stopping kubelet and containerd services..."
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true
echo "----------------------------------------------------"


# --- Phase 5: Final File and Package Removal ---
echo "PHASE 5: Removing all remaining data, configs, and packages..."
echo "  Deleting Kubernetes, etcd, and CNI directories..."
sudo rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/ /var/lib/cni/
sudo rm -rf /run/kubernetes/ /var/run/kubernetes/ /var/run/calico
echo "  Deleting containerd directory..."
sudo rm -rf /var/lib/containerd
# echo "  Deleting manually installed Python..."
# sudo rm -rf /usr/local/bin/python /usr/local/bin/python3.12 /usr/local/lib/python3.12 /usr/local/include/python3.12
# sudo rm -rf /usr/src/Python-3.12.*

echo "  Removing APT repositories and keys..."
sudo rm -f /etc/apt/keyrings/docker-apt-keyring.asc
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.asc
sudo rm -f /etc/apt/sources.list.d/kubernetes.list

echo "  Purging Kubernetes and container packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get purge -y kubelet kubeadm kubectl kubernetes-cni containerd.io || true
    sudo apt-get autoremove -y || true
elif command -v dnf &> /dev/null; then
    sudo dnf remove -y kubelet kubeadm kubectl kubernetes-cni containerd.io || true
elif command -v yum &> /dev/null; then
    sudo yum remove -y kubelet kubeadm kubectl kubernetes-cni containerd.io || true
fi
echo "----------------------------------------------------"


echo "Cleanup complete."
echo "Recommedned: Reboot the system to ensure all changes take effect."
