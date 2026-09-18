FROM astral/uv:python3.11-bookworm-slim

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1 

# 1. Copy ONLY core configuration files
COPY pyproject.toml uv.lock ./

# 2. OPTIMIZATION: Copy package configuration files ONLY
COPY packages/backend/pyproject.toml ./packages/backend/

# 3. FIXED: Tell uv exactly which package dependencies to pre-install into the layer cache
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-workspace --package aegisrag-backend

# 4. Now copy the rest of your changing source code files
COPY packages/ ./packages/

# 5. Complete the final workspace linkage step for the target package
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --package aegisrag-backend

EXPOSE 8000

# 6. Final Server Runtime command
CMD ["uv", "run", "--package", "aegisrag-backend", "uvicorn", "packages.backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
