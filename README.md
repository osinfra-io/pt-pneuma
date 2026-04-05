# Pneuma

[![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-pneuma/dependabot.yml?style=for-the-badge&logo=github&color=2088FF&label=Dependabot)](https://github.com/osinfra-io/pt-pneuma/actions/workflows/dependabot.yml) [![Datadog Security Enabled](https://img.shields.io/badge/Datadog%20Security-Enabled-632CA6?style=for-the-badge&logo=datadog)](https://app.datadoghq.com/security/code-security/repositories?repository_id=pt-pneuma)

## 📄 Repository Description

This repository contains the Infrastructure as Code (IaC) that shapes the Pneuma domain — the breathing, dynamic layer of the platform where structure comes alive. In the wider hierarchy of the Platform Team, Pneuma serves as the stratum where Corpus projects and networking become animated workload environments capable of receiving and running application teams.

Here, Kubernetes clusters are called into being across multiple zones; certificate management, service mesh, and policy enforcement are woven into each cluster; and Datadog observability extends its reach into the runtime so the platform can perceive and regulate itself at the application layer.

The Pneuma layer is where infrastructure breathes — where the static order established by Logos and the tangible form given by Corpus are joined by living workloads, dynamic routing, and continuous delivery. It is the atmosphere within which application teams move, build, and ship.

### 🛠️ Tools

- [pre-commit](https://github.com/pre-commit/pre-commit)
- [osinfra-pre-commit-hooks](https://github.com/osinfra-io/pt-techne-pre-commit-hooks)

### 📋 Skills and Knowledge

Links to documentation and other resources required to develop and iterate in this repository successfully.

- [cert-manager](https://cert-manager.io/docs/)
- [datadog kubernetes monitoring](https://docs.datadoghq.com/containers/kubernetes/)
- [datadog synthetics](https://docs.datadoghq.com/synthetics/)
- [google kubernetes engine](https://cloud.google.com/kubernetes-engine/docs)
- [istio service mesh](https://istio.io/latest/docs/)
- [kubernetes](https://kubernetes.io/docs/home/)
- [opa gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)

## 🔄 Deployment Dependency Graph

Each workflow (sandbox, non-production, production) deploys a `main` workspace first, then runs the per-zone job chains in parallel. Sandbox and non-production deploy **2 zones** (us-east1-b, us-east4-a); production deploys all **6 zones** (us-east1-b/c/d, us-east4-a/b/c). Two zones are expanded below — every zone follows the same dependency chain.

```mermaid
flowchart LR
    classDef gke fill:#4285F4,stroke:#4285F4,color:#fff
    classDef certmanager fill:#0195D8,stroke:#0195D8,color:#fff
    classDef istio fill:#466BB0,stroke:#466BB0,color:#fff
    classDef datadog fill:#632CA6,stroke:#632CA6,color:#fff
    classDef opa fill:#23263B,stroke:#23263B,color:#fff

    main["Main"]:::gke

    main --> z1_regional["Regional: us-east1-b"]:::gke
    z1_regional --> z1_onboarding["Onboarding: us-east1-b"]:::gke
    z1_onboarding --> z1_cert_manager["cert-manager: us-east1-b"]:::certmanager
    z1_onboarding --> z1_datadog["Datadog: us-east1-b"]:::datadog
    z1_cert_manager --> z1_cert_manager_istio_csr["cert-manager Istio CSR: us-east1-b"]:::certmanager
    z1_cert_manager --> z1_opa_gatekeeper["OPA Gatekeeper: us-east1-b"]:::opa
    z1_cert_manager_istio_csr --> z1_istio["Istio: us-east1-b"]:::istio
    z1_istio --> z1_istio_manifests["Istio Manifests: us-east1-b"]:::istio
    z1_istio_manifests --> z1_istio_test["Istio Test: us-east1-b"]:::istio
    z1_datadog --> z1_datadog_manifests["Datadog Manifests: us-east1-b"]:::datadog
    z1_opa_gatekeeper --> z1_opa_templates["OPA Gatekeeper Templates: us-east1-b"]:::opa
    z1_opa_templates --> z1_opa_constraints["OPA Gatekeeper Constraints: us-east1-b"]:::opa

    main --> z2_regional["Regional: us-east4-a"]:::gke
    z2_regional --> z2_onboarding["Onboarding: us-east4-a"]:::gke
    z2_onboarding --> z2_cert_manager["cert-manager: us-east4-a"]:::certmanager
    z2_onboarding --> z2_datadog["Datadog: us-east4-a"]:::datadog
    z2_cert_manager --> z2_cert_manager_istio_csr["cert-manager Istio CSR: us-east4-a"]:::certmanager
    z2_cert_manager --> z2_opa_gatekeeper["OPA Gatekeeper: us-east4-a"]:::opa
    z2_cert_manager_istio_csr --> z2_istio["Istio: us-east4-a"]:::istio
    z2_istio --> z2_istio_manifests["Istio Manifests: us-east4-a"]:::istio
    z2_istio_manifests --> z2_istio_test["Istio Test: us-east4-a"]:::istio
    z2_datadog --> z2_datadog_manifests["Datadog Manifests: us-east4-a"]:::datadog
    z2_opa_gatekeeper --> z2_opa_templates["OPA Gatekeeper Templates: us-east4-a"]:::opa
    z2_opa_templates --> z2_opa_constraints["OPA Gatekeeper Constraints: us-east4-a"]:::opa
```
