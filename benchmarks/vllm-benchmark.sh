source ~/.venv/bin/activate
python -m pip install -r benchmarks/vllm/requirements-cuda.txt
python benchmarks/vllm/benchmarks/benchmark_serving.py \
  --base-url $1 \
  --model $2 \
  --backend openai-chat \
  --endpoint /v1/chat/completions \
  --dataset-name sharegpt \
  --dataset-path benchmarks/ShareGPT_V3_unfiltered_cleaned_split.json \
  --num-prompts $3 \
  --request-rate $4

#### Examples

## OPENAI_API_KEY=ANYTHING sh benchmarks/vllm-benchmark.sh https://mixtral.vllm.nkp.cloudnative.nvdlab.net mistralai/Mixtral-8x7B-Instruct-v0.1 1 2000