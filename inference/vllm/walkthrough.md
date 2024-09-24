
## Native vLLM testing

## PreRequisites

- Files StorageClass
- Files NFS Export - /llm-model-store
- Lets Encrypt Cluster Issuer

## Deploy Native vLLM LLM Endpoint

1. Create Namespace and HuggingFace secret

```bash
## create namespace
kubectl create ns vllm

## configure hugging face API token secret
export HUGGING_FACE_HUB_TOKEN=<TOKEN>
kubectl create secret generic hf-secret \
    --from-literal=hf_api_token=${HUGGING_FACE_HUB_TOKEN} \
    --dry-run=client -o yaml -n vllm | kubectl apply -f -
```

2. Create PVC and PV

```bash
export NFS_STORAGE_CLASS=nai-nfs-storage
export FILES_SERVER_FQDN=files.odin.cloudnative.nvdlab.net

cat <<EOF | kubectl apply -n vllm -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  labels:
    storage: nfs
  name: vllm-volume
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 300Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: vllm-pvc
    namespace: vllm
  nfs:
    path: /llm-model-store/
    server: ${FILES_SERVER_FQDN}
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vllm-pvc
  namespace: vllm
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 300Gi
  selector:
    matchLabels:
      storage: nfs
  storageClassName: ${NFS_STORAGE_CLASS}
  volumeMode: Filesystem
  volumeName: vllm-volume
EOF
```

## Importing Custom Model

`task huggingface:download-model MODEL_NAME=meta-llama/Meta-Llama-3-70B-Instruct`

## Deploy

```bash

kubectl apply -k inference/vllm/base

## deploy
kubectl apply -k inference/vllm/overlays/meta-llama/Meta-Llama-3-70B-Instruct

## cleanup
kubectl delete -k inference/vllm/overlays/meta-llama/Meta-Llama-3-70B-Instruct

```

## Smoke Test

### LLama3-70b Instruct testing of Native vLLM Endpoint

```bash
### v1/completions
curl -k -X 'POST'  https://llm.vllm.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "meta-llama/Meta-Llama-3-70B-Instruct",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
}'

### v1/chat/completions
curl -k -X 'POST'  https://llm.vllm.nkp.cloudnative.nvdlab.net/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "meta-llama/Meta-Llama-3-70B-Instruct",
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful assistant."
        },
        {
          "role": "user",
          "content": "What did the fox jumped over?"
        }
      ],
      "stream": false,
      "temperature": 0.7,
      "max_tokens": 64,
      "top_p": 1,
      "temperature": 0
}'

```

### LLama3-70b Instruct testing of NAI Endpoint

```bash
### GET API KEY
export OPENAI_API_KEY=<>

### v1/completions
curl -k -X 'POST'  https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api/v1/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
      "model": "llama-3-70b-instruct",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
}'

### v1/chat/completions
curl -k -X 'POST'  https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
      "model": "llama-3-70b-instruct",
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful assistant."
        },
        {
          "role": "user",
          "content": "What did the fox jumped over?"
        }
      ],
      "stream": false,
      "temperature": 0.7,
      "max_tokens": 64,
      "top_p": 1,
      "temperature": 0
}'

```


### LLama3-70b Instruct testing of Native vLLM Endpoint

```bash
### v1/completions
curl -k -X 'POST'  https://llm.lws.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "meta-llama/Meta-Llama-3-70B-Instruct",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
}'

### v1/chat/completions
curl -k -X 'POST'  https://llm.lws.nkp.cloudnative.nvdlab.net/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "meta-llama/Meta-Llama-3-70B-Instruct",
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful assistant."
        },
        {
          "role": "user",
          "content": "What did the fox jumped over?"
        }
      ],
      "stream": false,
      "temperature": 0.7,
      "max_tokens": 64,
      "top_p": 1,
      "temperature": 0
}'

```

## Benchmark Test

```bash
## running vllm benchmark
source ~/.venv/bin/activate

## login to HF
export HF_HUB_TOKEN=<>
huggingface-cli login --token ${HF_HUB_TOKEN}

## OPENAI_API_KEY=ANYTHING ./benchmarks/vllm-benchmark.sh URL MODEL TOKENIZER GPU_MODEL GPU_COUNT REPLICA_COUNT MAX_TOKENS

## NAI EXAMPLE
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api llama-3-70b-instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## vllm EXAMPLE
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.vllm.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## lws EXAMPLE - 4 GPU x 1 VM
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.lws.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## lws EXAMPLE - 4 GPU x 2 VM
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.lws.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 2

```

## Issues

- [ ] Mistral Tokenizer Failure - needed to flip over to Llama 70b

```bash
## fails
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api mixtral-8x7b-inst-v1 mistralai/Mixtral-8x7B-Instruct-v0.1 L40S 4 1

## fails
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api mistral-7b-inst-v3 mistralai/Mistral-7B-Instruct-v0.3 L40S 4 1

## works
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api llama-3-8b-instruct meta-llama/Meta-Llama-3-8B-Instruct L40S 4 1

## works
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api llama-3-70b-instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## vllm EXAMPLE
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.vllm.nkp.cloudnative.nvdlab.net mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mixtral-8x7B-Instruct-v0.1 L40S 4 1
```


