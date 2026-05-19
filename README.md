# gitops-stack

Pipeline GitOps de nivel productivo construido sobre Docker, Kubernetes, Jenkins, Terraform y ArgoCD. Desplegado en AWS EKS.

## Descripción

Plataforma de entrega continua que automatiza el ciclo de vida completo del software — desde el commit hasta el despliegue en producción en AWS — siguiendo el patrón GitOps. Git actúa como única fuente de verdad para el estado del clúster y la infraestructura.

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
  ├── VPC con subredes públicas y privadas
  ├── 2 nodos worker t3.medium
  ├── 2 réplicas con balanceo de carga
  ├── Self-healing mediante liveness probes
  └── Actualizaciones sin downtime (rolling update)
          ↓
ArgoCD (GitOps)
  ├── Monitoriza repositorio Git
  ├── Reconcilia estado del clúster
  └── Despliega automáticamente al detectar cambios
          ↓
Prometheus + Grafana
  ├── Métricas de CPU, memoria y pods en tiempo real
  └── Dashboards de Kubernetes preconfigurados
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
| Monitorización | Prometheus + Grafana | Prometheus + Grafana |
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
│   └── service.yaml        # Service Kubernetes (NodePort)
├── terraform/
│   ├── main.tf             # VPC + EKS en AWS
│   ├── variables.tf        # Parámetros configurables por entorno
│   └── outputs.tf          # Endpoints y comandos de conexión
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # Pipeline GitHub Actions
├── Jenkinsfile             # Pipeline Jenkins para producción
└── Dockerfile              # Imagen optimizada por capas
```

## Pipeline CI/CD con Jenkins

Cada push a `main` dispara el pipeline automáticamente:

1. **Test** — Ejecución de tests con pytest. Si fallan, el pipeline se detiene completamente.
2. **Build** — Construcción de imagen Docker con caché de capas optimizado.
3. **Push a ECR** — Publicación de la imagen en el registry privado de AWS con tag único por build.
4. **Terraform Plan** — Planificación de cambios de infraestructura. Muestra exactamente qué se va a crear o modificar.
5. **Aprobación manual** — Un ingeniero revisa el plan y aprueba antes de aplicar cambios en producción.
6. **Terraform Apply** — Creación o actualización de infraestructura en AWS.
7. **Deploy en EKS** — Actualización del Deployment en Kubernetes con la nueva imagen.

> Nunca se despliega código roto. Nunca se modifica infraestructura sin aprobación humana.

## Infraestructura AWS (Terraform)

| Recurso | Configuración |
|---------|--------------|
| VPC | CIDR 10.0.0.0/16 — eu-west-1 |
| Subredes privadas | 2 AZs — nodos worker aislados de internet |
| Subredes públicas | 2 AZs — load balancers |
| NAT Gateway | Salida a internet para nodos privados |
| EKS Cluster | Kubernetes v1.35 — gitops-stack-prod |
| Node Group | 2 nodos t3.medium (min 1, max 3) |
| ECR | Registry privado — gitops-stack |
| IAM Roles | Roles de clúster y nodos con mínimo privilegio |
| KMS Key | Cifrado del clúster |
| Estado Terraform | S3 backend — compartido por todo el equipo |

## Recursos Kubernetes

| Recurso | Descripción |
|---------|-------------|
| Deployment | Gestiona 2 réplicas con estrategia rolling update |
| ReplicaSet | Garantiza el número de réplicas deseado en todo momento |
| Service | Balanceo de carga interno entre réplicas |
| Liveness Probe | Consulta `/health` cada 5 segundos — self-healing automático |
| Namespace argocd | ArgoCD instalado via Helm |
| Namespace monitoring | Prometheus + Grafana instalados via Helm |

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
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

## Despliegue en producción (AWS)

```bash
# Provisionar infraestructura
cd terraform
terraform init
terraform plan
terraform apply

# Conectar kubectl al clúster EKS
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# Verificar clúster
kubectl get nodes
kubectl get pods -A
```

## Principios aplicados

- **GitOps** — Git como única fuente de verdad para código e infraestructura
- **Infraestructura inmutable** — Cada cambio genera una nueva imagen, nunca se modifica en caliente
- **Fail fast** — El pipeline se detiene ante cualquier fallo de tests
- **Aprobación manual** — Ningún cambio de infraestructura se aplica sin revisión humana
- **Caché de capas** — Dockerfile estructurado para minimizar tiempos de build en el pipeline
- **Alta disponibilidad** — Self-healing automático, múltiples réplicas, múltiples zonas de disponibilidad
- **Trazabilidad** — Cada despliegue vinculado a un commit y build number concreto
- **Mínimo privilegio** — Roles IAM con permisos estrictamente necesarios
- **Registry privado** — Imágenes en ECR, nunca en registries públicos en producción

## Lo que demuestra este proyecto

Este proyecto implementa el flujo completo que usa un equipo DevOps en una empresa real:

- Un developer hace push → Jenkins detecta el cambio automáticamente
- Los tests validan el código antes de cualquier despliegue
- La imagen se construye y sube a un registry privado con versionado automático
- Terraform gestiona la infraestructura como código con aprobación manual
- Kubernetes orquesta los contenedores con self-healing y rolling updates
- ArgoCD mantiene el estado del clúster sincronizado con Git
- Prometheus y Grafana monitorizan el sistema en tiempo real

---

Desarrollado por [Liquenson](https://github.com/Liquenson) · Ingeniero DevOps  
Stack: Docker · Kubernetes · Jenkins · Terraform · AWS EKS · ECR · ArgoCD · Prometheus · Grafana
