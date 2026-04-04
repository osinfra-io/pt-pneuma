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

Each workflow (sandbox, non-production, production) deploys a `main` workspace first, then runs the per-zone job chains in parallel across all 6 zones. The diagram below shows the dependency chain for one zone — the same pattern repeats for each zone.

```mermaid
flowchart TD
    classDef gke fill:#4285F4,stroke:#4285F4,color:#fff
    classDef certmanager fill:#0195D8,stroke:#0195D8,color:#fff
    classDef istio fill:#466BB0,stroke:#466BB0,color:#fff
    classDef datadog fill:#632CA6,stroke:#632CA6,color:#fff
    classDef opa fill:#23263B,stroke:#23263B,color:#fff

    main["Main"]:::gke
    zone["Regional"]:::gke
    onboarding["Onboarding"]:::gke

    main --> zone
    zone --> onboarding
    onboarding --> cert_manager["cert-manager"]:::certmanager

    cert_manager --> cert_manager_istio_csr["cert-manager Istio CSR"]:::certmanager
    cert_manager --> opa_gatekeeper["OPA Gatekeeper"]:::opa

    cert_manager_istio_csr --> istio["Istio"]:::istio

    onboarding --> datadog["Datadog"]:::datadog

    datadog --> datadog_manifests["Datadog Manifests"]:::datadog
    istio --> istio_manifests["Istio Manifests"]:::istio
    istio_manifests --> istio_test["Istio Test"]:::istio

    opa_gatekeeper --> opa_gatekeeper_templates["OPA Gatekeeper Templates"]:::opa
    opa_gatekeeper_templates --> opa_gatekeeper_constraints["OPA Gatekeeper Constraints"]:::opa
```
