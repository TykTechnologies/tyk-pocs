# Tyk PoC Repository

Proof-of-concept and Production-ready Tyk deployment configurations,. All configs are transparent, documented, following best practices, and ready to use.

## 📝 License(s) Prerequisites

You can get free trial access through https://tyk.io/sign-up/

## 🚀 Quick Start

Choose your deployment:

### Docker Deployments

- **[Self-Managed](./docker/self-managed/)** - Full stack with Dashboard, Gateway, Portal, Redis, Postgres
- **[Hybrid](./docker/hybrid/)** - Tyk Cloud Dashboard + Self-hosted Gateway
- **[MDCB](./docker/mdcb/)** - Multi Data Center Bridge setup (Full stack- Control plane and Worker Data planes)

### Kubernetes (Helm) Deployments

- **[Helm Self-Managed](./kubernetes/helm-self-managed/)** - Full stack with Dashboard, Gateway, Portal, Redis, Postgres
- **[Hybrid](./kubernetes/helm-hybrid/)** - Tyk Cloud Dashboard + Self-hosted Gateway
- **[Hybrid](./kubernetes/helm-mdcb/)** - Multi Data Center Bridge setup (Full stack- Control plane and Worker Data planes)
- **[Operator](./kubernetes/standalone-operator/)** - Standalone Tyk Operator

## 📋 Requirements

- **Docker**: 20.10+ with Docker Compose
- **Kubernetes**: 1.24+ (for K8s deployments)
- **Tyk License**: Required for Dashboard, Dev Portal, Operator and MDCB Deployments

## 🎯 Design Principles

✅ **Transparency** - All configs visible and documented  
✅ **Education** - Learn by seeing and modifying  
✅ **Cross-platform** - Works on Windows, Mac, Linux  
✅ **Self-contained** - Each example includes everything needed  
✅ **Production-ready** - Based on best practices

## 🛠️ Utilities

- **[Bootstrap](./utils/bootstrap/)** - Automated org/admin/Provider/Users/APIs bootstraping for Tyk compenents.
- **[Cloud Setup](./utils/cloud-setup/)** - EC2, EKS, AKS deployment support
