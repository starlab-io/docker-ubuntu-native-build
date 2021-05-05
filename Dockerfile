FROM starlabio/ubuntu-base:1.7
MAINTAINER Pete Dietl <pete.dietl@starlab.io>

###############################################################################
# Install Rust Toolchains
###############################################################################

ENV PATH=/usr/local/cargo/bin:$PATH \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/etc/local/cargo/rustup

# install rustup in a globally accessible location
RUN curl https://sh.rustup.rs -sSf > rustup-install.sh && \
    umask 020 && sh ./rustup-install.sh -y --default-toolchain 1.46.0-x86_64-unknown-linux-gnu && \
    rm rustup-install.sh && \
                            \
    # Install rustfmt / cargo fmt for testing
    rustup component add rustfmt

# install the cargo license checker
RUN cargo install cargo-license

# Install AARCH64 Rust
RUN rustup target add aarch64-unknown-linux-gnu
# Install 32-bit ARM Rust
RUN rustup target add arm-unknown-linux-gnueabihf

# Install code coverage tools
RUN rustup component add llvm-tools-preview && \
    cargo install grcov

COPY cargo_config /.cargo/config

# setup fetching arm packages
RUN dpkg --add-architecture arm64 && dpkg --add-architecture armhf

# Ubuntu can't be an adult with their sources list for arm
RUN sed -e 's:deb h:deb [arch=amd64] h:' -e 's:deb-src h:deb-src [arch=amd64] h:' -i /etc/apt/sources.list && \
        find /etc/apt/sources.list.d/ -type f -exec sed -e 's:deb h:deb [arch=amd64] h:' -e 's:deb-src h:deb-src [arch=amd64] h:' -i {} \; && \
        sed -e 's:arch=amd64:arch=armhf,arm64:' -e 's:security:ports:' -e 's://.*archive://ports:' -e 's:/ubuntu::' /etc/apt/sources.list | grep 'ubuntu.com' | grep -v '\-ports' | tee /etc/apt/sources.list.d/arm.list

# package depends
# Please keep this list alphabetized
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
        acpica-tools \
        autoconf-archive \
        bc \
        bcc \
        bin86 \
        checkpolicy \
        clang \
        clang-format \
        clang-tools \
        cmake \
        cpio \
        dos2unix \
        execstack \
        gawk \
        gcc-aarch64-linux-gnu \
        gcc-arm-linux-gnueabihf \
        gcovr \
        gettext \
        gnu-efi \
        lcov \
        libaio-dev \
        libbsd-dev \
        libbz2-dev \
        libcmocka-dev \
        libkeyutils-dev \
        libkeyutils-dev:arm64 \
        libkeyutils-dev:armhf \
        libkeyutils1:arm64 \
        libkeyutils1:armhf \
        liblzma-dev \
        libncurses-dev \
        libnl-3-dev \
        libnl-cli-3-dev \
        libnl-utils \
        libpci-dev \
        libssl-dev:arm64 \
        libssl-dev:armhf \
        libtool \
        libtspi-dev \
        libyajl-dev \
        linux-headers-generic \
        m4 \
        ncurses-dev \
        parallel \
        ronn \
        rpm \
        software-properties-common \
        texinfo \
        u-boot-tools \
        uuid-dev \
        vim-common && \
        apt-get autoremove -y && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

RUN update-alternatives --install  /usr/bin/python python /usr/bin/python2.7 1000

# Install behave and hamcrest for testing
RUN pip3 install behave pyhamcrest requests

# Install gitlab python module
RUN pip3 install python-gitlab

# We need to install TPM 2.0 tools
RUN curl -sSfL https://github.com/01org/tpm2-tss/releases/download/1.2.0/tpm2-tss-1.2.0.tar.gz > tpm2-tss-1.2.0.tar.gz && \
    tar -zxf tpm2-tss-1.2.0.tar.gz && \
    cd tpm2-tss-1.2.0 && \
    EXTRA_CFLAGS="-Wno-error=int-in-bool-context" ./configure --prefix=/usr && \
    make && \
    make install && \
    cd .. && \
    rm -rf tpm2-tss-1.2.0 && \
    ldconfig

SHELL ["/bin/bash", "-c"]

ARG SHELLCHECK_VER=v0.7.0
RUN wget -nv https://github.com/koalaman/shellcheck/releases/download/v0.7.0/shellcheck-${SHELLCHECK_VER}.linux.x86_64.tar.xz && \
    tar xf shellcheck-${SHELLCHECK_VER}.linux.x86_64.tar.xz && \
    install shellcheck-${SHELLCHECK_VER}/shellcheck /usr/local/bin && \
    rm shellcheck-${SHELLCHECK_VER}.linux.x86_64.tar.xz && \
    rm -r shellcheck-${SHELLCHECK_VER}

ARG CPPCHECK_VER=1.89
RUN wget -nv https://github.com/danmar/cppcheck/archive/${CPPCHECK_VER}.tar.gz && \
    tar xf ${CPPCHECK_VER}.tar.gz && \
    pushd cppcheck-${CPPCHECK_VER} && \
    cmake . && \
    make -j $(nproc) && \
    make install && \
    popd && \
    rm -r cppcheck-${CPPCHECK_VER} && \
    rm ${CPPCHECK_VER}.tar.gz
