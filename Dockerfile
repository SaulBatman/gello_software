FROM ubuntu:22.04

WORKDIR /gello

# Set environment variables first (less likely to change)
ENV PYTHONPATH=/gello:/gello/third_party/oculus_reader/
ENV CONDA_ENV_NAME=polymetis

# Group apt updates and installs together
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    libpoco-dev \
    libeigen3-dev \
    lsb-release \
    curl \
    dpkg-dev \
    libfmt-dev \
    libhidapi-dev \
    python3-pip \
    android-tools-adb \
    libegl1-mesa-dev \
    wget \
    bzip2 \
    sudo 

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL http://robotpkg.openrobots.org/packages/debian/robotpkg.asc | sudo tee /etc/apt/keyrings/robotpkg.asc
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/robotpkg.asc] http://robotpkg.openrobots.org/packages/debian/pub $(lsb_release -cs) robotpkg" | sudo tee /etc/apt/sources.list.d/robotpkg.list
RUN apt update && apt install -y \
    robotpkg-pinocchio && \
    rm -rf /var/lib/apt/lists/* 
ENV PATH=/opt/openrobots/bin:$PATH \
    PKG_CONFIG_PATH=/opt/openrobots/lib/pkgconfig:$PKG_CONFIG_PATH \
    LD_LIBRARY_PATH=/opt/openrobots/lib:$LD_LIBRARY_PATH \
    PYTHONPATH=/opt/openrobots/lib/python3.10/site-packages:$PYTHONPATH \
    CMAKE_PREFIX_PATH=/opt/openrobots:$CMAKE_PREFIX_PATH

RUN git clone https://github.com/facebookresearch/fairo.git /tmp/fairo
RUN cd /tmp/fairo/polymetis/polymetis/src/clients/franka_panda_client/third_party && \
    rm -r libfranka && \
    git clone https://github.com/frankaemika/libfranka.git && \
    cd libfranka && \
    git checkout 0.14.2 && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_PREFIX_PATH=/opt/openrobots/lib/cmake \
          -DBUILD_TESTS=OFF .. && \
    make && \
    cpack -G DEB && \
    # Since Docker containers run as root, sudo is not required
    dpkg -i libfranka*.deb

SHELL ["/bin/bash", "--login", "-c"]
# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh &&\
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc &&\
    /bin/bash -c "source ~/.bashrc"  && \
    /opt/conda/bin/conda update -n base -c defaults conda -y &&\
    /opt/conda/bin/conda create -n polymetis-local python=3.8
ENV PATH=$PATH:/opt/conda/envs/polymetis-local/bin

RUN conda init bash &&\
    echo "conda activate polymetis-local" >> ~/.bashrc &&\
    /bin/bash -c "source /root/.bashrc"
RUN conda activate polymetis-local && \
    cd /tmp/fairo/polymetis && \
    # Create conda environment from the provided YAML file
    conda env update --file ./polymetis/environment.yml --prune 

RUN conda activate polymetis-local && \
    cd /tmp/fairo/polymetis && \
    sed -i '1i#include <cstddef>' polymetis/torch_isolation/include/torch_server_ops.hpp && \
    pip install -e ./polymetis && \
    # Build Polymetis from source:
    mkdir -p ./polymetis/build && cd ./polymetis/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_FRANKA=ON -DBUILD_TESTS=OFF -DBUILD_DOCS=OFF -DCMAKE_PREFIX_PATH="/opt/conda/envs/polymetis-local/lib/python3.8/site-packages/torch" && \
    make -j

# Python alias setup
RUN echo "alias python=python3" >> ~/.bashrc
RUN echo "source activate polymetis-local" >> ~/.bashrc

WORKDIR /gello

# Install Python dependencies
COPY requirements.txt /gello
RUN conda activate polymetis-local && \
    pip install -r requirements.txt
