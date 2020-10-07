#!/bin/sh

GITHUB_USER="mbrancato"
FLUX_VERSION="1.21.0"
FLUX_HELM_VERSION="1.2.0"
METALLB_VERSION="0.9.3"
MULTUS_VERSION="3.6"
INGRESS_NGINX_VERSION="2.11.2"

helm template flux fluxcd/flux \
   --namespace flux \
   --set git.readonly=true \
   --set git.user=${GITHUB_USER} \
   --set git.email=${GITHUB_USER}@users.noreply.github.com \
   --set git.url=git@github.com:${GITHUB_USER}/homelab-test \
   --set git.path="clusters/homelab" \
   --set syncGarbageCollection.enabled=true \
   --set registry.disableScanning=true \
   --set image.tag="$FLUX_VERSION" > flux/flux.yaml
helm template helm-operator fluxcd/helm-operator \
   --namespace flux \
   --set helm.versions=v3 \
   --set image.tag="$FLUX_HELM_VERSION" > flux/helm-operator.yaml
helm template node-problem-detector stable/node-problem-detector > node-problem-detector.yaml
curl -s "https://raw.githubusercontent.com/fluxcd/helm-operator/${FLUX_HELM_VERSION}/deploy/crds.yaml" > flux/helm-crds.yaml
curl -s "https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/namespace.yaml" > networking/metallb/metallb.yaml
curl -s "https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/metallb.yaml" > networking/metallb/metallb.yaml
curl -s "https://raw.githubusercontent.com/intel/multus-cni/v${MULTUS_VERSION}/images/multus-daemonset.yml" > networking/multus/multus-daemonset.yaml
curl -s "https://raw.githubusercontent.com/kubernetes/ingress-nginx/ingress-nginx-${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml" > networking/ingress/ingress-nginx.yaml
