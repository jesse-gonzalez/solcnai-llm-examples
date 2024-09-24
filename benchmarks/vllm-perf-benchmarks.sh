#!/usr/bin/env bash

# source ~/.venv/bin/activate
# python -m pip install -r benchmarks/vllm/requirements-cuda.txt

set -ex
set -o pipefail

declare -A useCases

## model specific
URL=$1
MODEL=$2
TOKENIZER=$3
GPU_MODEL=$4
GPU_COUNT=$5
REPLICA_COUNT=$6

TOKENIZERS_PARALLELISM=false

# Populate the array with Natural Language use case descriptions and their specified input/output lengths
useCases["Text Classification"]="128/128/400"
useCases["Question Answering"]="128/2048/250"
useCases["Text Generation"]="128/4096/200"
useCases["Text Summarization"]="2048/128/100"
useCases["Document Analysis"]="2048/2048/50"

# Function to execute vllm-perf-benchmark with the input/output lengths as arguments
runBenchmark() {
    local currentDate=$(date +"%Y%m%d-%H%M%S")
    local description="$1"
    local lengths="${useCases[$description]}"
    IFS='/' read -r inputSequenceLength outputSequenceLength numberOfPrompts <<< "$lengths"

    echo "INFO: $currentDate: Running vllm-perf-benchmark for $description use case with input length:$inputSequenceLength output length:$outputSequenceLength and number of prompts:$numberOfPrompts"
    
    # Concurrency is same as request rate / queries per second
    for concurrency in 1 2 4; do

        ## derived
        local cluster=$(echo $URL | cut -d/ -f3 | cut -d. -f1-3 | sed 's/http:\/\///; s/https:\/\///')
        local useCase=$(echo $description | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

        local modelName=$(echo $MODEL | cut -d/ -f2 | tr '[:upper:]' '[:lower:]')
        local resultsFileName="${modelName}_${useCase}_tp${GPU_COUNT}_pp${REPLICA_COUNT}_qps_${concurrency}_${currentDate}_results.json"

        ## Check if the benchmark results directory exists, if not create it
        local resultsDir="vllm-benchmark-results/${cluster}/${modelName}/${useCase}/${currentDate}"
        if [ ! -d "${resultsDir}" ]; then
            mkdir -p ${resultsDir}
        fi

        ## Run the benchmark script
        python3 benchmarks/vllm/benchmarks/benchmark_serving.py \
            --model $MODEL \
            --base-url $URL \
            --tokenizer $TOKENIZER \
            --backend openai-chat \
            --endpoint '/v1/chat/completions' \
            --dataset-name random \
            --random-input-len $inputSequenceLength \
            --random-output-len $outputSequenceLength \
            --seed 0 \
            --num-prompts $numberOfPrompts \
            --result-dir $resultsDir \
            --result-filename $resultsFileName \
            --request-rate $concurrency \
            --logprobs 1 \
            --percentile-metrics "ttft,tpot,itl,e2el" \
            --metric-percentiles "99,95,90,75,50,25" \
            --metadata config:cluster=$cluster \
                       config:url=$URL \
                       config:serving-model-name=$MODEL \
                       config:tokenizer=$TOKENIZER \
                       config:gpu-model=$GPU_MODEL \
                       config:tensor-parallel-size=$GPU_COUNT \
                       config:pipeline-parallel-size=$REPLICA_COUNT \
                       config:endpoint-replicas=$REPLICA_COUNT \
                       config:vllm-version=v0.6.1.post2 \
                       use-case:type=$useCase \
                       use-case:isl=$inputSequenceLength \
                       use-case:osl=$outputSequenceLength \
                       use-case:num-of-prompts=$numberOfPrompts \
            --save-result \
            --trust-remote-code \
            2>&1 | tee ${resultsDir}/${resultsFileName}_results.txt

            #--dataset-name random \
            #--dataset-name Open-Orca/OpenOrca \
            #--dataset-name sharegpt \
            #--dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json \
            #--sharegpt-output-len $outputSequenceLength \
            ## --disable-tqdm \

    done
}

# Iterate over all defined use cases and run the benchmark script for each
for description in "${!useCases[@]}"; do
    runBenchmark "$description"
done


#### Examples

## OPENAI_API_KEY=ANYTHING ./benchmarks/vllm-benchmark.sh URL MODEL TOKENIZER GPU_MODEL GPU_COUNT REPLICA_COUNT

## OPENAI_API_KEY=ANYTHING ./benchmarks/vllm-benchmark.sh https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api llama-3-70b-instruct meta-llama/Meta-Llama-3-70B-Instruct L40S 4 1

