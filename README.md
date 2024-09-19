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

#VERSION=v0.3.0
VERSION=v0.4.0
kubectl apply --server-side -f https://github.com/kubernetes-sigs/lws/releases/download/$VERSION/manifests.yaml

## deploy lws for target model
kubectl apply -k inference/vllm/lws/mixtral-8x7b-instruct
#kubectl apply -k inference/vllm/lws/meta-llama-3-8b-instruct

```

```bash
## Cleanup Using kustomize
kubectl delete -k inference/vllm/lws/mixtral-8x7b-instruct
#kubectl delete -k inference/vllm/lws/meta-llama-3-8b-instruct
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

curl https://llm.vllm.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistralai/Mixtral-8x7B-Instruct-v0.1",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
  }'

## benchmarking with lws / ray num-prompts for mistralai/Mixtral-8x7B-Instruct-v0.1 
OPENAI_API_KEY=ANYTHING sh benchmarks/vllm-benchmark.sh https://llm.vllm.nkp.cloudnative.nvdlab.net mistralai/Mixtral-8x7B-Instruct-v0.1 1000 1

## meta-llama/Meta-Llama-3-8B-Instruct test
curl https://llm.vllm.nkp.cloudnative.nvdlab.net/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "meta-llama/Meta-Llama-3-8B-Instruct",
      "prompt": "San Francisco is a",
      "max_tokens": 7,
      "temperature": 0
  }'

## benchmarking with lws / ray num-prompts for meta-llama/Meta-Llama-3-8B-Instruct  
OPENAI_API_KEY=ANYTHING sh benchmarks/vllm-benchmark.sh https://llm.vllm.nkp.cloudnative.nvdlab.net meta-llama/Meta-Llama-3-8B-Instruct 100 10
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

## Test using GenAI-Perf

https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/client/src/c%2B%2B/perf_analyzer/genai-perf/README.html

```bash
export RELEASE="24.08" # recommend using latest releases in yy.mm format

docker run --rm -it --net=host -v `pwd`:/workdir -w '/workdir' nvcr.io/nvidia/tritonserver:${RELEASE}-py3-sdk

# --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json \
export URL=https://llm.vllm.nkp.cloudnative.nvdlab.net
export MODEL=mistralai/Mixtral-8x7B-Instruct-v0.1
export INPUT_SEQUENCE_LENGTH=128
export INPUT_SEQUENCE_STD=0
export OUTPUT_SEQUENCE_LENGTH=128
export OUTPUT_SEQUENCE_STD=0
export NUMBER_OF_PROMPTS=3000
export CONCURRENCY=10
export MAX_TOKENS=3072

export MODEL_NAME=$(echo $MODEL | cut -d/ -f2 | tr '[:upper:]' '[:lower:]')
export PROFILE_NAME="${MODEL_NAME}_${INPUT_SEQUENCE_LENGTH}_${OUTPUT_SEQUENCE_LENGTH}_${NUMBER_OF_PROMPTS}_profile_export.json"

genai-perf profile \
    -m $MODEL \
    --service-kind openai \
    --endpoint v1/chat/completions \
    --endpoint-type chat \
    --backend vllm \
    --streaming \
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
    --extra-inputs min_tokens:$OUTPUT_SEQUENCE_LENGTH \
    --extra-inputs max_tokens:$MAX_TOKENS \
    --extra-inputs ignore_eos:true \
    --generate-plots \
    -v
```

export OPENAI_API_KEY=1e4267ba-b12a-4b9d-90d6-d1cf1a26aeb2
guidellm \
  --backend openai_server \
  --target "https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api/v1/chat/completions" \
  --model "llama-3-70b-instruct" \
  --data-type emulated \
  --output-path benchmarks\guidellm \
  --data "prompt_tokens=512,generated_tokens=128"


