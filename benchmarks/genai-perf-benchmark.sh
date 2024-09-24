declare -A useCases

# Populate the array with use case descriptions and their specified input/output lengths
useCases["Text Classifiction"]="128/128/30000"
useCases["Question Answering"]="128/2048/300"
useCases["Text Generation"]="128/4096/1500"
useCases["Text Summarization"]="2048/128/300"
useCases["Code Generation"]="2048/2048/1500"

# Function to execute genAI-perf with the input/output lengths as arguments
runBenchmark() {
    local description="$1"
    local lengths="${useCases[$description]}"
    IFS='/' read -r inputLength outputLength numberOfPrompts <<< "$lengths"

    echo "Running genAI-perf for $description use case with input length:$inputLengt output length:$outputLength and number of prompts:$numberOfPrompts"

    local HF_HUB_TOKEN=<> # Add your Hugging Face API token here
    huggingface-cli login --token ${HF_HUB_TOKEN}

    #Runs
    for concurrency in 1 2 5 10 50 100 250; do

        ## constants
        local URL=https://nai.cnai.nai-nkp-mgx.odin.cloudnative.nvdlab.net/api
        local SYSTEM_PROMPT_SEQUENCE_LENGTH=10
        local INPUT_SEQUENCE_LENGTH=$inputLength
        local INPUT_SEQUENCE_STD=0
        local OUTPUT_SEQUENCE_LENGTH=$outputLength
        local CONCURRENCY=$concurrency
        local NUMBER_OF_PROMPTS=$numberOfPrompts

        ## model specific
        local MODEL=llama-3-70b-instruct
        local GPU_MODEL=L40S
        local GPU_COUNT=4
        local REPLICA_COUNT=1
        local MAX_TOKENS=8192

        ## derived
        local MAX_TOKENS=$((MAX_TOKENS - SYSTEM_PROMPT_SEQUENCE_LENGTH - INPUT_SEQUENCE_LENGTH))
        local MODEL_NAME=$(echo $MODEL | cut -d/ -f2 | tr '[:upper:]' '[:lower:]')
        local PROFILE_NAME="${MODEL}_${GPU_MODEL}x${GPU_COUNT}x${REPLICA_COUNT}_${MAX_TOKENS}_${INPUT_SEQUENCE_LENGTH}_${OUTPUT_SEQUENCE_LENGTH}_${NUMBER_OF_PROMPTS}_${CONCURRENCY}_profile_export.json"

        echo $PROFILE_NAME

        local OUTPUT_SEQUENCE_STD=0  # Define OUTPUT_SEQUENCE_STD
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
            --measurement-interval 40000 \
            -v \
            -- \
            -H "Authorization: Bearer $NAI_OPENAI_API_KEY"

    done
}

# Iterate over all defined use cases and run the benchmark script for each
for description in "${!useCases[@]}"; do
    runBenchmark "$description"
done