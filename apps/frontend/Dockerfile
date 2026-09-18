# Stage 1: Build the Vite production assets
FROM node:20-alpine AS builder
WORKDIR /app

# Copy lockfile dependencies from subfolder context
COPY apps/frontend/package.json ./
RUN npm install

COPY apps/frontend/ ./

# Compile directly into /app/dist
RUN npm run build

# Stage 2: Serve compiled web bundles using Nginx
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]