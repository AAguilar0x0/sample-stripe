# Next.js Stripe Integration

## Project Structure

The project follows a modular architecture designed for scalability and maintainability:

```
src
├── common
├── components
├── features
├── hooks
└── lib
```

### common Folder

Contains shared utilities, constants, types, and providers used across the application:

```
common
├── app-routes.ts
├── assets.ts
├── components
├── constants.ts
├── csrf-utils.ts
├── environment.ts
├── hooks.ts
├── providers
├── types.ts
└── utils.ts
```

### components Folder

Houses reusable UI components shared across features:

```
components
└── ui
    ├── accordion.tsx
    ├── alert-dialog.tsx
    ├── button.tsx
    ├── card.tsx
    // ... other UI components
```

### features Folder

Feature-specific code organized by functionality:

```
features
├── browse
│   └── components
├── business
│   └── hooks.ts
└── business-product
    ├── components
    ├── hooks.ts
    └── stores.ts
```

### hooks Folder

Custom hooks for reusable logic:

```
hooks
├── use-mobile.tsx
└── use-toast.ts
```

### lib Folder

Backend-oriented utilities and services organized in a clean architecture pattern:

```
lib
├── adapters
│   └── trpc
│       └── routers        # tRPC route handlers
├── core
│   └── controllers        # Business logic controllers
├── env                    # Environment configuration
├── extern
│   ├── db                # Database configuration and schemas
│   └── repositories      # External service implementations
└── trpc                  # tRPC setup and utilities
```

#### Key Architecture Components:

1. **tRPC Setup**

   - Uses `createTRPCReact` for type-safe API calls
   - Server-side rendering support with React Server Components
   - Automatic request batching via `httpBatchLink`
   - Superjson for enhanced serialization

2. **Database Integration**

   - Drizzle ORM with PostgreSQL
   - Type-safe schema definitions
   - Environment-based configuration

3. **Clean Architecture**
   - Controllers handle business logic
   - Repositories manage external data access
   - Clear separation of concerns via adapters

### Environment Setup

Create a `.env` file with the following variables:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/dbname"
```

### Stripe Payment Integration

The application implements a secure and type-safe Stripe payment system using tRPC and React Server Components. The integration follows best practices for handling payments and subscriptions.

#### Setup

Add the following environment variables to your `.env` file:

```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

#### Architecture

The Stripe integration is organized in a clean, type-safe manner:

```
lib
├── adapters
│   └── trpc
│       └── routers
│           └── stripe.ts        # Stripe tRPC router
├── core
│   └── controllers
│       └── stripe.ts           # Payment business logic
└── extern
    └── stripe
        ├── client.ts           # Stripe client configuration
        ├── types.ts            # Type definitions
        └── webhooks.ts         # Webhook handlers
```

#### Key Features

1. **Type-Safe Payment Processing**

   - End-to-end type safety with tRPC
   - Zod validation for payment data
   - TypeScript interfaces for all Stripe objects

2. **Secure Payment Flow**

   - Server-side payment intent creation
   - Client-side payment confirmation
   - Webhook handling for async events
   - CSRF protection

3. **Subscription Management**

   - Subscription creation and management
   - Usage-based billing support
   - Proration handling
   - Subscription status tracking

4. **Error Handling**
   - Comprehensive error boundaries
   - Type-safe error responses
   - User-friendly error messages
   - Webhook error handling

#### Usage Example

```typescript
// Server-side payment intent creation
const { data: paymentIntent } = await trpc.stripe.createPaymentIntent.useQuery({
  amount: 1000,
  currency: 'usd',
})

// Client-side payment confirmation
const { handlePayment } = useStripePayment()
await handlePayment({
  paymentIntentId: paymentIntent.id,
  paymentMethodId: 'pm_card_visa',
})
```

#### Webhook Integration

The application implements a robust webhook system for handling asynchronous Stripe events:

```typescript
// Webhook handler
export async function POST(req: Request) {
  const body = await req.text()
  const signature = req.headers.get('stripe-signature')

  try {
    const event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET)

    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object)
        break
      case 'customer.subscription.updated':
        await handleSubscriptionUpdate(event.data.object)
        break
      // ... other event handlers
    }

    return new Response(null, { status: 200 })
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Webhook error' }), { status: 400 })
  }
}
```

#### Security Considerations

1. **API Key Management**

   - Server-side only access to secret keys
   - Environment variable protection
   - Key rotation support

2. **Data Protection**

   - PCI compliance through Stripe Elements
   - No sensitive data storage
   - Encrypted communication

3. **Rate Limiting**
   - API request throttling
   - Webhook retry handling
   - Concurrent request management

### Key Conventions

1. Keep folders shallow: Maximum two levels deep unless necessary
2. Feature isolation: Group related components, hooks, and stores within features
3. Shared functionality: Place reusable code in common
4. Type safety: Use tRPC for end-to-end type safety
5. Server Components: Prefer React Server Components for data fetching
6. Error Handling: Use Zod for validation and tRPC error handling

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
