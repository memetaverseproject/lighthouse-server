FROM node:16-alpine as base
WORKDIR /app
RUN apk add --no-cache bash

COPY package.json .
COPY yarn.lock .

# get production dependencies
FROM base as dependencies
RUN yarn install --prod --frozen-lockfile

# build sources
FROM base as catalyst-builder
RUN yarn install --frozen-lockfile

COPY . .
FROM catalyst-builder as comms-builder
RUN yarn build

# build final image with transpiled code and runtime dependencies
FROM base

COPY --from=dependencies /app/node_modules ./node_modules/

COPY --from=comms-builder /app/dist/src .

# https://docs.docker.com/engine/reference/builder/#arg
ARG CATALYST_VERSION=4.0.0-ci
ENV CATALYST_VERSION=${CATALYST_VERSION:-4.0.0}

# https://docs.docker.com/engine/reference/builder/#arg
ARG COMMIT_HASH=local
ENV COMMIT_HASH=${COMMIT_HASH:-local}

EXPOSE 9000

# Please _DO NOT_ use a custom ENTRYPOINT because it may prevent signals
# (i.e. SIGTERM) to reach the service
# Read more here: https://aws.amazon.com/blogs/containers/graceful-shutdowns-with-ecs/
#            and: https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/

# We use Tini to handle signals and PID1 (https://github.com/krallin/tini, read why here https://github.com/krallin/tini/issues/8)
RUN apk add --no-cache tini

ENTRYPOINT ["/sbin/tini", "--"]

# Run the program under Tini
CMD [ "/usr/local/bin/node", "--max-old-space-size=8192", "server.js" ]
