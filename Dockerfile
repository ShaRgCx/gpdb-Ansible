FROM ubuntu:22.04 AS download
ARG URI
RUN apt update > /dev/null && \
    apt install curl tar -y > /dev/null && \
    mkdir -pv /distr/dst
RUN curl -L -o /distr/core.tar ${URI} && \
    tar -xf /distr/core.tar -C /distr/dst && \
    rm -r /distr/dst/ansible_env /distr/dst/collections && \
    sed -i "s|ansible_env/bin/||g" /distr/dst/install.bash

FROM python:3-slim
WORKDIR /gbgp
COPY --from=download /distr/dst /gbgp
RUN apt update && apt install ssh -y && apt-get clean && \
    pip install --upgrade pip && \
    pip3 install -r requirements.txt && \
    ansible-galaxy collection install -r requirements.yml
ENTRYPOINT [ "/gbgp/install.bash" ]
