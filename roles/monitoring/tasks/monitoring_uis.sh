#!/bin/bash

# This script helps access Grafana and Prometheus UIs after Ansible deployment.
# Run this script on your EC2 instance after the Ansible playbook completes:
# chmod +x access_monitoring_uis.sh
# ./access_monitoring_uis.sh

# --- Configuration ---
KUBECONFIG_PATH="/home/ec2-user/.kube/config" # Ensure this matches your Ansible setup
GRAFANA_NAMESPACE="monitoring"
PROMETHEUS_NAMESPACE="monitoring"
GRAFANA_SERVICE_NAME="grafana"
PROMETHEUS_SERVICE_NAME="prometheus" # Assumes your Prometheus service is named 'prometheus'

# --- Functions ---

# Function to get EC2 instance ID
get_instance_id() {
    curl -s http://169.254.169.254/latest/meta-data/instance-id
}

# Function to get the security group ID attached to the instance
get_security_group_id() {
    aws ec2 describe-instances --instance-ids "$1" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text
}

# Function to add inbound rule to security group
add_security_group_rule() {
    local sg_id="$1"
    local port="$2"
    local description="$3"
    local result=$(aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port "$port" --cidr 0.0.0.0/0 --description "$description" 2>&1)

    if echo "$result" | grep -q "InvalidPermission.Duplicate"; then
        echo "  - Rule for port $port already exists."
    elif [ $? -eq 0 ]; then
        echo "  - Successfully added rule for port $port."
    else
        echo "  - Failed to add rule for port $port: $result"
        echo "    (You might need to add this rule manually via AWS Console/CLI)"
        echo "    AWS CLI command: aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port $port --cidr 0.0.0.0/0 --description \"$description\""
    fi
}


# --- Main Script Logic ---

echo "--- Kubernetes UI Access Helper ---"

# Get EC2 Public IP
EC2_PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
if [ -z "$EC2_PUBLIC_IP" ]; then
    echo "ERROR: Could not get EC2 Public IP. Please check internet connectivity."
    exit 1
fi
echo "Your EC2 Public IP: $EC2_PUBLIC_IP"