GUIDELLM__ENV="Environment.PROD"
GUIDELLM__REQUEST_TIMEOUT="30"
GUIDELLM__MAX_CONCURRENCY="512"
GUIDELLM__NUM_SWEEP_PROFILES="9"
GUIDELLM__LOGGING__DISABLED=
GUIDELLM__LOGGING__CLEAR_LOGGERS="True"
GUIDELLM__LOGGING__CONSOLE_LOG_LEVEL="WARNING"
GUIDELLM__LOGGING__LOG_FILE=
GUIDELLM__LOGGING__LOG_FILE_LEVEL=
GUIDELLM__DATASET__PREFERRED_DATA_COLUMNS=["prompt","instruction","input","inputs","question","context","text","content","body","data"]
GUIDELLM__DATASET__PREFERRED_DATA_SPLITS=["test","tst","validation","val","train"]
GUIDELLM__EMULATED_DATA__SOURCE="https://www.gutenberg.org/files/1342/1342-0.txt"
GUIDELLM__EMULATED_DATA__FILTER_START="It is a truth universally acknowledged, that a"
GUIDELLM__EMULATED_DATA__FILTER_END="CHISWICK PRESS:--CHARLES WHITTINGHAM AND CO."
GUIDELLM__EMULATED_DATA__CLEAN_TEXT_ARGS={"fix_encoding": true, "clean_whitespace": true, "remove_empty_lines": true, "force_new_line_punctuation": true}
GUIDELLM__OPENAI__API_KEY="invalid_token"
GUIDELLM__OPENAI__BASE_URL="http://localhost:8000/v1"
GUIDELLM__OPENAI__MAX_GEN_TOKENS="4096"
GUIDELLM__REPORT_GENERATION__SOURCE="https://guidellm.neuralmagic.com/local-report/index.html"
GUIDELLM__REPORT_GENERATION__REPORT_HTML_MATCH="window.report_data = {};"
GUIDELLM__REPORT_GENERATION__REPORT_HTML_PLACEHOLDER="{}"

```bash
export RELEASE="24.06" # recommend using latest releases in yy.mm format

docker run -it --net=host -v `pwd`:/workdir -w '/workdir' nvcr.io/nvidia/tritonserver:${RELEASE}-py3-sdk

# --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json \
export URL=https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api
export MODEL=llama-3-70b-instruct
export INPUT_SEQUENCE_LENGTH=128
export INPUT_SEQUENCE_STD=0
export OUTPUT_SEQUENCE_LENGTH=128
export OUTPUT_SEQUENCE_STD=0
export NUMBER_OF_PROMPTS=3000
export CONCURRENCY=10
export MAX_TOKENS=3072

export MODEL_NAME=$(echo $MODEL | cut -d/ -f2 | tr '[:upper:]' '[:lower:]')
export PROFILE_NAME="${MODEL_NAME}_${INPUT_SEQUENCE_LENGTH}_${OUTPUT_SEQUENCE_LENGTH}_${NUMBER_OF_PROMPTS}_profile_export.json"

export HF_HUB_TOKEN=<>
export OPENAI_API_KEY=<>

genai-perf profile \
    -m $MODEL \
    --service-kind openai \
    --endpoint v1/chat/completions \
    --endpoint-type chat \
    --backend vllm \
    --streaming \
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
    --extra-inputs max_tokens:$MAX_TOKENS \
    --generate-plots \
    --tokenizer "meta-llama/Meta-Llama-3-70B-Instruct" \
    -v \
    -- \
    -H "Authorization: Bearer $OPENAI_API_KEY"
```



`sh benchmarks/genai-perf-benchmark.sh`

## generate comparisons

```
cd genai-perf-results/
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

### vllm benchmarks

https://buildkite.com/vllm/performance-benchmark/builds/4068#01908bf6-e6e6-4f38-a050-703cd08998dd

```bash
Input length: randomly sample 500 prompts from ShareGPT dataset (with fixed random seed).
Output length: the corresponding output length of these 500 prompts.
Models: llama-3 8B, llama-3 70B, mixtral 8x7B.
Average QPS (query per second): 4 for the small model (llama-3 8B) and 2 for other two models. For each QPS, the arrival time of each query is determined using a random Poisson process (with fixed random seed).
Evaluation metrics: Throughput (higher the better), TTFT (time to the first token, lower the better), ITL (inter-token latency, lower the better).
```

```bash

