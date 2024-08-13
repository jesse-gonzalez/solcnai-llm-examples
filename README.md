# solcnai-llm-examples
Examples repo for various LLM inference scenarios


## Testing with RayService using KubeRay

1. Requires Kuberay operator

2. Requires Hugging-face secret

```bash
LLM_TESTING_NAMESPACE=llm-testing

kubectl create ns ${LLM_TESTING_NAMESPACE}

## configure hugging face API token
export HUGGING_FACE_HUB_TOKEN=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
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HUGGING_FACE_HUB_TOKEN} \
    --dry-run=client -o yaml -n ${LLM_TESTING_NAMESPACE} | kubectl apply -f -

```