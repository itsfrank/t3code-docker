# syntax=docker/dockerfile:1.7

ARG NODE_VERSION=24.13.1

FROM oven/bun:1.3.9 AS build

ARG NODE_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV npm_config_platform=linux
ENV npm_config_arch=x64
ENV npm_config_target_arch=x64
ENV PREBUILD_ARCH=x64

WORKDIR /src/repo

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    g++ \
    make \
    python3 \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

COPY . .

RUN bun install --frozen-lockfile --concurrent-scripts 1
RUN bunx turbo run build --filter=@t3tools/contracts --filter=@t3tools/shared --filter=@t3tools/web --filter=t3

RUN mkdir -p /bundle/node /bundle/t3code/apps/server /out \
  && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
  && tar -xJf /tmp/node.tar.xz --strip-components=1 -C /bundle/node \
  && cp package.json /bundle/t3code/package.json \
  && cp -R node_modules /bundle/t3code/node_modules \
  && cp apps/server/package.json /bundle/t3code/apps/server/package.json \
  && cp -R apps/server/dist /bundle/t3code/apps/server/dist \
  && install -m 0755 t3code-docker/run-remote-t3.sh /bundle/run-t3code.sh \
  && cp t3code-docker/REMOTE_DIRECT_SETUP.md /bundle/REMOTE_DIRECT_SETUP.md \
  && tar -czf /out/t3code-remote-linux-x64.tar.gz -C /bundle .

FROM scratch AS export

COPY --from=build /out/ /
