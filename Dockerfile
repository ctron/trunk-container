FROM registry.access.redhat.com/ubi9/ubi:latest

ARG TARGETPLATFORM

LABEL org.opencontainers.image.source="https://github.com/ctron/trunk-container"

RUN dnf -y update
RUN dnf -y install nodejs

ENV \
    RUSTUP_HOME=/opt/rust \
    CARGO_HOME=/opt/rust

# add cargo home to the path, must be in a new step to table able to reference CARGO_HOME
ENV PATH="$PATH:$CARGO_HOME/bin"

# the 'sed' workaround is required due to https://github.com/rust-lang/rustup/issues/2700
RUN \
    curl https://sh.rustup.rs -sSf | sed 's#/proc/self/exe#\/bin\/sh#g' | sh -s -- -y && \
    rustup target add wasm32-unknown-unknown

COPY build/${TARGETPLATFORM}/trunk /usr/local/bin

RUN npm install -g sass@1.58.3 && sass --version

RUN true \
    && curl -sSL https://github.com/rustwasm/wasm-pack/releases/download/v0.10.3/wasm-pack-v0.10.3-$(uname -p)-unknown-linux-musl.tar.gz -o wasm-pack.tar.gz \
    && tar --strip-components=1 -xvzf wasm-pack.tar.gz '*/wasm-pack' \
    && rm wasm-pack.tar.gz \
    && cp wasm-pack /usr/local/bin/ && rm wasm-pack \
    && wasm-pack --version

RUN \
    case "$(uname -p)" in \
        aarch64) \
            curl -sSL https://github.com/rustwasm/wasm-bindgen/releases/download/0.2.84/wasm-bindgen-0.2.84-aarch64-unknown-linux-gnu.tar.gz  -o wasm-bingen.tar.gz \
            && tar --strip-components=1 -xzvf wasm-bingen.tar.gz '*/wasm-bindgen' \
            && rm wasm-bingen.tar.gz \
            && install wasm-bindgen /usr/local/bin && rm wasm-bindgen \
            ;; \
        x86_64) \
            curl -sSL https://github.com/rustwasm/wasm-bindgen/releases/download/0.2.84/wasm-bindgen-0.2.84-x86_64-unknown-linux-musl.tar.gz -o wasm-bingen.tar.gz \
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

# Set the cache directory after installing tools using npm, and make it accessible
ENV npm_config_cache=/opt/npm
RUN mkdir $npm_config_cache && chmod a+rwx $npm_config_cache

RUN install -m 0777 -d /usr/src
VOLUME /usr/src/