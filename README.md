# gitops-stack

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes)
![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)
![Jenkins](https://img.shields.io/badge/Jenkins-2.555-D24939?logo=jenkins)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)
![ArgoCD](https://img.shields.io/badge/ArgoCD-3.4-EF7B4D?logo=argo)
![License](https://img.shields.io/badge/License-MIT-green)

Pipeline GitOps de nivel productivo desplegado en **AWS EKS** — construido sobre Docker, Kubernetes, Jenkins, Terraform, ArgoCD y Prometheus. Incluye gestión de identidades IAM, auditoría con CloudTrail y monitorización con CloudWatch.

## Descripción

Plataforma de entrega continua que automatiza el ciclo de vida completo del software — desde el commit hasta el despliegue en producción en AWS — siguiendo el patrón GitOps. Git actúa como única fuente de verdad para el código, la infraestructura y la gestión de accesos.

## Arquitectura

```
Developer hace git push
          ↓
Jenkins (CI/CD on-premise)
  ├── Ejecuta tests automáticos (pytest)
  ├── Construye imagen Docker
  ├── Publica imagen en AWS ECR (registry privado)
  ├── Ejecuta Terraform plan
  ├── Aprobación manual antes de aplicar
  └── Terraform apply → infraestructura en AWS
          ↓
AWS EKS (Kubernetes gestionado)
  ├── VPC con subredes públicas y privadas (2 AZs)
  ├── 2 nodos worker t3.small
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
│   ├── app.py              # API REST con Flask
│   └── requirements.txt    # Dependencias Python
├── tests/
│   └── test_app.py         # Tests automatizados (pytest)
├── k8s/
│   ├── deployment.yaml     # Deployment Kubernetes (2 réplicas)
│   └── service.yaml        # Service Kubernetes (LoadBalancer)
├── terraform/
│   ├── main.tf             # VPC + EKS en AWS
│   ├── variables.tf        # Parámetros configurables por entorno
│   ├── outputs.tf          # Endpoints y comandos de conexión
│   └── users.tf            # Gestión de usuarios y grupos IAM
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # Pipeline GitHub Actions (desarrollo)
├── Jenkinsfile             # Pipeline Jenkins para producción
└── Dockerfile              # Imagen optimizada por capas
```

## Pipeline CI/CD con Jenkins

Cada push a `main` dispara el pipeline automáticamente:

1. **Test** — Ejecución de tests con pytest. Si fallan, el pipeline se detiene.
2. **Build** — Construcción de imagen Docker con caché de capas optimizado.
3. **Push a ECR** — Publicación en registry privado AWS con tag único por build number.
4. **Terraform Plan** — Planificación de cambios. Muestra exactamente qué se va a crear o modificar.
5. **Aprobación manual** — Un ingeniero revisa el plan y aprueba antes de aplicar en producción.
6. **Terraform Apply** — Creación o actualización de infraestructura en AWS.
7. **Deploy en EKS** — Actualización del Deployment con la nueva imagen. Rolling update sin downtime.

> Nunca se despliega código roto. Nunca se modifica infraestructura sin aprobación humana.

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
| `devops-team` | EKS + ECR + CloudWatch | dev-kevin, dev-wesley, dev-ruben, dev-pelegrino |
| `developers` | ECR PowerUser + CloudWatch Logs | dev-sarah, dev-marcus, dev-elena |
| `security-team` | CloudTrail + IAM ReadOnly | sec-maria, sec-john, sec-anna |
| `monitoring-team` | CloudWatch ReadOnly | ops-pedro, ops-sofia, ops-james |
| `data-team` | S3 Full + RDS ReadOnly | data-luis, data-nina, data-alex |

Principio aplicado: **mínimo privilegio** — cada grupo tiene exactamente los permisos que necesita.

## Observabilidad

**CloudWatch Container Insights** — métricas de CPU, memoria y red de cada pod y nodo en tiempo real.

**CloudWatch Logs** — logs centralizados del clúster EKS: API server, scheduler, controller manager y authenticator. Los logs persisten aunque el pod haya muerto.

**CloudTrail** — auditoría completa de todas las acciones en AWS. Registra quién hizo qué, cuándo y desde dónde. Multi-región, almacenado en S3.

**Prometheus + Grafana** — dashboards de Kubernetes con métricas de pods, nodos y namespaces instalados via Helm.

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/` | GET | Devuelve hostname del pod, versión y estado |
| `/health` | GET | Health check para liveness probe de Kubernetes |

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

# Conectar kubectl al clúster EKS
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# Verificar clúster
kubectl get nodes
kubectl get pods -A

# Activar CloudWatch Container Insights
aws eks create-addon \
  --cluster-name gitops-stack-prod \
  --addon-name amazon-cloudwatch-observability \
  --region eu-west-1
```

## Principios aplicados

- **GitOps** — Git como única fuente de verdad para código, infraestructura y accesos
- **Infraestructura inmutable** — Cada cambio genera una nueva imagen, nunca se modifica en caliente
- **Fail fast** — El pipeline se detiene ante cualquier fallo de tests
- **Aprobación manual** — Ningún cambio de infraestructura se aplica sin revisión humana
- **Mínimo privilegio** — Roles y grupos IAM con permisos estrictamente necesarios
- **Caché de capas** — Dockerfile optimizado para minimizar tiempos de build
- **Alta disponibilidad** — Self-healing, múltiples réplicas, múltiples zonas de disponibilidad
- **Trazabilidad completa** — Cada despliegue vinculado a un commit, build number y usuario
- **Registry privado** — Imágenes en ECR, nunca en registries públicos en producción
- **Auditoría** — CloudTrail registra todas las acciones en AWS con timestamp y usuario

## Lo que demuestra este proyecto

Este proyecto implementa el flujo completo que usa un equipo DevOps en producción real:

- Developer hace push → Jenkins detecta el cambio automáticamente
- Tests validan el código antes de cualquier despliegue
- Imagen construida y subida a ECR privado con versionado automático por build number
- Terraform gestiona infraestructura y usuarios IAM como código con aprobación manual
- Kubernetes orquesta contenedores con self-healing y rolling updates sin downtime
- ArgoCD mantiene el estado del clúster sincronizado con Git — GitOps real
- CloudWatch + Prometheus monitorizan el sistema en tiempo real
- CloudTrail audita todas las acciones para cumplimiento y seguridad

---

Desarrollado por [Liquenson](https://github.com/Liquenson) · Ingeniero DevOps

**Stack:** Docker · Kubernetes · Jenkins · Terraform · AWS EKS · ECR · ArgoCD · Prometheus · Grafana · CloudWatch · CloudTrail · IAM
