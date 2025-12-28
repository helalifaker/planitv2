# Plan-It Frontend Dockerfile
# Next.js 16 + React 19

FROM node:22-alpine

# Set working directory
WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy dependency files
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Run development server with Turbopack
CMD ["pnpm", "dev"]
