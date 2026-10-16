FROM haskell:9.6.7-slim
RUN apt-get update && apt-get install -y --no-install-recommends default-mysql-client \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY . .
RUN bash scripts/build.sh
CMD [".build/lab3-run", "lab3/examples/textbook.txt"]