export NAI_OPENAI_API_KEY=1e4267ba-b12a-4b9d-90d6-d1cf1a26aeb2

host='localhost', port=8000, endpoint='/v1/completions'

export TOKENIZERS_PARALLELISM=false
export OPENAI_API_KEY="1e4267ba-b12a-4b9d-90d6-d1cf1a26aeb2"
export URL=https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api
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

source ~/.venv/bin/activate
export OPENAI_API_KEY=1e4267ba-b12a-4b9d-90d6-d1cf1a26aeb2 && \
export TOKENIZERS_PARALLELISM=false && \
./benchmarks/vllm-perf-benchmarks.sh

## extract info from each report
echo "### Serving Benchmarks" >> vllm-benchmark-results/benchmark_results.md
sed -n '5p' vllm-benchmark-results/llama-3-70b-instruct_L40Sx4x1_6134_2048_128_3_qps_1_profile_export.json_results.txt >> vllm-benchmark-results/benchmark_results.md # first line
echo "" >> vllm-benchmark-results/benchmark_results.md
echo '```' >> vllm-benchmark-results/benchmark_results.md
tail -n 33 vllm-benchmark-results/llama-3-70b-instruct_L40Sx4x1_6134_2048_128_3_qps_1_profile_export.json_results.txt >> vllm-benchmark-results/benchmark_results.md # last 35 lines
echo '```' >> vllm-benchmark-results/benchmark_results.md

# Parse and convert to CSV

awk '
BEGIN {
    FS=":";
    OFS=","
    print "Metric,Value"
}
{
    if (NF == 2) {
        gsub(/^[ \t]+|[ \t]+$/, "", $1);
        gsub(/^[ \t]+|[ \t]+$/, "", $2);
        print $1, $2
    }
}
' vllm-benchmark-results/benchmark_results.md

```



```

# Get the current date in YYYY-MM-DD format
current_date=$(date +%Y-%m-%d)

# Define the output CSV and Markdown files with the date appended
output_csv="vllm-benchmark-results/benchmark_results_${current_date}.csv"
output_markdown="vllm-benchmark-results/benchmark_results_${current_date}.md"

# Example filename
filename="llama-3-70b-instruct_L40Sx4x1_6134_2048_128_3_qps_1_profile_export.json_results.txt"

# Remove the extension
filename_no_ext="${filename%.*}"

# Split the filename by underscores
IFS='_' read -r MODEL GPU_MODEL GPU_COUNT REPLICA_COUNT MAX_TOKENS INPUT_SEQUENCE_LENGTH OUTPUT_SEQUENCE_LENGTH NUMBER_OF_PROMPTS QPS CONCURRENCY <<< "${filename_no_ext}"

# Print the variables in the desired format
echo "${MODEL}_${GPU_MODEL}x${GPU_COUNT}x${REPLICA_COUNT}_${MAX_TOKENS}_${INPUT_SEQUENCE_LENGTH}_${OUTPUT_SEQUENCE_LENGTH}_${NUMBER_OF_PROMPTS}_qps_${CONCURRENCY}"

# Initialize the CSV file with headers
echo "Metric,Value,File" >| $output_csv

# Loop through all relevant files in the vllm-benchmark folder
for file in vllm-benchmark-results/*.txt; do
    echo "### Serving Benchmarks" >> $output_markdown
    sed -n '5p' $file >> $output_markdown # first line
    echo "" >> $output_markdown
    echo '```' >> $output_markdown
    tail -n 33 $file >> $output_markdown # last 35 lines
    echo '```' >> $output_markdown

    tail -n 33 $file >| $output_csv.temp

    # Parse and append to CSV
    awk -v filename=$(basename "$file") '
    BEGIN {
        FS=":";
        OFS=","
    }
    {
        if (NF == 2) {
            gsub(/^[ \t]+|[ \t]+$/, "", $1);
            gsub(/^[ \t]+|[ \t]+$/, "", $2);
            print $1, $2, filename
        }
    }
    ' $output_csv.temp | tee -a $output_csv
done

rm $output_csv.temp

# Display the CSV content
cat $output_csv



```

