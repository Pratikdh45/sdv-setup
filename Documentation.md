# Ansible Kubernetes Monitoring Stack Documentation

## Table of Contents
1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Components](#components)
4. [Setup and Configuration](#setup-and-configuration)
5. [Deployment Process](#deployment-process)
6. [Monitoring Stack](#monitoring-stack)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

## Overview
This project contains Ansible playbooks and roles for deploying a comprehensive Kubernetes monitoring stack. The stack includes Prometheus, Grafana, and Node Exporter for collecting and visualizing metrics from Kubernetes clusters.

## Project Structure
```
ansible-testing/
├── ansible.cfg              # Ansible configuration file
├── group_vars/
│   └── all.yml             # Global variables
├── host_vars/
│   └── 3.17.25.69.yml      # Host-specific variables
├── inventories/
│   ├── dev                 # Development environment inventory
│   ├── prod                # Production environment inventory
│   ├── qa                  # QA environment inventory
│   └── staging             # Staging environment inventory
├── playbooks/
│   ├── deploy_apps.yml     # Application deployment playbook
│   ├── deploy_monitoring.yml # Monitoring stack deployment
│   └── site.yml           # Main site playbook
└── roles/
    ├── grafana/           # Grafana deployment role
    ├── k8s_setup/        # Kubernetes setup role
    ├── monitoring/       # General monitoring role
    ├── nginx/           # NGINX configuration role
    ├── node_exporter/   # Node Exporter deployment
    ├── prometheus/      # Prometheus deployment
    └── python/         # Python environment setup
```

## Components

### Core Components
1. **Prometheus**
   - Purpose: Time-series database and monitoring system
   - Location: `roles/prometheus/`
   - Key files: `prometheus-deployment.yml`

2. **Grafana**
   - Purpose: Metrics visualization and dashboarding
   - Location: `roles/grafana/`
   - Key files: `grafana-deployment.yml`

3. **Node Exporter**
   - Purpose: System metrics collection
   - Location: `roles/node_exporter/`
   - Key files: 
     - `node-exporter-daemonset.yml`
     - `node-exporter-service.yml`

### Supporting Components
1. **NGINX**
   - Purpose: Reverse proxy and load balancing
   - Location: `roles/nginx/`
   - Configuration: `nginx.yml`

2. **Python Environment**
   - Purpose: Runtime environment setup
   - Location: `roles/python/`
   - Templates: `config.ini.j2`, `nginx.conf.j2`

## Setup and Configuration

### Prerequisites
- Ansible 2.9+
- Python 3.x
- Kubernetes cluster access
- SSH access to target hosts

### Initial Setup
1. Configure ansible.cfg:
   ```ini
   [defaults]
   inventory = inventories/dev
   remote_user = ansible
   host_key_checking = False
   ```

2. Set up inventory files in `inventories/` directory
3. Configure global variables in `group_vars/all.yml`
4. Adjust host-specific variables in `host_vars/`

## Deployment Process

### Step 1: Basic Infrastructure
```bash
ansible-playbook playbooks/site.yml -i inventories/dev
```

### Step 2: Monitoring Stack
```bash
ansible-playbook playbooks/deploy_monitoring.yml -i inventories/dev
```

### Step 3: Application Deployment
```bash
ansible-playbook playbooks/deploy_apps.yml -i inventories/dev
```

## Monitoring Stack

### Prometheus Configuration
- Data retention: 15 days
- Scrape interval: 30s
- Alert rules: Located in `roles/prometheus/files/rules/`

### Grafana Setup
- Default dashboards included
- Data source: Prometheus
- Default admin credentials in `group_vars/all.yml`

### Node Exporter
- Deployed as DaemonSet
- Metrics port: 9100
- System metrics collection interval: 15s

## Testing

### Prerequisites
- Python test dependencies
- Access to test environment

### Running Tests
1. Unit tests:
   ```bash
   ansible-playbook playbooks/site.yml --check
   ```

2. Integration tests:
   ```bash
   ansible-playbook playbooks/deploy_monitoring.yml --check
   ```

## Troubleshooting

### Common Issues
1. **Connection Issues**
   - Check SSH access
   - Verify inventory file configuration
   - Ensure correct SSH keys are available

2. **Deployment Failures**
   - Check Ansible logs in `ansible.log`
   - Verify Kubernetes cluster access
   - Check resource availability

3. **Monitoring Issues**
   - Verify Prometheus targets
   - Check Grafana data source configuration
   - Ensure Node Exporter metrics are accessible

### Support
For additional support:
1. Check the project's issue tracker
2. Review Ansible documentation
3. Contact the infrastructure team

---

## License
This project is licensed under the MIT License.

## Contributors
- DevOps Team
- Infrastructure Team
- Platform Engineering Team
