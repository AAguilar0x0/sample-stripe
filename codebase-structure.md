# Vectle Codebase Structure

This document outlines the structure of the codebase, which follows Next.js 15 App Router conventions and modern React best practices.

## Technical Stack

- **Framework**: Next.js 15.1.4 with App Router
- **Runtime**: React 19.0.0
- **Language**: TypeScript
- **Database**: Supabase with generated types
- **API Layer**: tRPC 11 with React Query
- **Styling**: Tailwind CSS with Shadcn UI (Radix UI components)
- **Form Handling**: React Hook Form with Zod validation
- **State Management**: Zustand
- **Development Tools**:
  - ESLint & Prettier for code quality
  - Husky & lint-staged for git hooks
  - TypeScript for static typing
  - Supabase CLI for type generation

## Directory Overview

```
src/
├── app/         # Next.js App Router pages and layouts
├── components/  # Shared UI components
├── features/    # Feature-specific modules
├── lib/         # Core business logic and external integrations
├── common/      # App-wide shared utilities
└── hooks/       # Global React hooks
```

## Frontend Structure

### App (`src/app/`)

Follows Next.js App Router conventions with route groups:

- `(authenticated)/` - Protected routes requiring authentication
- `(guest)/` - Public routes including auth and public pages
- `api/` - API routes including tRPC and webhooks

### Components (`src/components/`)

Reusable UI components following a two-tier structure:

- `ui/` - Primitive components built with Shadcn UI/Radix
  - Button, Input, Dialog, etc.
  - Follows atomic design principles
- `custom-ui/` - Composite components specific to the application
  - Combines multiple primitive components
  - Implements specific business UI patterns

### Features (`src/features/<feature>/`)

Feature-specific modules. Each feature follows this structure:

- `components/` - Feature-specific React components
- `hooks.ts` - Custom React hooks for the feature
- `schemas.ts` - Zod schemas for validation

Example feature structure using `auth`:
```
features/
└── auth/
    ├── components/
    │   ├── auth-login-form.tsx
    │   ├── auth-register-form.tsx
    │   └── auth-reset-password-form.tsx
    ├── hooks.ts
    └── schemas.ts
```

### Common (`src/common/`)

App-wide shared utilities:

- `app-routes.ts` - Route definitions and constants
- `constants.ts` - Global constants
- `hooks.ts` - Shared custom hooks
- `providers/` - Global React context providers
- `utils.ts` - Utility functions
- `types.ts` - Shared TypeScript types

## Backend Structure

### Core (`src/lib/core/`)

Core business logic independent of external services:

- `constants.ts` - Core business constants
- `dtos/` - Data Transfer Objects using Zod schemas
- `handlers/` - Business logic handlers
- `controllers/` - API route controllers
- `schemas.ts` - Shared Zod schemas
- `services/` - Internal services

### External Integrations (`src/lib/extern/`)

Integration with external services:

- `db/` - Database integration (Supabase)
  - `schemas.ts` - Database-specific schemas
  - `supabase/` - Supabase repositories
- Other integrations as needed (e.g., payment, email, etc.)

### Environment & Utils

- `env/` - Environment configuration
  - `client.ts` - Client-side env vars
  - `server.ts` - Server-side env vars
- `utils.ts` - Server utilities
- `trpc/` - tRPC setup and configuration

## Best Practices

1. **Type Safety**
   - Use TypeScript throughout
   - Zod for runtime validation
   - tRPC for end-to-end type safety

2. **Component Structure**
   - Functional components only
   - Custom hooks for logic
   - Props explicitly typed

3. **Data Fetching**
   - Use React Server Components where possible
   - tRPC for client-side data fetching
   - Handle loading and error states

4. **Styling**
   - Tailwind CSS (mobile-first)
   - Shadcn UI components
   - Use gap for spacing (avoid margins)

5. **Performance**
   - Minimize client components
   - Dynamic imports with Suspense
   - Optimize for Core Web Vitals

