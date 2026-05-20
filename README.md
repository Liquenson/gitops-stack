# gitops-stack

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes)
![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)
![Ansible](https://img.shields.io/badge/Ansible-2.10-EE0000?logo=ansible)
![Jenkins](https://img.shields.io/badge/Jenkins-2.555-D24939?logo=jenkins)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)
![ArgoCD](https://img.shields.io/badge/ArgoCD-3.4-EF7B4D?logo=argo)
![License](https://img.shields.io/badge/License-MIT-green)

Pipeline GitOps de nivel productivo desplegado en **AWS EKS** — construido sobre Docker, Kubernetes, Jenkins, Terraform, Ansible, ArgoCD y Prometheus. Incluye gestión de identidades IAM, auditoría con CloudTrail, monitorización con CloudWatch y configuración automática de nodos con Ansible.

## Descripción

Plataforma de entrega continua que automatiza el ciclo de vida completo del software — desde el commit hasta el despliegue en producción en AWS — siguiendo el patrón GitOps. Git actúa como única fuente de verdad para el código, la infraestructura, la configuración y la gestión de accesos.

## Arquitectura

```
Developer hace git push
          ↓
Jenkins (CI/CD on-premise)
  ├── Ejecuta tests automáticos (pytest)
  ├── Construye imagen Docker
  ├── Publica imagen en AWS ECR (registry privado)
  ├── Ejecuta Terraform plan + aprobación manual
  ├── Terraform apply → infraestructura en AWS
  ├── Ansible → configura nodos automáticamente
  │     ├── common: paquetes base + timezone + usuarios
  │     ├── security: hardening SSH + firewall UFW
  │     └── monitoring: agente CloudWatch
  └── kubectl → despliega app en EKS
          ↓
AWS EKS (Kubernetes gestionado)
  ├── VPC con subredes públicas y privadas (2 AZs)
  ├── 2 nodos worker t3.small configurados con Ansible
  ├── 2 réplicas con balanceo de carga
  ├── Load Balancer real expuesto a internet
  ├── Self-healing mediante liveness probes
  └── Actualizaciones sin downtime (rolling update)
          ↓
ArgoCD (GitOps)
  ├── Monitoriza repositorio Git
  ├── Reconcilia estado del clúster
  └── Despliega automáticamente al detectar cambios
          ↓
Observabilidad
  ├── Prometheus + Grafana — métricas del clúster
  ├── CloudWatch Container Insights — métricas AWS
  ├── CloudWatch Logs — logs centralizados
  └── CloudTrail — auditoría de todas las acciones AWS
```

## Stack tecnológico

| Capa | Local | Producción (AWS) |
|------|-------|-----------------|
| Aplicación | Python / Flask | Python / Flask |
| Contenedorización | Docker | Docker |
| Registry de imágenes | Docker Hub | AWS ECR (privado) |
| Pipeline CI/CD | GitHub Actions | Jenkins (on-premise) |
| Infraestructura como código | — | Terraform |
| Configuración de nodos | — | Ansible |
| Orquestación local | Minikube | AWS EKS |
| CD / GitOps | ArgoCD | ArgoCD |
| Monitorización | Prometheus + Grafana | CloudWatch + Grafana |
| Auditoría | — | CloudTrail |
| Gestión de accesos | — | AWS IAM (grupos + políticas) |
| Control de versiones | Git / GitHub | Git / GitHub |

## Estructura del proyecto

```
gitops-stack/
├── app/
│   ├── app.py                    # API REST con Flask
│   └── requirements.txt          # Dependencias Python
├── tests/
│   └── test_app.py               # Tests automatizados (pytest)
├── k8s/
│   ├── deployment.yaml           # Deployment Kubernetes (2 réplicas)
│   └── service.yaml              # Service Kubernetes (LoadBalancer)
├── terraform/
│   ├── main.tf                   # VPC + EKS en AWS
│   ├── variables.tf              # Parámetros configurables por entorno
│   ├── outputs.tf                # Endpoints y comandos de conexión
│   └── users.tf                  # Gestión de usuarios y grupos IAM
├── ansible/
│   ├── ansible.cfg               # Configuración global de Ansible
│   ├── inventory.yml             # Inventario de servidores
│   ├── site.yml                  # Playbook principal
│   ├── group_vars/
│   │   └── all.yml               # Variables globales compartidas
│   └── roles/
│       ├── common/               # Configuración base del sistema
│       ├── security/             # Hardening de seguridad
│       └── monitoring/           # Agente CloudWatch
├── scripts/
│   └── pre-destroy.sh            # Script de limpieza antes del destroy
├── .github/
│   └── workflows/
│       └── ci-cd.yml             # Pipeline GitHub Actions (desarrollo)
├── Jenkinsfile                   # Pipeline Jenkins para producción
└── Dockerfile                    # Imagen optimizada por capas
```

## Pipeline CI/CD con Jenkins

Cada push a `main` dispara el pipeline automáticamente:

1. **Test** — Ejecución de tests con pytest. Si fallan, el pipeline se detiene.
2. **Build** — Construcción de imagen Docker con caché de capas optimizado.
3. **Push a ECR** — Publicación en registry privado AWS con tag único por build number.
4. **Terraform Plan** — Planificación de cambios con aprobación manual antes de aplicar.
5. **Terraform Apply** — Creación o actualización de infraestructura en AWS.
6. **Ansible** — Configuración automática de los nodos EC2 recién creados.
7. **Deploy en EKS** — Actualización del Deployment con rolling update sin downtime.

> Nunca se despliega código roto. Nunca se modifica infraestructura sin aprobación humana.

## Configuración de nodos con Ansible

Ansible configura automáticamente cada nodo EC2 después de ser creado por Terraform:

| Rol | Descripción |
|-----|-------------|
| `common` | Actualiza paquetes, instala dependencias base, configura timezone Europe/Madrid, crea usuario de deploy, configura límites del sistema |
| `security` | Hardening SSH (deshabilita root login y autenticación por contraseña), configura firewall UFW, activa actualizaciones automáticas de seguridad |
| `monitoring` | Instala y configura agente CloudWatch para métricas de CPU, memoria y disco, centraliza logs en CloudWatch Logs |

```bash
# Ejecutar playbook manualmente
cd ansible
ansible-playbook site.yml --extra-vars "node1_ip=X.X.X.X node2_ip=Y.Y.Y.Y"

# Ejecutar solo un rol específico
ansible-playbook site.yml --tags security
ansible-playbook site.yml --tags monitoring
```

## Infraestructura AWS (Terraform)

| Recurso | Configuración |
|---------|--------------|
| VPC | CIDR 10.0.0.0/16 — eu-west-1 (Irlanda) |
| Subredes privadas | 2 AZs — nodos worker aislados de internet |
| Subredes públicas | 2 AZs — load balancers |
| NAT Gateway | Salida a internet para nodos privados |
| EKS Cluster | Kubernetes v1.35 — gitops-stack-prod |
| Node Group | 2 nodos t3.small (min 1, max 3) |
| ECR | Registry privado — gitops-stack |
| Load Balancer | AWS ELB expuesto a internet |
| IAM Roles | Roles de clúster y nodos con mínimo privilegio |
| KMS Key | Cifrado del clúster |
| CloudTrail | Auditoría multi-región en S3 |
| CloudWatch | Container Insights + logs del clúster |
| Estado Terraform | S3 backend — compartido por todo el equipo |

## Gestión de Identidades IAM (Terraform)

Todos los usuarios y grupos se gestionan como código en `terraform/users.tf`:

| Grupo | Permisos | Usuarios |
|-------|----------|---------|
| `devops-team` | EKS + ECR + CloudWatch | dev-kevin, dev-wesley, dev-ruben, dev-pelegrino, dev-aisa, dev-ismael, dev-fermme |
| `developers` | ECR PowerUser + CloudWatch Logs | dev-yolanda, dev-marcus, dev-elena, dev-william |
| `security-team` | IAM ReadOnly | sec-maria, sec-john, sec-anna |
| `monitoring-team` | CloudWatch ReadOnly | ops-pedro, ops-sofia, ops-james |
| `data-team` | S3 Full + RDS ReadOnly | data-luis, data-nina, data-alex |

Para añadir un usuario — edita `users.tf` y ejecuta `terraform apply`. Para eliminarlo — quítalo de la lista.

## Procedimiento de destroy seguro

```bash
# Paso 1 — Pre-destroy (elimina Load Balancer de Kubernetes)
bash scripts/pre-destroy.sh

# Paso 2 — Destruir infraestructura
cd terraform
terraform destroy -auto-approve
```

## Ejecución en local

```bash
# Clonar el repositorio
git clone https://github.com/Liquenson/gitops-stack.git
cd gitops-stack

# Construir y ejecutar con Docker
docker build -t gitops-stack:local .
docker run -d -p 5000:5000 gitops-stack:local

# Verificar funcionamiento
curl http://localhost:5000
curl http://localhost:5000/health

# Desplegar en Kubernetes local (requiere Minikube)
minikube start --driver=docker
kubectl apply -f k8s/
minikube service pipeline-demo-service --url

# Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Instalar monitorización
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

## Despliegue en producción (AWS)

```bash
# Provisionar infraestructura y usuarios IAM
cd terraform
terraform init
terraform plan
terraform apply

# Configurar nodos con Ansible
cd ../ansible
ansible-playbook site.yml

# Conectar kubectl al clúster EKS
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# Verificar clúster
kubectl get nodes
kubectl get pods -A
```

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/` | GET | Devuelve hostname del pod, versión y estado |
| `/health` | GET | Health check para liveness probe de Kubernetes |

## Principios aplicados

- **GitOps** — Git como única fuente de verdad para código, infraestructura y configuración
- **Infraestructura inmutable** — Cada cambio genera una nueva imagen, nunca se modifica en caliente
- **Configuración como código** — Ansible gestiona la configuración de servidores de forma reproducible
- **Fail fast** — El pipeline se detiene ante cualquier fallo de tests
- **Aprobación manual** — Ningún cambio de infraestructura se aplica sin revisión humana
- **Mínimo privilegio** — Roles y grupos IAM con permisos estrictamente necesarios
- **Alta disponibilidad** — Self-healing, múltiples réplicas, múltiples zonas de disponibilidad
- **Trazabilidad completa** — Cada despliegue vinculado a un commit, build number y usuario
- **Registry privado** — Imágenes en ECR, nunca en registries públicos en producción
- **Auditoría** — CloudTrail registra todas las acciones en AWS con timestamp y usuario
- **Hardening automático** — Ansible aplica políticas de seguridad en cada nodo nuevo

---

Desarrollado por [Liquenson](https://github.com/Liquenson) · Ingeniero DevOps

**Stack:** Docker · Kubernetes · Jenkins · Terraform · Ansible · AWS EKS · ECR · ArgoCD · Prometheus · Grafana · CloudWatch · CloudTrail · IAM
