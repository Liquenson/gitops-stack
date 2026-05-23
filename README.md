# gitops-stack

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes)
![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)
![Ansible](https://img.shields.io/badge/Ansible-2.10-EE0000?logo=ansible)
![Jenkins](https://img.shields.io/badge/Jenkins-2.555-D24939?logo=jenkins)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)
![License](https://img.shields.io/badge/License-MIT-green)

> Pipeline GitOps de nivel productivo sobre **AWS EKS** — infraestructura como código, CI/CD automatizado, configuración sin SSH y acceso al cluster mediante roles IAM asumibles. Sin intervención manual. Sin bastiones. Sin secretos hardcodeados.

---

## ¿Qué es y qué resuelve?

**gitops-stack** es una plataforma de entrega continua que automatiza el ciclo de vida completo del software en AWS — desde el commit hasta el despliegue en producción — siguiendo el patrón GitOps.

**Resuelve tres problemas reales de equipos DevOps:**

| Problema | Solución |
|----------|----------|
| Despliegues manuales propensos a errores | Pipeline CI/CD end-to-end con Jenkins, 7 stages automatizados |
| Acceso inseguro al cluster EKS (usuarios directos, SSH) | IAM Role asumible + Ansible via AWS SSM — cero credenciales estáticas |
| Infraestructura no reproducible | Terraform modular con backend S3 — `terraform apply` recrea todo desde cero |

**Git actúa como única fuente de verdad** para código, infraestructura, configuración y accesos. Ningún cambio llega a producción sin pasar por Pull Request, tests y aprobación humana.

---

## Arquitectura

```
Developer → git push → Pull Request → merge a main
                                           ↓
                                    Jenkins Pipeline
                          ┌────────────────────────────────┐
                          │  1. pytest (fail fast)          │
                          │  2. docker build + push ECR     │
                          │  3. terraform plan + apply      │
                          │     ├─ VPC + EKS + KMS          │
                          │     ├─ IAM Role eks-admin-role  │
                          │     └─ EKS Access Entries       │
                          │  4. Ansible via AWS SSM         │
                          │     ├─ common: base + timezone  │
                          │     ├─ security: firewalld SSH  │
                          │     └─ monitoring: CloudWatch   │
                          │  5. sts:AssumeRole → kubectl    │
                          │     └─ rolling update sin downtime│
                          └────────────────────────────────┘
                                           ↓
                              AWS EKS — gitops-stack-prod
                          ┌────────────────────────────────┐
                          │  2 nodos t3.small (2 AZs)      │
                          │  2 réplicas — self-healing      │
                          │  Subredes privadas — sin IP     │
                          └────────────────────────────────┘
```

---

## Stack tecnológico

| Capa | Herramienta | Función |
|------|-------------|---------|
| Aplicación | Python / Flask | API REST con endpoints `/` y `/health` |
| Contenedorización | Docker | Imagen optimizada por capas con caché |
| Registry | AWS ECR | Registry privado — tag por BUILD_NUMBER |
| CI/CD | Jenkins on-premise | Pipeline declarativo, 7 stages |
| IaC | Terraform 1.9 | VPC, EKS, IAM, KMS — backend S3 |
| Config Management | Ansible + AWS SSM | Configuración de nodos sin SSH |
| Orquestación | AWS EKS (K8s 1.35) | Cluster gestionado, multi-AZ |
| Acceso cluster | IAM Role + STS | `sts:AssumeRole` — sesiones temporales |
| Monitorización | CloudWatch + Grafana | Métricas, logs, Container Insights |
| Auditoría | CloudTrail | Registro de todas las acciones AWS |
| Seguridad nodos | firewalld + dnf-automatic | Hardening automático en cada deploy |
| Control versiones | Git / GitHub | Branch protection + PR obligatorio |

---

## Estructura del proyecto

```
gitops-stack/
├── app/                          # API Flask
│   ├── app.py
│   └── requirements.txt
├── tests/
│   └── test_app.py               # pytest — 2 tests, fail fast
├── k8s/
│   ├── deployment.yaml           # 2 réplicas, rolling update
│   └── service.yaml              # NodePort
├── terraform/
│   ├── main.tf                   # VPC + EKS + IAM Role + Access Entries
│   ├── variables.tf              # aws_account_id, eks_admin_user, región
│   ├── outputs.tf                # cluster_endpoint, configure_kubectl
│   └── users.tf                  # 5 grupos IAM + 22 usuarios como código
├── ansible/
│   ├── ansible.cfg               # remote_user: ssm-user, tmp: /tmp/.ansible
│   ├── inventory.yml             # community.aws.aws_ssm
│   ├── site.yml                  # 4 plays: common, security, monitoring, verify
│   ├── group_vars/all.yml
│   └── roles/
│       ├── common/               # dnf update, paquetes, timezone, usuario deploy
│       ├── security/             # firewalld, SSH hardening, dnf-automatic
│       └── monitoring/           # CloudWatch agent, métricas cada 60s
├── scripts/
│   └── pre-destroy.sh            # Limpia LB de K8s antes del destroy
├── .github/workflows/
│   └── ci-cd.yml                 # GitHub Actions — tests en PRs
├── Jenkinsfile                   # Pipeline producción — 7 stages
└── Dockerfile                    # python:3.11-slim, capas optimizadas
```

---

## Pipeline CI/CD — 7 stages

```
Test → Build → Push ECR → Terraform → Ansible SSM → Kubernetes → ✅
```

| Stage | Qué hace | Si falla |
|-------|----------|----------|
| **Test** | `pytest tests/` — 2 tests | Pipeline se detiene |
| **Build** | `docker build` con caché de capas | Pipeline se detiene |
| **Push ECR** | Login + tag + push con BUILD_NUMBER | Pipeline se detiene |
| **Terraform** | `plan` → aprobación manual → `apply` | Requiere intervención |
| **Ansible SSM** | Configura nodos via SSM sin SSH | Ignorado con `ignore_errors` |
| **Kubernetes** | `sts:AssumeRole` → `kubectl apply` → rollout | Pipeline se detiene |

> Nunca se despliega código roto. Ningún cambio de infraestructura sin aprobación humana.

---

## Acceso EKS — Patrón empresarial

El cluster nunca se accede con usuarios IAM directamente. Todo pasa por un rol asumible.

```
liquenson-cli ──┐
                ├──→ sts:AssumeRole ──→ eks-admin-role ──→ EKS
Jenkins         ┘         (sesión temporal 1h)
```

**Gestionado 100% por Terraform:**

```hcl
resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"
  # liquenson-cli y Jenkins pueden asumir este rol
}

resource "aws_eks_access_entry" "admin" {
  principal_arn = aws_iam_role.eks_admin.arn  # el ROL, no el usuario
}

resource "aws_eks_access_policy_association" "admin" {
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}
```

**Beneficios:** sesiones temporales con expiración automática, trazabilidad en CloudTrail por cada `jenkins-deploy-{BUILD_NUMBER}`, cero credenciales estáticas.

---

## Gestión de identidades IAM

Todo gestionado como código en `terraform/users.tf`. Para añadir o eliminar usuarios: editar el archivo y abrir un Pull Request.

| Grupo | Permisos | Miembros |
|-------|----------|---------|
| `devops-team` | EKS + ECR + CloudWatch | dev-kevin, dev-wesley, dev-ruben, dev-pelegrino, dev-aisa, dev-ismael, dev-fermme |
| `developers` | ECR PowerUser + CloudWatch Logs | dev-yolanda, dev-marcus, dev-elena, dev-william |
| `security-team` | IAM ReadOnly | sec-maria, sec-john, sec-anna |
| `monitoring-team` | CloudWatch ReadOnly | ops-pedro, ops-sofia, ops-james |
| `data-team` | S3 Full + RDS ReadOnly | data-luis, data-nina, data-alex |

---

## Infraestructura AWS

| Recurso | Configuración |
|---------|--------------|
| VPC | `10.0.0.0/16` — eu-west-1 |
| Subredes privadas | 2 AZs — nodos sin IP pública |
| Subredes públicas | 2 AZs — load balancers |
| NAT Gateway | Single NAT — salida internet para nodos |
| EKS Cluster | K8s 1.35 — `gitops-stack-prod` |
| Node Group | 2× t3.small, min 1 / max 3, SSM habilitado |
| ECR | Registry privado `gitops-stack` |
| IAM Role | `eks-admin-role` — asumible, mínimo privilegio |
| KMS Key | Cifrado de secrets del cluster |
| CloudWatch | Container Insights + log groups 90 días |
| S3 Backend | `devops-lab-tfstate-538079272432` — estado compartido |

---

## Compatibilidad Amazon Linux 2023

Los nodos EKS corren AL2023. Diferencias clave respecto a versiones anteriores:

| Componente | Amazon Linux 2 | Amazon Linux 2023 |
|-----------|---------------|-------------------|
| Firewall | UFW | **firewalld** |
| Actualizaciones | unattended-upgrades | **dnf-automatic** |
| Grupo sudo | sudo | **wheel** |
| curl | curl | **curl-minimal** (no reemplazar) |
| Usuario SSM | ec2-user | **ssm-user** |
| tmp Ansible | `~/.ansible/tmp` | **`/tmp/.ansible/tmp`** |

---

## Quickstart — Despliegue en producción

```bash
# 1. Provisionar infraestructura completa
cd terraform
terraform init && terraform apply

# 2. Conectar kubectl (el rol se asume automáticamente en el pipeline)
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# 3. Verificar
kubectl get nodes && kubectl get pods -A
```

El IAM Role, EKS Access Entries y todos los usuarios IAM se crean automáticamente con el `terraform apply`. Sin pasos manuales adicionales.

## Destroy seguro

```bash
bash scripts/pre-destroy.sh          # elimina Load Balancer de K8s
cd terraform && terraform destroy -auto-approve
```

---

## Flujo Git — Branch Protection

```bash
git checkout -b feat/mi-cambio
git commit -m "feat: descripción"
git push origin feat/mi-cambio
# → Pull Request → merge → Jenkins lanza el pipeline automáticamente
```

Push directo a `main` está bloqueado. Todo cambio pasa por revisión.

---

## Principios de diseño

- **GitOps** — Git como única fuente de verdad para todo
- **Infraestructura inmutable** — nueva imagen por commit, nunca modificación en caliente
- **Acceso sin SSH** — Ansible via SSM, cero bastiones, cero claves SSH
- **Roles asumibles** — acceso EKS siempre mediante IAM Role, nunca usuario directo
- **Sesiones temporales** — credenciales con expiración automática vía STS
- **Fail fast** — el pipeline se detiene ante cualquier fallo de tests
- **Mínimo privilegio** — grupos y roles con permisos estrictamente necesarios
- **Trazabilidad completa** — cada deploy vinculado a commit + build number + usuario
- **Hardening automático** — Ansible aplica políticas de seguridad en cada nodo nuevo
- **Alta disponibilidad** — multi-AZ, self-healing, rolling updates sin downtime

---

## API Endpoints

| Endpoint | Método | Respuesta |
|----------|--------|-----------|
| `/` | GET | `hostname`, `version`, `status` del pod |
| `/health` | GET | Health check — liveness probe de Kubernetes |

---

Desarrollado por [Liquenson](https://github.com/Liquenson) · Ingeniero DevOps · Las Palmas de Gran Canaria

**Stack:** Python · Docker · Kubernetes · Jenkins · Terraform · Ansible · AWS SSM · AWS EKS · ECR · IAM · CloudWatch · CloudTrail
