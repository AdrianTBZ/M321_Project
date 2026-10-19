FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY flow.sh .
RUN chmod +x flow.sh
CMD ["bash", "flow.sh"]
