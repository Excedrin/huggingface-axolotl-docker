# latest is
#ARG CUDA_VERSION="12.4.1"
ARG CUDA_VERSION="11.8.0"
ARG CUDNN_VERSION="8"
ARG UBUNTU_VERSION="22.04"

FROM nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-devel-ubuntu$UBUNTU_VERSION

ARG MAX_JOBS=8
ARG AXOLOTL_EXTRAS=""
ARG AXOLOTL_ARGS=""
ARG CUDA="118"
#ARG CUDA="121"
ARG TORCH_CUDA_ARCH_LIST="7.0 7.5 8.0 8.6 9.0+PTX"
ARG PYTHON_VERSION="3.10"
ARG PYTHON_SHORT="310"

ENV DEBIAN_FRONTEND=noninteractive \
	TZ=Europe/Paris

# Remove any third-party apt sources to avoid issues with expiring keys.
# Install some basic utilities
RUN rm -f /etc/apt/sources.list.d/*.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    git \
    git-lfs \
    htop \
    less \
    libaio-dev \
    libnccl2 \
    libnccl-dev \
    libsndfile-dev \
    libx11-6 \
    nano \
    ninja-build \
    rsync \
    s3fs \
    software-properties-common \
    sudo \
    tmux \
    unzip \
    vim \
    wget \
    zip

RUN add-apt-repository ppa:flexiondotorg/nvtop && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends nvtop

RUN curl -sL https://deb.nodesource.com/setup_22.x  | bash - && \
    apt-get install -y nodejs && \
    npm install -g configurable-http-proxy

RUN rm -rf /var/lib/apt/lists/*

# User Debian packages
## Security warning : Potential user code executed as root (build time)
RUN --mount=target=/root/packages.txt,source=packages.txt \
    apt-get update && \
    xargs -r -a /root/packages.txt apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=target=/root/on_startup.sh,source=on_startup.sh,readwrite \
	bash /root/on_startup.sh

# Create a non-root user and switch to it
RUN adduser --disabled-password --gecos '' --shell /bin/bash user

RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user

RUN mkdir /data && chown user:user /data

###########
# Axolotl base
#

USER user

# All users can use /home/user as their home directory
ENV HOME=/home/user
RUN mkdir $HOME/.cache $HOME/.config \
 && chmod -R 777 $HOME

WORKDIR $HOME/app

# Set up the Conda environment
ENV PYTHON_VERSION=$PYTHON_VERSION
ENV TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST

ENV CONDA_AUTO_UPDATE_CONDA=false \
    PATH=$HOME/miniconda/bin:$PATH

RUN curl -sLo ~/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
  && chmod +x ~/miniconda.sh \
  && ~/miniconda.sh -b -p ~/miniconda \
  && rm ~/miniconda.sh \
  && conda clean -ya \
  && conda create -n "py${PYTHON_VERSION}" python="${PYTHON_VERSION}"

ENV PATH="$HOME/miniconda/envs/py${PYTHON_VERSION}/bin:$PATH"

# From here forward Python for 'user' is the miniconda version.

#ARG PYTORCH_VERSION="2.1.2+cu${CUDA}"
#ARG TORCHVISION_VERSION="0.16.2+cu${CUDA}"
#ARG TORCHAUDIO_VERSION="2.1.2+cu${CUDA}"

ARG PYTORCH_VERSION="2.3.0+cu${CUDA}"
ARG TORCHVISION_VERSION="0.18.0+cu${CUDA}"
ARG TORCHAUDIO_VERSION="2.3.0+cu${CUDA}"

ENV PYTORCH_VERSION=$PYTORCH_VERSION

RUN python3 -m pip install --upgrade pip && pip3 install packaging && \
    python3 -m pip install --no-cache-dir -U torch==${PYTORCH_VERSION} torchvision==${TORCHVISION_VERSION} torchaudio==${TORCHAUDIO_VERSION} --index-url https://download.pytorch.org/whl/cu$CUDA/

RUN git lfs install --skip-repo && \
    pip3 install awscli && \
    pip3 install -U --no-cache-dir pydantic==1.10.15
    # The base image ships with `pydantic==1.8.2` which is not working, 1.10.15 is the last 1x version.

###########
# Axolotl

ENV BNB_CUDA_VERSION=$CUDA

WORKDIR /workspace

RUN git clone --depth=1 https://github.com/OpenAccess-AI-Collective/axolotl.git

WORKDIR /workspace/axolotl

RUN pip3 install --only-binary :all: galore scikit-learn ninja psutil scipy

# If AXOLOTL_EXTRAS is set, append it in brackets
RUN pip install causal_conv1d

ENV MAX_JOBS=$MAX_JOBS

# scikit-learn has 1.5.0 available, requirements.txt specifies 1.2.2, which doesn't have a wheel

RUN sed -i 's/scikit-learn==.*/scikit-learn/' requirements.txt

RUN mkdir wheels && cd wheels && \
    curl -LO https://github.com/Dao-AILab/flash-attention/releases/download/v2.5.8/flash_attn-2.5.8+cu${CUDA}torch2.1cxx11abiFALSE-cp${PYTHON_SHORT}-cp${PYTHON_SHORT}-linux_x86_64.whl && \
    pip install -f . flash_attn

RUN if [ "$AXOLOTL_EXTRAS" != "" ] ; then \
        pip install -e .[deepspeed,flash-attn,mamba-ssm,galore,$AXOLOTL_EXTRAS] $AXOLOTL_ARGS; \
    else \
        pip install -e .[deepspeed,flash-attn,mamba-ssm,galore] $AXOLOTL_ARGS; \
    fi

# So we can test the Docker image
RUN pip install pytest

# fix so that git fetch/pull from remote works
RUN git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && \
    git config --get remote.origin.fetch

# helper for huggingface-login cli
RUN git config --global credential.helper store

###########
# Huggingface Jupyter setup

# Python packages
RUN --mount=target=requirements.txt,source=requirements.txt \
    pip install --no-cache-dir --upgrade -r requirements.txt

# Copy the current directory contents into the container at $HOME/app setting the owner to the user
COPY --chown=user . $HOME/app

WORKDIR $HOME/app

RUN chmod +x start_server.sh

COPY --chown=user login.html /home/user/miniconda/lib/python3.9/site-packages/jupyter_server/templates/login.html

ENV PYTHONUNBUFFERED=1 \
	GRADIO_ALLOW_FLAGGING=never \
	GRADIO_NUM_PORTS=1 \
	GRADIO_SERVER_NAME=0.0.0.0 \
	GRADIO_THEME=huggingface \
	SYSTEM=spaces \
	SHELL=/bin/bash

CMD ["./start_server.sh"]
