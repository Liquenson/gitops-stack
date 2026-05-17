# gitops-stack

Pipeline GitOps de nivel productivo construido sobre Docker, Kubernetes, GitHub Actions y ArgoCD.

## Descripción

Plataforma de entrega continua que automatiza el ciclo de vida completo del software — desde el commit hasta el despliegue en producción — siguiendo el patrón GitOps. Git actúa como única fuente de verdad para el estado del clúster.

## Arquitectura

```
El desarrollador hace push
          ↓
GitHub Actions  ←─── CI
  ├── Ejecuta tests automáticos
  ├── Construye imagen Docker
  └── Publica en registry (Docker Hub)
          ↓
ArgoCD  ←─── CD / GitOps
  ├── Detecta cambios en el repositorio
  ├── Reconcilia el estado del clúster
  └── Despliega en Kubernetes automáticamente
          ↓
Clúster Kubernetes
  ├── 2 réplicas con balanceo de carga
  ├── Self-healing mediante liveness probes
  └── Actualizaciones sin downtime (rolling update)
```

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Aplicación | Python / Flask |
| Contenedorización | Docker |
| Registry de imágenes | Docker Hub |
| Pipeline CI | GitHub Actions |
| Orquestación | Kubernetes (Minikube) |
| Despliegue CD / GitOps | ArgoCD |
| Control de versiones | Git / GitHub |

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
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # Pipeline GitHub Actions
└── Dockerfile              # Imagen optimizada por capas
```

## Pipeline CI/CD

Cada push a `main` dispara el pipeline automáticamente:

1. **Test** — Ejecución de tests con pytest. Si fallan, el pipeline se detiene.
2. **Build** — Construcción de imagen Docker con caché de capas optimizado.
3. **Push** — Publicación de la imagen en el registry.
4. **Deploy** — ArgoCD detecta el cambio y sincroniza el clúster automáticamente.

> El despliegue solo se ejecuta si los tests pasan. Nunca se despliega código roto.

## Recursos Kubernetes

| Recurso | Descripción |
|---------|-------------|
| Deployment | Gestiona 2 réplicas con estrategia rolling update |
| ReplicaSet | Garantiza el número de réplicas deseado en todo momento |
| Service | Balanceo de carga interno entre réplicas (NodePort) |
| Liveness Probe | Consulta `/health` cada 5 segundos para verificar disponibilidad |

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/` | GET | Devuelve hostname, versión y estado del servicio |
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

# Desplegar en Kubernetes (requiere Minikube)
kubectl apply -f k8s/
minikube service pipeline-demo-service --url
```

## Equivalencia con entornos productivos

| Este proyecto | Entorno productivo |
|--------------|-------------------|
| Minikube | OpenShift / EKS / AKS |
| Docker Hub | ECR / Harbor (registry privado) |
| GitHub Actions | Jenkins (on-premise) |
| NodePort | Ingress Controller / LoadBalancer |
| Certificado autofirmado | Certificado TLS corporativo |

## Principios aplicados

- **GitOps** — Git como única fuente de verdad para el estado del clúster
- **Infraestructura inmutable** — Cada cambio genera una nueva imagen, nunca se modifica en caliente
- **Fail fast** — El pipeline se detiene ante cualquier fallo de tests
- **Caché de capas** — Dockerfile estructurado para minimizar tiempos de build
- **Alta disponibilidad** — Self-healing automático mediante liveness probes y ReplicaSet
- **Trazabilidad** — Cada despliegue vinculado a un commit concreto en Git

---

Desarrollado por [Liquenson](https://github.com/Liquenson) · Ingeniero DevOps
