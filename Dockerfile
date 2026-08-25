# build stage
FROM node:22-slim AS build
WORKDIR /app
RUN corepack enable
# the lockfile must come along for --frozen-lockfile
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY packages/protocol/package.json packages/protocol/
COPY packages/producer-core/package.json packages/producer-core/
COPY apps/hub/package.json apps/hub/
RUN pnpm install --frozen-lockfile
COPY tsconfig.base.json tsconfig.json ./
COPY packages/protocol packages/protocol
COPY packages/producer-core packages/producer-core
COPY apps/hub apps/hub
RUN pnpm --filter @aweshare/hub... build

# run stage — the hub resolves aweshare-protocol and aweshare-producer-core
# through apps/hub/node_modules, whose workspace symlinks target /app/packages,
# so both must ship. (No prune step: pnpm prune is interactive/unsupported
# under --filter in workspaces, so devDependencies of the root ride along.)
FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production AWESHARE_HUB_DATA_DIR=/data
COPY --from=build /app/node_modules ./node_modules
# apps/hub/dist reads the monorepo root package.json (VERSION) via ../../../package.json
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/packages/protocol/package.json ./packages/protocol/
COPY --from=build /app/packages/protocol/dist ./packages/protocol/dist
COPY --from=build /app/packages/producer-core/package.json ./packages/producer-core/
COPY --from=build /app/packages/producer-core/dist ./packages/producer-core/dist
# producer-core/dist imports 'aweshare-protocol' bare (the inliner that rewrites
# it to a relative path runs only in the root build, not per-app --filter), and
# ESM resolves that from the importer's own path — apps/hub/node_modules is not
# on that path. Ship the pnpm symlink dir so packages-side code resolves too.
COPY --from=build /app/packages/producer-core/node_modules ./packages/producer-core/node_modules
COPY --from=build /app/apps/hub/node_modules ./apps/hub/node_modules
COPY --from=build /app/apps/hub/dist ./apps/hub/dist
COPY --from=build /app/apps/hub/package.json ./apps/hub/
# container-local `aweshare` command: the image ships the hub only, so the
# umbrella CLI is a thin wrapper that forwards to the hub CLI. `aweshare hub X`
# and plain `X` both work; -h/--help/help, -v/--version and no args print the
# hub usage; `producer`/`consumer` are rejected (they run on their own machines).
RUN printf '#!/bin/sh\ncase "$1" in\n  hub) shift; exec node /app/apps/hub/dist/cli.js "$@";;\n  ""|-h|--help|help|-v|--version) exec node /app/apps/hub/dist/cli.js ${1:--h};;\n  producer) echo "error: producer commands run on the producer machine, not in the hub container" >&2; exit 1;;\n  consumer) echo "error: consumer commands run on the consumer machine, not in the hub container" >&2; exit 1;;\nesac\necho "error: use \\"aweshare hub <command>\\" in this container; producer/consumer commands run on their own machines" >&2; exit 1\n' > /usr/local/bin/aweshare \
  && chmod +x /usr/local/bin/aweshare
EXPOSE 8787
VOLUME /data
ENTRYPOINT ["node", "apps/hub/dist/cli.js"]
CMD ["serve"]
