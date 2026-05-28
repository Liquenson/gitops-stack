<div align="center">

# gitops-stack

**Pipeline GitOps de nivel productivo sobre AWS EKS**

[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](https://python.org)
[![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-SSM-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![Jenkins](https://img.shields.io/badge/Jenkins-2.555-D24939?logo=jenkins&logoColor=white)](https://jenkins.io)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks)
[![License](https://img.shields.io/badge/License-MIT-22C55E)](LICENSE)

*Infraestructura como código · CI/CD automatizado · Configuración sin SSH · Acceso al cluster via IAM roles asumibles*

</div>

---

## Overview

`gitops-stack` automatiza el ciclo de vida completo del software en AWS — desde el commit hasta el despliegue en Kubernetes — siguiendo el patrón GitOps. Git es la única fuente de verdad para código, infraestructura, configuración y accesos. Ningún cambio llega a producción sin Pull Request, tests automáticos y aprobación humana.

| Problema | Solución |
|----------|----------|
| Despliegues manuales propensos a error | Pipeline Jenkins de 7 stages — 100% automatizado |
| Acceso inseguro al cluster EKS | IAM Role asumible + `sts:AssumeRole` — cero credenciales estáticas |
| Infraestructura no reproducible | Terraform modular con backend S3 — `apply` recrea todo desde cero |
| Configuración manual de servidores | Ansible via AWS SSM — sin SSH, sin bastión, sin IP pública |

---

## Architecture

```
git push → PR → merge main
                    │
             Jenkins Pipeline                    AWS
             ────────────────         ┌──────────────────────┐
             1. pytest               │  VPC 10.0.0.0/16      │
             2. docker build         │  ├─ private subnets   │
             3. push ECR             │  │   worker-node ×2   │
             4. terraform apply  ──► │  └─ public subnets    │
             5. ansible SSM          │      NAT Gateway       │
             6. kubectl rollout      │                        │
             ────────────────        │  EKS gitops-stack-prod │
                    │                │  2 réplicas · multi-AZ │
                    └──────────────► │  self-healing · TLS    │
                                     └──────────────────────┘
```

---

## Stack

| Layer | Tool | Role |
|-------|------|------|
| App | Python / Flask | API REST — `/` `/health` |
| Container | Docker | Imagen optimizada por capas · tag `BUILD_NUMBER` |
| Registry | AWS ECR | Registry privado — pull solo con IAM |
| CI/CD | Jenkins on-premise | Pipeline declarativo — Jenkinsfile versionado |
| IaC | Terraform 1.9 | VPC · EKS · IAM · KMS · backend S3 |
| Config | Ansible + AWS SSM | Hardening y monitoring sin SSH |
| Orchestration | AWS EKS 1.35 | Cluster gestionado · multi-AZ |
| Access | IAM Role + STS | `sts:AssumeRole` — sesiones de 1h |
| Observability | CloudWatch · Grafana | Container Insights · logs 90d |
| Audit | CloudTrail | Cada acción AWS registrada con timestamp |

---

## Pipeline

```
Test ──► Build ──► ECR ──► Terraform ──► Ansible SSM ──► Kubernetes ──► ✅
```

| Stage | Action | On failure |
|-------|--------|------------|
| **Test** | `pytest tests/` — fail fast | Pipeline aborts |
| **Build** | `docker build` con layer cache | Pipeline aborts |
| **Push ECR** | Tag `:{BUILD_NUMBER}` + push | Pipeline aborts |
| **Terraform** | `plan` → aprobación manual → `apply` | Requiere intervención |
| **Ansible SSM** | common · security · monitoring | `ignore_errors` en telnet |
| **Kubernetes** | `sts:AssumeRole` → `kubectl apply` → rollout | Pipeline aborts |

---

## IAM Pattern

Ningún usuario tiene acceso directo al cluster. Todo pasa por `eks-admin-role`.

```
liquenson-cli  ─┐
                ├─► sts:AssumeRole ─► eks-admin-role ─► EKS cluster
Jenkins        ─┘   (1h TTL)          (Terraform managed)
```

```hcl
# main.tf — Access Entry apunta al ROL, nunca al usuario
resource "aws_eks_access_entry" "admin" {
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
```

CloudTrail audita cada `jenkins-deploy-{BUILD_NUMBER}` con rol, timestamp y región.

---

## Infrastructure

```
AWS eu-west-1
├── VPC 10.0.0.0/16
│   ├── private subnets  10.0.1.0/24 · 10.0.2.0/24  (workers — sin IP pública)
│   └── public subnets   10.0.101.0/24 · 10.0.102.0/24  (load balancers)
├── EKS  gitops-stack-prod  K8s 1.35
│   └── Node Group  2× t3.small · SSM enabled · min 1 / max 3
├── ECR  gitops-stack  (privado)
├── IAM  eks-admin-role + 5 grupos + 22 usuarios (users.tf)
├── KMS  alias/eks/gitops-stack-prod  (secrets cifrados)
├── CloudWatch  Container Insights · log groups 90d
└── S3  devops-lab-tfstate-538079272432  (Terraform backend)
```

**IAM groups gestionados como código en `users.tf`:**

| Group | Policy | Members |
|-------|--------|---------|
| `devops-team` | EKS + ECR + CloudWatch | dev-kevin, dev-wesley, dev-ruben, dev-pelegrino, dev-aisa, dev-ismael, dev-fermme |
| `developers` | ECR PowerUser + CW Logs | dev-yolanda, dev-marcus, dev-elena, dev-william |
| `security-team` | IAM ReadOnly | sec-maria, sec-john, sec-anna |
| `monitoring-team` | CloudWatch ReadOnly | ops-pedro, ops-sofia, ops-james |
| `data-team` | S3 Full + RDS ReadOnly | data-luis, data-nina, data-alex |

---

## Ansible via SSM

Los nodos EKS corren Amazon Linux 2023 en subredes privadas. Ansible los configura sin SSH ni bastión usando `community.aws.aws_ssm` como connection plugin.

| Role | Tasks |
|------|-------|
| `common` | dnf update · paquetes base · timezone · usuario `deploy` · límites archivos |
| `security` | SSH hardening · firewalld (HTTPS+SSH+6443) · `dnf-automatic` |
| `monitoring` | CloudWatch agent · métricas 60s · `/var/log/messages` + `/var/log/secure` |

> **Fix producción:** `immediate: yes` en firewalld mantiene la sesión SSM activa durante el hardening — sin esto, el nodo pierde conexión al activar el firewall.

**Amazon Linux 2023 vs AL2:**

| | Amazon Linux 2 | Amazon Linux 2023 |
|-|----------------|-------------------|
| Firewall | UFW | `firewalld` |
| Updates | unattended-upgrades | `dnf-automatic` |
| sudo group | `sudo` | `wheel` |
| SSM user | `ec2-user` | `ssm-user` |
| Ansible tmp | `~/.ansible/tmp` | `/tmp/.ansible/tmp` |

---

## Quickstart

```bash
# Infraestructura completa desde cero
cd terraform
terraform init
terraform apply          # IAM Role + EKS + VPC + usuarios — sin pasos manuales

# Conectar kubectl
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# Verificar
kubectl get nodes
kubectl get pods -A
```

```bash
# Destroy seguro
bash scripts/pre-destroy.sh          # elimina LB antes del destroy
cd terraform && terraform destroy -auto-approve
```

---

## Git Workflow

```bash
git checkout -b feat/mi-cambio
git commit -m "feat: descripción"
git push origin feat/mi-cambio
# → Pull Request → merge → Jenkins pipeline automático
```

`main` tiene branch protection activa. Push directo bloqueado.

---

## Project Structure

```
gitops-stack/
├── app/                    # Flask API
├── tests/                  # pytest
├── k8s/                    # Deployment + Service manifests
├── terraform/
│   ├── main.tf             # VPC · EKS · IAM Role · Access Entries · KMS
│   ├── users.tf            # 5 grupos + 22 usuarios IAM como código
│   ├── variables.tf
│   └── outputs.tf
├── ansible/
│   ├── roles/
│   │   ├── common/
│   │   ├── security/       # firewalld con immediate:yes para SSM
│   │   └── monitoring/     # CloudWatch agent
│   ├── site.yml
│   └── inventory.yml       # community.aws.aws_ssm
├── scripts/
│   └── pre-destroy.sh
├── Jenkinsfile             # 7-stage declarative pipeline
└── Dockerfile              # python:3.11-slim · layer cache optimizado
```

---

## Design Principles

```
GitOps          Git es la única fuente de verdad — nada existe sin un commit
Immutable       Nueva imagen por commit — nunca modificación en caliente
Zero-SSH        Ansible via SSM — sin bastiones, sin claves SSH, sin IPs públicas
Least Privilege IAM con mínimo privilegio — roles, no usuarios directos
Fail Fast       Pipeline se detiene ante cualquier fallo de tests
Auditability    Cada deploy vinculado a commit + BUILD_NUMBER + usuario + timestamp
```

---

<div align="center">

Developed by [Liquenson](https://github.com/Liquenson) · DevOps Engineer · Las Palmas de Gran Canaria

</div>
