# solcnai-llm-examples
Examples repo for various LLM inference scenarios

## Testing with LWS and VLLM

1. Requires Hugging-face secret

```bash
LLM_TESTING_NAMESPACE=llm

kubectl create ns ${LLM_TESTING_NAMESPACE}

## configure hugging face API token
export HUGGING_FACE_HUB_TOKEN=<TOKEN>
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HUGGING_FACE_HUB_TOKEN} \
    --dry-run=client -o yaml -n ${LLM_TESTING_NAMESPACE} | kubectl apply -f -
```


```bash
## install lws operator

VERSION=v0.3.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml

## deploy lws for target model
kubectl apply -k inference/vllm/lws/mixtral-8x7b-instruct

```

```bash
## Cleanup Using kustomize
kubectl delete -k inference/vllm/lws/mixtral-8x7b-instruct
```

## Testing with Kuberay Clusters

1. Requires Hugging-face secret

```bash
KUBERAY_TESTING_NAMESPACE=kuberay

kubectl create ns ${KUBERAY_TESTING_NAMESPACE}

## configure hugging face API token
export HUGGING_FACE_HUB_TOKEN=<TOKEN>
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HUGGING_FACE_HUB_TOKEN} \
    --dry-run=client -o yaml -n ${KUBERAY_TESTING_NAMESPACE} | kubectl apply -f -
```

### Deploy Kuberay Operator

https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/raycluster-quick-start.html

```bash
# This helm repo is same for all helm charts below
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install both CRDs and KubeRay operator v1.1.1.
helm upgrade --install kuberay-operator kuberay/kuberay-operator --namespace kuberay --create-namespace --version 1.1.1

# Confirm that the operator is running in the namespace `kuberay`
kubectl get pods -l app.kubernetes.io/name=kuberay-operator
# NAME                                          READY   STATUS    RESTARTS     AGE
# kuberay-operator-fcd9556c6-cn7pc              1/1     Running   0            4m28s

```

## Deploy Model Specific Kuberay - RayService

`kubectl apply -f inference/kuberay/mixtral-8x7b-instruct/ray-service.yaml -n ${KUBERAY_TESTING_NAMESPACE}`

## Troubleshooting

https://docs.ray.io/en/master/cluster/kubernetes/troubleshooting/rayservice-troubleshooting.html#kuberay-raysvc-troubleshoot

```bash

# make sure to update namespace

# Run ray status
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- ray status
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- ray summary actors
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- serve status
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- ray summary actors
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- ray list placement-groups --detail

kubectl get po -l ray.io/node-type=worker -L status.phase=Running -o name | cut -d/ -f2 | xargs -I {} kubectl exec -t {} -- ray status
kubectl get po -l ray.io/node-type=worker -L status.phase=Running -o name | cut -d/ -f2 | xargs -I {} kubectl exec -t {} -- ray summary actors
kubectl get po -l ray.io/node-type=worker -L status.phase=Running -o name | cut -d/ -f2 | xargs -I {} kubectl exec -t {} -- serve status

# Check the logs under /tmp/ray/session_latest/logs/serve/
kubectl exec -it $(kubectl get pods -l ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers) -- bash
kubectl exec -it $(kubectl get pods -l ray.io/node-type=worker -o custom-columns=POD:metadata.name --no-headers) -- bash

# Check ALL the logs under /tmp/ray/session_latest/logs
kubectl get po -l ray.io/node-type=worker -L status.phase=Running -o name | cut -d/ -f2 | xargs -I {} kubectl exec -t {} -- ls /tmp/ray/session_latest/logs

## view metrics
kubectl top nodes
kubectl top nodes --show-capacity
kubectl top pod --containers --sort-by=memory
kubectl top pod -l ray.io/node-type=worker --containers 
kubectl top pod -l ray.io/node-type=worker --sort-by=memory --containers 

## view taint
kubectl get nodes -o='custom-columns=NodeName:.metadata.name,TaintKey:.spec.taints[*].key,TaintValue:.spec.taints[*].value,TaintEffect:.spec.taints[*].effect'

# List PersistentVolumes sorted by capacity
kubectl get pv --sort-by=.spec.capacity.storage
```

```bash
### Mixtral 8x7b testing

curl https://mixtral.vllm.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistralai/Mixtral-8x7B-Instruct-v0.1",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
  }'

## benchmarking with lws / ray request-rate num-prompts
OPENAI_API_KEY=ANYTHING sh .staging/benchmarks/vllm-benchmark.sh https://mixtral.vllm.nkp.cloudnative.nvdlab.net mistralai/Mixtral-8x7B-Instruct-v0.1 5 2000
```

```bash
## chatbot app
https://gradio.vllm.nkp.cloudnative.nvdlab.net/

## ray dashboard (embedded with grafana dashboards)
https://ray.vllm.nkp.cloudnative.nvdlab.net/dashboard/#/overview

## public - view only grafana dashboards

## Ray
https://grafana.vllm.nkp.cloudnative.nvdlab.net/dkp/grafana/d/rayDefaultDashboard/ray-core-dashboard?orgId=1

## vllm
https://grafana.vllm.nkp.cloudnative.nvdlab.net/dkp/grafana/d/b281712d-8bff-41ef-9f3f-71ad43c05e9b/vllm?orgId=1

## DCGGM 
https://grafana.vllm.nkp.cloudnative.nvdlab.net/dkp/grafana/d/Oxed_c6Wz/platform-apps-nvidia-dcgm-exporter?orgId=1

```