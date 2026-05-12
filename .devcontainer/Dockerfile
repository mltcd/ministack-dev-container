# Stage 1: get and install AWS CLI v2
FROM ubuntu:26.04 AS awscli-installer
RUN apt-get update && apt-get install -y curl unzip ca-certificates \
  && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
  && unzip /tmp/awscliv2.zip -d /tmp \
  && /tmp/aws/install \
  && rm -rf /tmp/awscliv2.zip /tmp/aws

# Stage 2: final image with tools + copied AWS CLI
FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /work

RUN apt-get update && apt-get install -y \
    python3 \
    curl zip \
    ca-certificates \
    jq bash-completion sudo \
  && rm -rf /var/lib/apt/lists/*

COPY --from=awscli-installer /usr/local/aws-cli /usr/local/aws-cli
COPY --from=awscli-installer /usr/local/bin/aws /usr/local/bin/aws
COPY --from=awscli-installer /usr/local/bin/aws_completer /usr/local/bin/aws_completer

ARG USERNAME=wojtek
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN userdel -r ubuntu 2>/dev/null || true \
  && groupdel ubuntu 2>/dev/null || true \
  && groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