echo -e "\n--- Checking Grafana Service ---"
GRAFANA_TYPE=$(sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$GRAFANA_NAMESPACE" "$GRAFANA_SERVICE_NAME" -o jsonpath='{.spec.type}')

if [ "$GRAFANA_TYPE" != "NodePort" ]; then
    echo "Grafana Service is of type '$GRAFANA_TYPE'. Modifying to NodePort..."
    sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl patch svc "$GRAFANA_SERVICE_NAME" -n "$GRAFANA_NAMESPACE" -p '{"spec":{"type":"NodePort"}}'
    echo "Waiting for Grafana Service to update..."
    sleep 5
fi

GRAFANA_NODEPORT=$(sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$GRAFANA_NAMESPACE" "$GRAFANA_SERVICE_NAME" -o jsonpath='{.spec.ports[?(@.port==3000)].nodePort}')
if [ -z "$GRAFANA_NODEPORT" ]; then
    echo "ERROR: Could not determine Grafana NodePort. Check service status."
    exit 1
fi
echo "Grafana NodePort: $GRAFANA_NODEPORT"
echo "Grafana UI URL: http://$EC2_PUBLIC_IP:$GRAFANA_NODEPORT"
echo "Default credentials: admin/admin (you will be prompted to change)"


echo -e "\n--- Checking Prometheus Service ---"
PROMETHEUS_TYPE=$(sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_SERVICE_NAME" -o jsonpath='{.spec.type}')

# Check if Prometheus service actually exists first
if ! sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_SERVICE_NAME" &> /dev/null; then
    echo "WARNING: Prometheus service '$PROMETHEUS_SERVICE_NAME' not found in '$PROMETHEUS_NAMESPACE' namespace."
    echo "         Please ensure Prometheus is deployed and its service is named correctly."
    PROMETHEUS_NODEPORT="" # Set to empty if service not found
else
    # Prometheus UI typically runs on port 9090
    if [ "$PROMETHEUS_TYPE" != "NodePort" ]; then
        echo "Prometheus Service is of type '$PROMETHEUS_TYPE'. Modifying to NodePort..."
        sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl patch svc "$PROMETHEUS_SERVICE_NAME" -n "$PROMETHEUS_NAMESPACE" -p '{"spec":{"type":"NodePort"}}'
        echo "Waiting for Prometheus Service to update..."
        sleep 5
    fi

    PROMETHEUS_NODEPORT=$(sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_SERVICE_NAME" -o jsonpath='{.spec.ports[?(@.port==9090)].nodePort}')
    if [ -z "$PROMETHEUS_NODEPORT" ]; then
        echo "ERROR: Could not determine Prometheus NodePort. Check service status."
        # Attempt a broader search if 9090 isn't found
        PROMETHEUS_NODEPORT=$(sudo KUBECONFIG="$KUBECONFIG_PATH" kubectl get svc -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_SERVICE_NAME" -o jsonpath='{.spec.ports[0].nodePort}')
        if [ -z "$PROMETHEUS_NODEPORT" ]; then
             echo "ERROR: Fallback for Prometheus NodePort failed. It might not be exposed on 9090 or first port."
        fi
    fi

    if [ -n "$PROMETHEUS_NODEPORT" ]; then
        echo "Prometheus NodePort: $PROMETHEUS_NODEPORT"
        echo "Prometheus UI URL: http://$EC2_PUBLIC_IP:$PROMETHEUS_NODEPORT"
    fi
fi


echo -e "\n--- Attempting to Configure EC2 Security Group ---"
echo "NOTE: This requires 'aws cli' to be installed and the EC2 instance to have an IAM role with 'ec2:AuthorizeSecurityGroupIngress' permissions."

INSTANCE_ID=$(get_instance_id)
if [ -z "$INSTANCE_ID" ]; then
    echo "WARNING: Could not get EC2 Instance ID. Cannot automate security group modification."
    echo "         Please ensure 'aws cli' is installed and configured or add rules manually."
else
    echo "EC2 Instance ID: $INSTANCE_ID"
    SG_ID=$(get_security_group_id "$INSTANCE_ID")
    if [ -z "$SG_ID" ]; then
        echo "ERROR: Could not get Security Group ID for instance '$INSTANCE_ID'."
        echo "       Please add the security group rules manually."
    else
        echo "Associated Security Group ID: $SG_ID"
        echo "Adding inbound rules (TCP from 0.0.0.0/0):"
        if [ -n "$GRAFANA_NODEPORT" ]; then
            add_security_group_rule "$SG_ID" "$GRAFANA_NODEPORT" "Grafana UI access"
        fi
        if [ -n "$PROMETHEUS_NODEPORT" ]; then
            add_security_group_rule "$SG_ID" "$PROMETHEUS_NODEPORT" "Prometheus UI access"
        fi
    fi
fi

echo -e "\n--- Manual Security Group Setup (if automated failed) ---"
echo "If the automated security group modification failed or you prefer manual, do the following:"
echo "1. Go to your AWS EC2 Console -> Instances."
echo "2. Select your instance ($EC2_PUBLIC_IP)."
echo "3. In the 'Security' tab, click on the Security Group ID (e.g., $SG_ID)."
echo "4. Go to 'Inbound rules' -> 'Edit inbound rules'."
echo "5. Add new rules:"
echo "   - Type: Custom TCP, Port range: $GRAFANA_NODEPORT, Source: 0.0.0.0/0 (or your IP)"
echo "   - Type: Custom TCP, Port range: $PROMETHEUS_NODEPORT, Source: 0.0.0.0/0 (or your IP)"
echo "   - Make sure you save the rules."

echo -e "\n--- Done ---"
echo "Grafana UI: http://$EC2_PUBLIC_IP:$GRAFANA_NODEPORT"
echo "Prometheus UI: http://$EC2_PUBLIC_IP:$PROMETHEUS_NODEPORT"