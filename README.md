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

## Troubleshooting

https://docs.ray.io/en/master/cluster/kubernetes/troubleshooting/rayservice-troubleshooting.html#kuberay-raysvc-troubleshoot

```bash

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
## Using kustomize
kubectl delete -k inference/vllm/lws/mixtral-8x7b-instruct
```