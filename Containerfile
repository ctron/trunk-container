FROM registry.access.redhat.com/ubi9/ubi:latest

ARG TARGETPLATFORM

ARG RUST_VERSION="1.75.0"
ARG SASS_VERSION="1.70.0"
ARG WASM_PACK_VERSION="0.12.1"
ARG WASM_BINDGEN_VERSION="0.2.90"
ARG BINARYEN_VERSION="116"

LABEL org.opencontainers.image.source="https://github.com/ctron/trunk-container"

RUN dnf -y install nodejs git gcc

ENV \
    RUSTUP_HOME=/opt/rust \
    CARGO_HOME=/opt/rust

# add cargo home to the path, must be in a new step to table able to reference CARGO_HOME
ENV PATH="$PATH:$CARGO_HOME/bin"

# the 'sed' workaround is required due to https://github.com/rust-lang/rustup/issues/2700
RUN \
    curl https://sh.rustup.rs -sSf | sed 's#/proc/self/exe#\/bin\/sh#g' | sh -s -- -y --default-toolchain ${RUST_VERSION} && \
    rustup target add wasm32-unknown-unknown

COPY build/${TARGETPLATFORM}/trunk /usr/local/bin

RUN trunk --version

RUN npm install -g sass@${SASS_VERSION} && sass --version

RUN true \
    && curl -sSL https://github.com/rustwasm/wasm-pack/releases/download/v${WASM_PACK_VERSION}/wasm-pack-v${WASM_PACK_VERSION}-$(uname -p)-unknown-linux-musl.tar.gz -o wasm-pack.tar.gz \
    && tar --strip-components=1 -xvzf wasm-pack.tar.gz '*/wasm-pack' \
    && rm wasm-pack.tar.gz \
    && cp wasm-pack /usr/local/bin/ && rm wasm-pack \
    && wasm-pack --version

RUN \
    case "$(uname -p)" in \
        aarch64) \
            curl -sSL https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-aarch64-unknown-linux-gnu.tar.gz  -o wasm-bingen.tar.gz \
            && tar --strip-components=1 -xzvf wasm-bingen.tar.gz '*/wasm-bindgen' \
            && rm wasm-bingen.tar.gz \
            && install wasm-bindgen /usr/local/bin && rm wasm-bindgen \
            ;; \
        x86_64) \
            curl -sSL https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-x86_64-unknown-linux-musl.tar.gz -o wasm-bingen.tar.gz \
            && tar --strip-components=1 -xzvf wasm-bingen.tar.gz '*/wasm-bindgen' \
            && rm wasm-bingen.tar.gz \
            && install wasm-bindgen /usr/local/bin && rm wasm-bindgen \
            ;; \
        *) \
            echo "Build platform not supported: $(uname -p)" ; \
            exit 1 \
            ;; \
    esac ; \
    wasm-bindgen --version

RUN \
    case "$(uname -p)" in \
      x86_64) \
          curl -sSL https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-x86_64-linux.tar.gz -o binaryen.tar.gz \
          && tar --strip-components=1 -xzvf binaryen.tar.gz '*/wasm-opt' \
          && rm binaryen.tar.gz \
          && install bin/wasm-opt /usr/local/bin && rm -Rf bin \
          && wasm-opt --version \
          ;; \
      *) \
          echo "Ignoring wasm-opt for: $(uname -p)" ; \
          ;; \
    esac

# Set the cache directory after installing tools using npm, and make it accessible
ENV npm_config_cache=/opt/npm
RUN mkdir $npm_config_cache && chmod a+rwx $npm_config_cache

RUN install -m 0777 -d /usr/src
VOLUME /usr/src/

EXPOSE 8080
