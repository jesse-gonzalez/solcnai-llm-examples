FROM docker.io/vllm/vllm-openai:v0.6.1.post2

RUN pip install ray[default]

COPY ray_init.sh /vllm-workspace/ray_init.sh
