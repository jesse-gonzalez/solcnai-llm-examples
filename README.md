- [solcnai-llm-examples](#solcnai-llm-examples)
  - [Pre-Requisites](#pre-requisites)
  - [Deploy Multi-GPU/Multi-Node Distributed Inferencing with LWS/vLLM/Ray (Tensor \& Pipeline Parallelization)](#deploy-multi-gpumulti-node-distributed-inferencing-with-lwsvllmray-tensor--pipeline-parallelization)
  - [Deploy Single-Node/Multi-GPU using vLLM (Tensor Parallelization)](#deploy-single-nodemulti-gpu-using-vllm-tensor-parallelization)
  - [Benchmarking using NVIDIA GenAI-Perf](#benchmarking-using-nvidia-genai-perf)
    - [Genai-Perf - Benchmarking Multiple Use Cases](#genai-perf---benchmarking-multiple-use-cases)
    - [Genai-Perf - Generate comparisons using Gen-AI](#genai-perf---generate-comparisons-using-gen-ai)
    - [Benchmarking using vLLM Project](#benchmarking-using-vllm-project)
  - [vLLM Benchmarks - Looping through Multiple Use Cases](#vllm-benchmarks---looping-through-multiple-use-cases)
  - [Troubleshooting](#troubleshooting)
    - [LLama3-70b Instruct testing of Native vLLM Endpoint](#llama3-70b-instruct-testing-of-native-vllm-endpoint)
    - [LLama3-70b Testing of NAI Endpoint](#llama3-70b-testing-of-nai-endpoint)
    - [LLama3-70b Instruct testing of Native vLLM Endpoint](#llama3-70b-instruct-testing-of-native-vllm-endpoint-1)
  - [Other Scenarios](#other-scenarios)
    - [Testing with Kuberay Clusters/Service](#testing-with-kuberay-clustersservice)
    - [Deploy Kuberay Operator](#deploy-kuberay-operator)
    - [Kuberay - Deploy Model Specific RayService](#kuberay---deploy-model-specific-rayservice)
    - [Kuberay - Troubleshooting](#kuberay---troubleshooting)



# solcnai-llm-examples

Examples repo for various LLM inferencing Deployment and Testing scenarios

## Pre-Requisites

1. Configure Namespace

    ```bash
    ## set namespace
    LLM_TESTING_NAMESPACE=llm

    ## create namespace
    kubectl create ns ${LLM_TESTING_NAMESPACE}
    ```

2. Configure Hugging-face secret

    ```bash
    ## configure hugging face API token
    export HUGGING_FACE_HUB_TOKEN=<TOKEN>

    ## configure secret
    kubectl create secret generic hf-secret \
        --from-literal=hf_api_token=${HUGGING_FACE_HUB_TOKEN} \
        --dry-run=client -o yaml -n ${LLM_TESTING_NAMESPACE} | kubectl apply -f -
    ```

3. Create PVC and PV

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

## Deploy Multi-GPU/Multi-Node Distributed Inferencing with LWS/vLLM/Ray (Tensor & Pipeline Parallelization)

```bash
## 1. install lws operator
VERSION=v0.4.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml

## 2. deploy lws for target model. Examples:
kubectl apply -k inference/lws/mixtral-8x7b-instruct

kubectl apply -k inference/lws/meta-llama-3-8b-instruct

kubectl apply -k inference/lws/meta-llama-3-70b-instruct

## 3. validate
kubectl get lws,ingress,svc,po,pvc -n llm

## 4. cleanup as needed. Examples:
kubectl delete -k inference/lws/mixtral-8x7b-instruct
kubectl delete -k inference/lws/meta-llama-3-8b-instruct
kubectl delete -k inference/lws/meta-llama-3-70b-instruct

### 5. smoke test LLM endpoint
curl https://llm.vllm.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistralai/Mixtral-8x7B-Instruct-v0.1",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
  }'

## chatbot app
https://gradio.lws.nkp.cloudnative.nvdlab.net/

## ray dashboard (embedded with grafana dashboards)
https://ray.lws.nkp.cloudnative.nvdlab.net/dashboard/#/overview

## public - view only grafana dashboards

## Ray
https://grafana.lws.nkp.cloudnative.nvdlab.net/dkp/grafana/d/rayDefaultDashboard/ray-core-dashboard?orgId=1

## vllm
https://grafana.lws.nkp.cloudnative.nvdlab.net/dkp/grafana/d/b281712d-8bff-41ef-9f3f-71ad43c05e9b/vllm?orgId=1

## DCGGM 
https://grafana.lws.nkp.cloudnative.nvdlab.net/dkp/grafana/d/Oxed_c6Wz/platform-apps-nvidia-dcgm-exporter?orgId=1

```

## Deploy Single-Node/Multi-GPU using vLLM (Tensor Parallelization)

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

```bash

## deploy base
kubectl apply -k inference/vllm/base

## deploy specific
kubectl apply -k inference/vllm/overlays/meta-llama/Meta-Llama-3-70B-Instruct

## cleanup
kubectl delete -k inference/vllm/overlays/meta-llama/Meta-Llama-3-70B-Instruct

```

## Benchmarking using NVIDIA GenAI-Perf

https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/client/src/c%2B%2B/perf_analyzer/genai-perf/README.html

```bash
export RELEASE="24.06" # recommend using latest releases in yy.mm format

## easier to run from docker then install via pip
docker run --cpus 8 -it --net=host -v `pwd`:/workdir -w '/workdir' nvcr.io/nvidia/tritonserver:${RELEASE}-py3-sdk

docker run --rm -it --net=host -v `pwd`:/workdir -w '/workdir' nvcr.io/nvidia/tritonserver:${RELEASE}-py3-sdk

## set HF_TOKEN and Login
export HF_HUB_TOKEN=<>
huggingface-cli login --token ${HF_HUB_TOKEN}

## set OPENAI_API_KEY and NAI endpoint URL
export OPENAI_API_KEY=<>
export URL=https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api

####### ONLY SET ONE OF THESE USE CASES
## Defaults
export SYSTEM_PROMPT_SEQUENCE_LENGTH=10

## test use case 1 - chat q&a (small input/output - 3k requests)
export INPUT_SEQUENCE_LENGTH=128
export INPUT_SEQUENCE_STD=0
export OUTPUT_SEQUENCE_LENGTH=128
export OUTPUT_SEQUENCE_STD=0
export NUMBER_OF_PROMPTS=3000
export CONCURRENCY=100

####### ONLY SET ONE OF THESE MAX_TOKENS VALUES based on NAI ENDPOINT & Model Deployed
## modify MAX_TOKENS based on GPU_COUNT and MODEL. Effectively trying to validate throughput based on dynamic batching provided by vLLM

### 1x GPU (L40S) x1 Replica (VM)
### Examples: meta-llama/Meta-Llama-3-8B-Instruct
## MODEL value should match name in NAI endpoint
export MODEL=llama-3-8b-instruct
export GPU_MODEL=L40S
export GPU_COUNT=1
export REPLICA_COUNT=1
export MAX_TOKENS=8192

###############
## Calculate actual max tokens available after system and input prompt tokens are accounted for...

export MAX_TOKENS=$((MAX_TOKENS - SYSTEM_PROMPT_SEQUENCE_LENGTH - INPUT_SEQUENCE_LENGTH))

###############
## Setup Profile Name used for Generated Benchmark Results
export PROFILE_NAME="${MODEL}_${GPU_MODEL}x${GPU_COUNT}x${REPLICA_COUNT}_${MAX_TOKENS}_${INPUT_SEQUENCE_LENGTH}_${OUTPUT_SEQUENCE_LENGTH}_${NUMBER_OF_PROMPTS}_profile_export.json"

### Example: This will ensure you can keep track of results based on Model and Test Config. i.e., llama-3-70b-instruct_L40Sx4x1_8054_128_128_1_profile_export.json

echo $PROFILE_NAME

## validate connectivity before test
curl -v -k -X 'POST' ${URL}/v1/chat/completions \
 -H "Authorization: Bearer ${OPENAI_API_KEY}" \
 -H 'accept: application/json' \
 -H 'Content-Type: application/json' \
 -d "{
      \"model\": \"$MODEL\",
      \"messages\": [
        {
            \"role\": \"system\",
            \"content\": \"You are a helpful assistant.\"
        },
        {
          \"role\": \"user\",
          \"content\": \"Explain Deep Neural Networks in simple terms\"
        }
      ],
      \"max_tokens\": $MAX_TOKENS,
      \"stream\": false
}"

## Run test
genai-perf \
    -m $MODEL \
    --service-kind openai \
    --endpoint v1/chat/completions \
    --endpoint-type chat \
    --streaming \
    --backend vllm \
    --profile-export-file $PROFILE_NAME \
    --url $URL \
    --synthetic-input-tokens-mean $INPUT_SEQUENCE_LENGTH \
    --synthetic-input-tokens-stddev $INPUT_SEQUENCE_STD \
    --concurrency $CONCURRENCY \
    --num-prompts $NUMBER_OF_PROMPTS \
    --random-seed 123 \
    --output-tokens-mean $OUTPUT_SEQUENCE_LENGTH \
    --output-tokens-stddev $OUTPUT_SEQUENCE_STD \
    --artifact-dir genai-perf-results \
    --tokenizer "hf-internal-testing/llama-tokenizer" \
    --extra-inputs max_tokens:$MAX_TOKENS \
    --generate-plots \
    --measurement-interval 100000 \
    -v \
    -- \
    -H "Authorization: Bearer $OPENAI_API_KEY"  
```

### Genai-Perf - Benchmarking Multiple Use Cases

`sh benchmarks/genai-perf-benchmark.sh`

### Genai-Perf - Generate comparisons using Gen-AI

```
cd genai-perf-results/

## Example: Generate Text-Classification Comparison Plots 
TEXT_CLASSIFICATION_FILES=$(ls *128_128*export.json | xargs echo)
genai-perf compare --file $TEXT_CLASSIFICATION_FILES
mv compare/ text-classification-compare/

QUESTION_ANSWERING_FILES=$(ls *128_2048*export.json | xargs echo)
genai-perf compare --file $QUESTION_ANSWERING_FILES
mv compare/ question-answering-compare/

TEXT_GENERATION_FILES=$(ls *128_4096*export.json | xargs echo)
genai-perf compare --file $TEXT_GENERATION_FILES
mv compare/ text-generation-compare/

TEXT_SUMMARIZATION_FILES=$(ls *2048_128*export.json | xargs echo)
genai-perf compare --file $TEXT_SUMMARIZATION_FILES
mv compare/ text-summarization-compare/

CODE_GENERATION_FILES=$(ls *2048_2048*export.json | xargs echo)
genai-perf compare --file $CODE_GENERATION_FILES
mv compare/ code-generation-compare/
```

### Benchmarking using vLLM Project

```bash
## git clone vllm https://github.com/vllm-project/vllm repo into benchmarks dir
git clone https://github.com/vllm-project/vllm benchmarks/vllm

## install python pre-requisites into pip env if needed. i.e., 
source ~/.venv/bin/activate
python3 -m pip install -r benchmarks/vllm/requirements-cuda.txt

## login to HF
export HF_HUB_TOKEN=<>
huggingface-cli login --token ${HF_HUB_TOKEN}

## standalone testing
export OPENAI_API_KEY=<>
export URL=https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api

export TOKENIZERS_PARALLELISM=false && \
python3 benchmarks/vllm/benchmarks/benchmark_serving.py \
  --backend openai-chat \
  --base-url=$URL \
  --endpoint='/v1/chat/completions' \
  --model llama-3-70b-instruct \
  --tokenizer "meta-llama/Meta-Llama-3-70B-Instruct" \
  --dataset-name sharegpt \
  --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json \
  --num-prompts 20 \
  --result-dir vllm-benchmark-results/ \
  --result-filename llama-3-70b-instruct_tp1_qps_2.json \
  --request-rate 1 \
  --percentile-metrics "ttft,tpot,itl,e2el" \
  --metric-percentiles "50,95,99" \
  --sharegpt-output-len 128 \
  --disable-tqdm \
  --save-result \
  2>&1 | tee vllm-benchmark-results/llama-3-70b-instruct_tp1_qps_2_results.txt
```

## vLLM Benchmarks - Looping through Multiple Use Cases

```bash
## running vllm benchmark
source ~/.venv/bin/activate

## login to HF
export HF_HUB_TOKEN=<>
huggingface-cli login --token ${HF_HUB_TOKEN}

## OPENAI_API_KEY=ANYTHING ./benchmarks/vllm-benchmark.sh URL MODEL TOKENIZER GPU_MODEL GPU_COUNT REPLICA_COUNT

## NAI EXAMPLE
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api llama-3-70b-instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## vllm EXAMPLE
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.vllm.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## lws EXAMPLE - 4 GPU x 1 VM
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.lws.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

## lws EXAMPLE - 4 GPU x 2 VM
OPENAI_API_KEY=<> ./benchmarks/vllm-perf-benchmarks.sh https://llm.lws.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-70B-Instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 2

```

## Troubleshooting

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

### LLama3-70b Testing of NAI Endpoint

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

## Other Scenarios

### Testing with Kuberay Clusters/Service

1. Requires Hugging-face secret

```bash
## create namespace
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

### Kuberay - Deploy Model Specific RayService

`kubectl apply -f inference/kuberay/mixtral-8x7b-instruct/ray-service.yaml -n ${KUBERAY_TESTING_NAMESPACE}`

### Kuberay - Troubleshooting

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