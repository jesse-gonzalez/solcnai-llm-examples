FROM docker.io/vllm/vllm-openai:v0.5.3.post1

RUN pip install ray[default]

COPY ray_init.sh /vllm-workspace/ray_init.sh
