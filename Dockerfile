# ── Stage 1: Clone & Build ──────────────────────────────────────────
FROM node:20-alpine AS builder

RUN apk add --no-cache git

WORKDIR /build

# Clone the demo repo and fetch the submodules needed by the frontend
RUN git clone --depth 1 https://github.com/in-th3-l00p/demo.git . && \
    git submodule update --init --depth 1 \
        submodules/panoplia.peer \
        submodules/panoplia.defi

# Build panoplia.peer library
RUN cd submodules/panoplia.peer && npm ci && npm run build

# Build panoplia.defi (panoplia.swap) library
RUN cd submodules/panoplia.defi && npm ci && npm run build

# Vite env vars (inlined at build time)
ARG VITE_MPC_API_URL=http://localhost:3000
ARG VITE_WALLETCONNECT_PROJECT_ID=

# Install app dependencies and build the Vite app
RUN cd app && \
    printf "VITE_MPC_API_URL=%s\nVITE_WALLETCONNECT_PROJECT_ID=%s\n" \
        "$VITE_MPC_API_URL" "$VITE_WALLETCONNECT_PROJECT_ID" > .env && \
    npm install && npm run build

# ── Stage 2: Serve ──────────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /build/app/dist /usr/share/nginx/html

# SPA fallback — serve index.html for all client-side routes
RUN printf 'server {\n\
    listen 80;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
