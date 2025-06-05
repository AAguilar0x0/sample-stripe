# tRPC Data Flow Architecture

This document outlines the data flow architecture using tRPC in our Next.js application, following best practices and maintaining type safety throughout the stack.

## Technical Stack

- **tRPC Version**: 11.0.0-rc.708
- **Query Client**: @tanstack/react-query v5
- **Type Safety**: TypeScript + Zod validation
- **Database**: Supabase with generated types
- **API Layer**: Next.js App Router API routes

## Directory Structure

```
src/lib/
├── core/
│   ├── controllers/     # Business logic controllers
│   ├── dtos/           # Data Transfer Objects with Zod schemas
│   └── services/       # Core business services
├── extern/
│   └── db/
│       └── supabase/   # Supabase repositories
├── trpc/               # tRPC configuration
└── adapters/
    └── trpc/
        └── routers/    # tRPC route handlers
```

## Data Flow Implementation

### 1. Repository Layer (`src/lib/extern/db/supabase/<feature-repo>.ts`)

Handles direct database interactions:

```typescript
import { DTO, Entity } from '@/lib/core/dtos/<feature>'

export class Repo {
  constructor() {
    // Initialize database connection
  }

  // Database operations
  async create(): Promise<Entity> {}
  async find(): Promise<Entity[]> {}
  async update(): Promise<Entity> {}
  async delete(): Promise<void> {}
}
```

### 2. Service Provider (`src/lib/extern/index.ts`)

Manages service dependencies and injection:

```typescript
export class MyServiceProvider {
  private featureRepo: FeatureRepo

  getFeatureRepo() {
    if (!this.featureRepo) {
      this.featureRepo = new FeatureRepo()
    }
    return this.featureRepo
  }
}
```

### 3. Controllers (`src/lib/core/controllers/<feature>.ts`)

Implements business logic:

```typescript
import { FeatureRepo } from '@/lib/extern/db/supabase/<feature>'

export class Controller {
  constructor(private repo: FeatureRepo) {}

  async handleOperation(input: InputDTO): Promise<OutputDTO> {
    // Business logic implementation
  }
}
```

### 4. Controller Factory (`src/lib/core/controllers/index.ts`)

Manages controller instantiation:

```typescript
export class MyControllerFactory {
  constructor(private services: MyServiceProvider) {}

  getFeatureController() {
    return new FeatureController(this.services.getFeatureRepo())
  }
}
```

### 5. tRPC Router Implementation

#### Router Setup (`src/lib/adapters/trpc/routers/<feature>.ts`)

```typescript
export const featureRouter = createTRPCRouter({
  operation: protectedProcedure
    .input(inputSchema)
    .query(async ({ ctx, input }) => {
      const result = await ctx.controllers
        .getFeatureController()
        .handleOperation(input)
      return result
    }),
})
```

#### Router Registration (`src/lib/adapters/trpc/routers/index.ts`)

```typescript
export const appRouter = createTRPCRouter({
  feature: featureRouter,
})
```

## Best Practices

1. **Type Safety**
   - Use Zod schemas for input/output validation
   - Leverage tRPC's type inference
   - Generate and use database types

2. **Error Handling**
   - Use custom error classes
   - Implement proper error boundaries
   - Handle tRPC errors gracefully

3. **Performance**
   - Implement proper caching strategies
   - Use React Query's built-in caching
   - Optimize query invalidation

4. **Security**
   - Implement proper authentication checks
   - Use protected procedures where needed
   - Validate all inputs

## Client Usage

```typescript
// React component example
export function FeatureComponent() {
  const { data, isLoading } = trpc.feature.operation.useQuery({
    // typed input parameters
  })

  if (isLoading) return <Loading />
  
  return <div>{data.result}</div>
}
```

## Implementation Steps

1. Create feature repository in `src/lib/extern/db/supabase/<feature-repo>.ts`
2. Update `MyServiceProvider` with new feature service
3. Create feature controller in `src/lib/core/controllers/<feature>.ts`
4. Update `MyControllerFactory` with new controller
5. Register controller in tRPC initialization
6. Create feature router in `src/lib/adapters/trpc/routers/<feature>.ts`
7. Register router in main router index

## Testing

- Unit test controllers and repositories
- Integration test tRPC procedures
- End-to-end test complete flow
- Mock external dependencies

## Common Patterns

### Input Validation

```typescript
const inputSchema = z.object({
  // Zod schema definition
})

export type InputType = z.infer<typeof inputSchema>
```

### Error Handling

```typescript
try {
  const result = await operation()
  return result
} catch (error) {
  throw new TRPCError({
    code: 'INTERNAL_SERVER_ERROR',
    message: 'Operation failed',
    cause: error,
  })
}
```

### Query Invalidation

```typescript
const utils = trpc.useUtils()
await utils.feature.operation.invalidate()
```
