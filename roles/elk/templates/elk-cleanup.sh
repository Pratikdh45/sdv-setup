#!/bin/bash
#
# This script forcefully removes all components of the ELK stack deployed by the Ansible role.
# It is designed to be run from your Ubuntu server if a Helm deployment becomes corrupted.
#

echo "\n--- Deleting Elasticsearch Persistent Volume ---"
kubectl delete pv elasticsearch-pv-0
kubectl delete pv elasticsearch-pv-1



echo "\n--- Deleting Elasticsearch Persistent Volume Claims ---"
kubectl delete pvc -n monitoring -l app=elasticsearch-master --ignore-not-found=true
kubectl delete pvc -n monitoring -l app=elasticsearch-data --ignore-not-found=true



echo "--- Uninstalling ELK Helm Releases (errors for 'not found' are OK) ---"
helm uninstall elasticsearch -n monitoring || true
helm uninstall kibana -n monitoring || true
helm uninstall logstash -n monitoring || true
helm uninstall filebeat -n monitoring || true

echo "\n--- Forcefully Deleting Orphaned Kibana Resources (errors for 'not found' are OK) ---"
kubectl delete role -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete role -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete rolebinding -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete rolebinding -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete job -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete job -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete service -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete service -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete configmap -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete configmap -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete secret -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete secret -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete job -n monitoring -l app.kubernetes.io/instance=kibana --ignore-not-found=true
kubectl delete serviceaccount -n monitoring pre-install-kibana-kibana --ignore-not-found=true
kubectl delete serviceaccount -n monitoring post-delete-kibana-kibana --ignore-not-found=true
kubectl delete configmap -n monitoring kibana-kibana-helm-scripts --ignore-not-found=true




echo "\nELK cleanup complete."

