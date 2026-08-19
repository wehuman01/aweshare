# build stage
FROM node:22-slim AS build
WORKDIR /app
RUN corepack enable
# the lockfile must come along for --frozen-lockfile
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY packages/protocol/package.json packages/protocol/
COPY apps/hub/package.json apps/hub/
RUN pnpm install --frozen-lockfile
COPY tsconfig.base.json tsconfig.json ./
COPY packages/protocol packages/protocol
COPY apps/hub apps/hub
RUN pnpm --filter @aweshare/hub... build

# run stage — the hub resolves aweshare-protocol through apps/hub/node_modules,
# whose workspace symlink targets /app/packages/protocol, so it must ship too.
# (No prune step: pnpm prune is interactive/unsupported under --filter in workspaces,
# so devDependencies of the root ride along.)
FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production AWESHARE_HUB_DATA_DIR=/data
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/packages/protocol/package.json ./packages/protocol/
COPY --from=build /app/packages/protocol/dist ./packages/protocol/dist
COPY --from=build /app/apps/hub/node_modules ./apps/hub/node_modules
COPY --from=build /app/apps/hub/dist ./apps/hub/dist
COPY --from=build /app/apps/hub/package.json ./apps/hub/
EXPOSE 8787
VOLUME /data
ENTRYPOINT ["node", "apps/hub/dist/cli.js"]
CMD ["serve"]
