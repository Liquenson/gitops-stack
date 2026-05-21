# gitops-stack

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes)
![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)
![Ansible](https://img.shields.io/badge/Ansible-2.10-EE0000?logo=ansible)
![Jenkins](https://img.shields.io/badge/Jenkins-2.555-D24939?logo=jenkins)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)
![License](https://img.shields.io/badge/License-MIT-green)

Pipeline GitOps de nivel productivo desplegado en **AWS EKS** — construido sobre Docker, Kubernetes, Jenkins, Terraform, Ansible y CloudWatch. Incluye gestión de identidades IAM, auditoría con CloudTrail, monitorización con CloudWatch y configuración automática de nodos via AWS Systems Manager (SSM), sin necesidad de SSH ni bastión.

## Descripción

Plataforma de entrega continua que automatiza el ciclo de vida completo del software — desde el commit hasta el despliegue en producción en AWS — siguiendo el patrón GitOps. Git actúa como única fuente de verdad para el código, la infraestructura, la configuración y la gestión de accesos.

## Arquitectura

\`\`\`
Developer hace git push
          ↓
Jenkins (CI/CD on-premise)
  ├── Ejecuta tests automáticos (pytest)
  ├── Construye imagen Docker
  ├── Publica imagen en AWS ECR (registry privado)
  ├── Ejecuta Terraform plan + aprobación manual
  ├── Terraform apply → infraestructura en AWS
  ├── Ansible via AWS SSM → configura nodos automáticamente
  │     ├── common: paquetes base + timezone + usuario deploy
  │     ├── security: hardening SSH + firewalld + dnf-automatic
  │     └── monitoring: agente CloudWatch (métricas + logs)
  └── kubectl → despliega app en EKS (rolling update)
          ↓
AWS EKS (Kubernetes gestionado)
  ├── VPC con subredes públicas y privadas (2 AZs)
  ├── 2 nodos worker t3.small en subredes privadas
  ├── 2 réplicas con balanceo de carga
  ├── Self-healing mediante liveness probes
  └── Actualizaciones sin downtime (rolling update)
          ↓
Observabilidad
  ├── CloudWatch Container Insights — métricas AWS
  ├── CloudWatch Logs — logs centralizados de /var/log/messages y /var/log/secure
  └── CloudTrail — auditoría de todas las acciones AWS
\`\`\`

## Stack tecnológico

| Capa | Local | Producción (AWS) |
|------|-------|-----------------|
| Aplicación | Python / Flask | Python / Flask |
| Contenedorización | Docker | Docker |
| Registry de imágenes | — | AWS ECR (privado) |
| Pipeline CI/CD | GitHub Actions | Jenkins (on-premise) |
| Infraestructura como código | — | Terraform |
| Configuración de nodos | — | Ansible via AWS SSM |
| Orquestación | — | AWS EKS (Kubernetes 1.35) |
| Monitorización | — | CloudWatch + Container Insights |
| Auditoría | — | CloudTrail |
| Gestión de accesos | — | AWS IAM (grupos + políticas) |
| Control de versiones | Git / GitHub | Git / GitHub |

## Estructura del proyecto

\`\`\`
gitops-stack/
├── app/
│   ├── app.py                    # API REST con Flask
│   └── requirements.txt          # Dependencias Python
├── tests/
│   └── test_app.py               # Tests automatizados (pytest)
├── k8s/
│   ├── deployment.yaml           # Deployment Kubernetes (2 réplicas)
│   └── service.yaml              # Service Kubernetes (NodePort)
├── terraform/
│   ├── main.tf                   # VPC + EKS en AWS
│   ├── variables.tf              # Parámetros configurables por entorno
│   ├── outputs.tf                # Endpoints y comandos de conexión
│   └── users.tf                  # Gestión de usuarios y grupos IAM
├── ansible/
│   ├── ansible.cfg               # Configuración global (SSM, remote_user: ssm-user)
│   ├── inventory.yml             # Inventario via community.aws.aws_ssm
│   ├── site.yml                  # Playbook principal
│   ├── group_vars/
│   │   └── all.yml               # Variables globales compartidas
│   └── roles/
│       ├── common/               # Paquetes base, timezone, usuario deploy
│       ├── security/             # Hardening SSH, firewalld, dnf-automatic
│       └── monitoring/           # Agente CloudWatch
├── scripts/
│   └── pre-destroy.sh            # Script de limpieza antes del destroy
├── .github/
│   └── workflows/
│       └── ci-cd.yml             # Pipeline GitHub Actions (desarrollo)
├── Jenkinsfile                   # Pipeline Jenkins para producción
└── Dockerfile                    # Imagen optimizada por capas
\`\`\`

## Pipeline CI/CD con Jenkins

Cada push a \`main\` dispara el pipeline automáticamente:

1. **Test** — Ejecución de tests con pytest. Si fallan, el pipeline se detiene.
2. **Build** — Construcción de imagen Docker con caché de capas optimizado.
3. **Push a ECR** — Publicación en registry privado AWS con tag único por build number.
4. **Terraform Plan** — Planificación de cambios con aprobación manual antes de aplicar.
5. **Terraform Apply** — Creación o actualización de infraestructura en AWS.
6. **Ansible via SSM** — Configuración automática de los nodos EKS sin SSH ni bastión.
7. **Deploy en EKS** — \`kubectl apply\` + rolling update sin downtime.

> Nunca se despliega código roto. Nunca se modifica infraestructura sin aprobación humana.

## Configuración de nodos con Ansible via SSM

Ansible configura automáticamente cada nodo EC2 a través de AWS Systems Manager Session Manager. No se requiere SSH, bastión ni IP pública — los nodos están en subredes privadas.

| Rol | Descripción |
|-----|-------------|
| \`common\` | Actualiza paquetes (dnf), instala wget/git/vim/htop/net-tools/unzip/python3, configura timezone Europe/Madrid, crea usuario \`deploy\` en grupo \`wheel\`, configura límites de archivos abiertos |
| \`security\` | Hardening SSH (deshabilita root login y autenticación por contraseña, cambia puerto), instala y configura \`firewalld\` (SSH + puerto 6443), instala \`dnf-automatic\` para actualizaciones de seguridad automáticas |
| \`monitoring\` | Instala agente CloudWatch, configura métricas de CPU/memoria/disco cada 60s, centraliza logs de \`/var/log/messages\` y \`/var/log/secure\` en CloudWatch Logs |

**Requisitos para que SSM funcione:**
- Política \`AmazonSSMManagedInstanceCore\` en el rol IAM del node group (gestionado por Terraform)
- \`remote_user: ssm-user\` en \`ansible.cfg\`
- \`remote_tmp: /tmp/.ansible/tmp\` en \`ansible.cfg\`
- \`session-manager-plugin\` instalado en el host que ejecuta Ansible
- Plugin \`community.aws.aws_ssm\` en el inventario

\`\`\`bash
# Ejecutar playbook manualmente
cd ansible
ansible-playbook site.yml -e NODE1_ID=i-xxxxx -e NODE2_ID=i-yyyyy

# Ejecutar solo un rol específico
ansible-playbook site.yml --tags security
ansible-playbook site.yml --tags monitoring
\`\`\`

## Infraestructura AWS (Terraform)

| Recurso | Configuración |
|---------|--------------|
| VPC | CIDR 10.0.0.0/16 — eu-west-1 (Irlanda) |
| Subredes privadas | 2 AZs — nodos worker aislados de internet |
| Subredes públicas | 2 AZs — load balancers |
| NAT Gateway | Salida a internet para nodos privados |
| EKS Cluster | Kubernetes v1.35 — gitops-stack-prod |
| Node Group | 2 nodos t3.small (min 1, max 3) con SSM habilitado |
| ECR | Registry privado — gitops-stack |
| IAM Roles | Roles de clúster y nodos con mínimo privilegio |
| KMS Key | Cifrado del clúster |
| CloudTrail | Auditoría multi-región en S3 |
| CloudWatch | Container Insights + logs del clúster |
| Estado Terraform | S3 backend — compartido por todo el equipo |

## Gestión de Identidades IAM (Terraform)

Todos los usuarios y grupos se gestionan como código en \`terraform/users.tf\`:

| Grupo | Permisos | Usuarios |
|-------|----------|---------|
| \`devops-team\` | EKS + ECR + CloudWatch | dev-kevin, dev-wesley, dev-ruben, dev-pelegrino, dev-aisa, dev-ismael, dev-fermme |
| \`developers\` | ECR PowerUser + CloudWatch Logs | dev-yolanda, dev-marcus, dev-elena, dev-william |
| \`security-team\` | IAM ReadOnly | sec-maria, sec-john, sec-anna |
| \`monitoring-team\` | CloudWatch ReadOnly | ops-pedro, ops-sofia, ops-james |
| \`data-team\` | S3 Full + RDS ReadOnly | data-luis, data-nina, data-alex |

Para añadir un usuario — edita \`users.tf\` y ejecuta \`terraform apply\`. Para eliminarlo — quítalo de la lista.

## Acceso al clúster EKS

El acceso a EKS se gestiona mediante EKS Access Entries (API nativa, no aws-auth configmap):

\`\`\`bash
# Añadir acceso de administrador a un usuario IAM
aws eks create-access-entry \
  --cluster-name gitops-stack-prod \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --region eu-west-1

aws eks associate-access-policy \
  --cluster-name gitops-stack-prod \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region eu-west-1
\`\`\`

## Procedimiento de destroy seguro

\`\`\`bash
# Paso 1 — Pre-destroy (elimina recursos de Kubernetes que bloquean el destroy)
bash scripts/pre-destroy.sh

# Paso 2 — Destruir infraestructura
cd terraform
terraform destroy -auto-approve
\`\`\`

## Ejecución en local

\`\`\`bash
# Clonar el repositorio
git clone https://github.com/Liquenson/gitops-stack.git
cd gitops-stack

# Construir y ejecutar con Docker
docker build -t gitops-stack:local .
docker run -d -p 5000:5000 gitops-stack:local

# Verificar funcionamiento
curl http://localhost:5000
curl http://localhost:5000/health
\`\`\`

## Despliegue en producción (AWS)

\`\`\`bash
# Provisionar infraestructura y usuarios IAM
cd terraform
terraform init
terraform plan
terraform apply

# Conectar kubectl al clúster EKS
aws eks update-kubeconfig --region eu-west-1 --name gitops-stack-prod

# Añadir acceso EKS al usuario administrador
aws eks create-access-entry \
  --cluster-name gitops-stack-prod \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --region eu-west-1

aws eks associate-access-policy \
  --cluster-name gitops-stack-prod \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/USERNAME \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region eu-west-1

# Verificar clúster
kubectl get nodes
kubectl get pods -A

# Configurar nodos con Ansible (se ejecuta automáticamente en el pipeline)
cd ansible
ansible-playbook site.yml -e NODE1_ID=i-xxxxx -e NODE2_ID=i-yyyyy
\`\`\`

## Endpoints de la API

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| \`/\` | GET | Devuelve hostname del pod, versión y estado |
| \`/health\` | GET | Health check para liveness probe de Kubernetes |

## Compatibilidad Amazon Linux 2023

Los nodos EKS corren Amazon Linux 2023. Diferencias clave respecto a versiones anteriores:

| Componente | Amazon Linux 2 | Amazon Linux 2023 |
|-----------|---------------|-------------------|
| Firewall | UFW | firewalld |
| Actualizaciones automáticas | unattended-upgrades | dnf-automatic |
| Grupo sudoers | sudo | wheel |
| curl preinstalado | curl | curl-minimal (no reemplazar) |
| Usuario SSM | ec2-user | ssm-user |
| Directorio tmp Ansible | ~/.ansible/tmp | /tmp/.ansible/tmp |

## Principios aplicados

- **GitOps** — Git como única fuente de verdad para código, infraestructura y configuración
- **Infraestructura inmutable** — Cada cambio genera una nueva imagen, nunca se modifica en caliente
- **Configuración como código** — Ansible gestiona la configuración de servidores de forma reproducible
- **Acceso sin SSH** — Ansible via AWS SSM elimina la necesidad de bastiones y claves SSH
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

**Stack:** Docker · Kubernetes · Jenkins · Terraform · Ansible · AWS SSM · AWS EKS · ECR · CloudWatch · CloudTrail · IAM
