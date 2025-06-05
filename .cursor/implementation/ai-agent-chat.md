# DB Agent Chat Implementation Details
AI Agent Chat

## Overview

The DB Agent Chat is a feature that enables users to interact with their database using natural language. It provides a chat interface where users can ask questions about their data, and the agent translates these questions into SQL queries, executes them, and returns the results.

This implementation follows a similar pattern to the planned [AI Agent Chat](./ai-agent-chat.md) but is specifically focused on database interactions with a more streamlined approach.

## Implementation Architecture

The DB Agent Chat feature follows a layered architecture that connects the React frontend to the LangChain-powered backend, following the standard data flow pattern:

```
Frontend (React)                    Backend (Node.js)
┌─────────────────────┐             ┌─────────────────────────────┐
│                     │             │                             │
│  db-agent-chat.tsx  │  tRPC API   │  dbChatAgentRouter         │
│  (React Component)  │◄────────────┤  (tRPC Router)             │
│         │           │             │                             │
│         │           │             │                             │
│         ▼           │             │         │                   │
│  useDbAgentThreadId │             │         ▼                   │
│  (Internal Hook)    │             │                             │
│                     │             │  DBChatAgentController      │
└─────────────────────┘             │  (Controller)               │
                                    │                             │
                                    │         │                   │
                                    │         ▼                   │
                                    │                             │
                                    │  DBChatAgentService         │
                                    │  (Service)                  │
                                    │                             │
                                    │         │                   │
                                    │         ▼                   │
                                    │                             │
                                    │  LangChain & LangGraph      │
                                    │  (SQL Generation & Execution)│
                                    │                             │
                                    └─────────────────────────────┘
```

## Component Structure

```
src/
├── features/
│   └── db-agent/
│       ├── components/
│       │   └── db-agent-chat.tsx       # Main UI component with tRPC calls
│       └── hooks/
│           └── useDbAgentThreadId.ts   # Internal hook for thread management
├── lib/
│   ├── adapters/
│   │   └── trpc/
│   │       └── routers/
│   │           └── db-chat-agent.ts    # tRPC router for agent
│   ├── core/
│   │   ├── controllers/
│   │   │   └── db-chat-agent.ts        # Controller for handling requests
│   │   ├── handlers/
│   │   │   └── db-chat-agent.ts        # Message handling utilities
│   │   └── services/
│   │       └── db-chat-agent.ts        # Core agent service
│   └── extern/
│       └── index.ts                    # Service provider registration
```

## Implementation Details

### Main Components

1. **DBAgentChatWrapper**
   - Entry point component in `db-agent-chat.tsx`
   - Handles loading states and error conditions
   - Uses `useDbAgentThreadId` hook internally for thread management
   - Fetches user and business data using tRPC queries

2. **DbAgentChat**
   - Core chat interface component in `db-agent-chat.tsx`
   - Manages messages state and streaming content
   - Handles user interactions (send, approve, reject)
   - Directly communicates with backend via tRPC mutations

3. **useDbAgentThreadId**
   - Internal hook used only within the db-agent-chat component
   - Manages thread creation and storage
   - Provides thread ID for API calls
   - Does not communicate directly with the backend

4. **DbAgentEmptyState**
   - Shown when no messages exist
   - Displays example queries as conversation starters
   - Provides user guidance on capabilities

### Data Flow

Following the standard pattern from the diagram:

1. User inputs a natural language question in the chat interface
2. The `db-agent-chat.tsx` component gets the thread ID from `useDbAgentThreadId` hook
3. The input and thread ID are sent to the backend via `trpc.dbChatAgent.stream.useMutation()`
4. The tRPC router (`dbChatAgentRouter`) validates the input and forwards it to the controller
5. The controller (`DBChatAgentController`) processes the request and calls the service
6. The service (`DBChatAgentService`) uses LangChain to:
   - Generate a SQL query from the natural language input
   - Stream back the generated SQL for user approval
7. The response flows back through the controller and router to the frontend
8. The frontend displays the SQL and prompts for approval/rejection
9. User approves or rejects via UI buttons, sending `APPROVED` or `REJECTED` constants
10. If approved, the request flows through the same path:
    - Router → Controller → Service → LangChain
    - The service executes the SQL query and generates a response
    - The response flows back: Service → Controller → Router → Frontend
11. The frontend renders the response in the chat interface

### Backend Implementation

#### tRPC Router (lib/adapters/trpc/routers/db-chat-agent.ts)

The router defines the API endpoints and handles input validation:

- `stream`: A mutation procedure that takes user input and streams responses
- `state`: A query procedure that retrieves the current state of a conversation
- Both procedures validate inputs using Zod schemas
- Routes requests to the appropriate controller methods

#### Controller (lib/core/controllers/db-chat-agent.ts)

The `DBChatAgentController` acts as an intermediary between the router and service:

- Receives validated requests from the router
- Formats data for the service layer
- Handles streaming responses with generator functions
- Provides methods:
  - `stream()`: Streams chat responses from the service
  - `getGraphState()`: Retrieves the current state of a conversation

#### Message Handling (lib/core/handlers/db-chat-agent.ts)

This module provides utilities for handling message formats and state interrupts:

- Defines constants like `DB_CHAT_AGENT.APPROVED` and `DB_CHAT_AGENT.REJECTED`
- Provides type definitions for messages and state updates
- Implements validation functions to check message types
- Handles state interrupts for human approval workflows

#### Core Service (lib/core/services/db-chat-agent.ts)

The `DBChatAgentService` class implements the core agent functionality:

1. **State Management**
   - Uses `StateAnnotation` to track conversation state
   - Maintains messages, SQL queries, and results
   - Preserves user context (userId, businessId, vectleProfileId)

2. **LangGraph Implementation**
   - Implements a directed graph with nodes for:
     - `writeQuery`: Generates SQL from natural language
     - `humanApproval`: Interrupts for user review
     - `executeQuery`: Runs approved SQL
     - `generateAnswer`: Creates response from results
     - `rejectedExecution`: Handles query rejection
   - Defines edges between nodes to control conversation flow

3. **SQL Generation and Security**
   - Uses ChatOpenAI model to generate SQL queries
   - Filters table information to only include allowed tables
   - Enforces business_id restrictions for data security
   - Executes queries safely using QuerySqlTool

4. **Streaming Architecture**
   - Implements `stream()` method that returns an async generator
   - Handles different input types (normal questions vs. approvals/rejections)
   - Formats messages for proper frontend rendering

### Service Integration (lib/extern/index.ts)

The DB Agent Chat service is integrated into the application through:

1. **Service Provider Pattern**
   - `MyServiceProvider` class accepts database dependencies
   - `DBChatAgentService()` method returns a singleton instance
   - Lazy initialization ensures resources are only created when needed

2. **Controller Factory Pattern**
   - Controllers are instantiated with their required services
   - `DBChatAgentController` is created with an instance of `DBChatAgentService`
   - This follows the dependency injection pattern for better testability

## LangGraph Implementation Details

The DB Agent Chat feature leverages LangGraph and LangChain to create a powerful, stateful conversation flow with human-in-the-loop capabilities. This implementation follows best practices from the LangGraph documentation and adapts them to the specific needs of database interactions.

### State Graph Architecture

The core of the implementation is in `lib/core/services/db-chat-agent.ts`, which uses LangGraph's `StateGraph` to create a directed graph for conversation flow:

```
                  ┌─────────────┐
                  │    START    │
                  └──────┬──────┘
                         │
                         ▼
                  ┌─────────────┐
                  │  writeQuery │
                  └──────┬──────┘
                         │
                         ▼
                  ┌─────────────┐
                  │humanApproval│
                  └──────┬──────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
           ▼                           ▼
    ┌─────────────┐            ┌─────────────┐
    │ executeQuery │            │rejectedExec │
    └──────┬──────┘            └──────┬──────┘
           │                           │
           ▼                           │
    ┌─────────────┐                    │
    │generateAnswer│                    │
    └──────┬──────┘                    │
           │                           │
           ▼                           ▼
    ┌─────────────┐            ┌─────────────┐
    │     END     │            │     END     │
    └─────────────┘            └─────────────┘
```

This graph defines the conversation flow with the following nodes:

1. **writeQuery**: Generates SQL from natural language input
2. **humanApproval**: Interrupts execution for user review
3. **executeQuery**: Runs the approved SQL query
4. **generateAnswer**: Creates a natural language response from results
5. **rejectedExecution**: Handles query rejection

### Human-in-the-Loop Implementation

The implementation uses LangGraph's `interrupt()` function to create a human-in-the-loop approval workflow, similar to the approach described in the [LangGraph Review Tool Calls documentation](https://langchain-ai.github.io/langgraphjs/how-tos/review-tool-calls/#simple-usage).

In the `humanApproval` node:

```typescript
async humanApproval(state: typeof StateAnnotation.State) {
  const isApproved = interrupt<
    {
      question: string
      llm_output: string
    },
    {
      action: 'approved' | 'rejected'
    }
  >({
    question: 'Is this correct?',
    llm_output: state.writtenQuery,
  })

  if (isApproved.action === 'approved') {
    return new Command({ goto: 'executeQuery' })
  } else {
    return new Command({ goto: 'rejectedExecution' })
  }
}
```

This creates a breakpoint in the execution flow where:
1. The generated SQL query is presented to the user
2. The user can approve or reject the query
3. Based on the user's decision, the flow continues to either execute the query or reject it

### Persistent State Management

The implementation uses `PostgresSaver` from `@langchain/langgraph-checkpoint-postgres` to persist conversation state across requests, as described in the [LangGraph Persistence documentation](https://langchain-ai.github.io/langgraphjs/concepts/persistence/#memory-store).

```typescript
constructor(
  private readonly db: SqlDatabase,
  private readonly postgresSaver: PostgresSaver,
) {
  // ...
}

```

This allows the conversation to maintain state between user interactions, which is crucial for the approval workflow and for maintaining context throughout the conversation.

### SQL Query Generation and Execution

The implementation follows the pattern described in the [LangChain SQL QA tutorial](https://js.langchain.com/docs/tutorials/sql_qa/#human-in-the-loop) for generating and executing SQL queries:

1. **Query Generation**: Uses a structured prompt template to guide the LLM in generating SQL
   ```typescript
   async writeQuery(state: typeof StateAnnotation.State) {
     const structuredLlm = this.chatLLM.withStructuredOutput(agentWriteQueryOutputSchema)
     const qTemplate = await this.queryPromptTemplate()
     const promptValue = await qTemplate.invoke({
       dialect: this.db.appDataSourceOptions.type,
       top_k: 10,
       table_info: filteredTableInfo,
       input: state.question,
       business_id: state.businessId,
       // ...
     })
     const result = await structuredLlm.invoke(promptValue)
     return {
       messages: [/* ... */],
       writtenQuery: result.query,
     }
   }
   ```

2. **Query Execution**: Uses `QuerySqlTool` to safely execute the approved query
   ```typescript
   async executeQuery(state: typeof StateAnnotation.State) {
     const executeQueryTool = new QuerySqlTool(this.db)
     const result = await executeQueryTool.invoke(state.writtenQuery)
     return {
       sqlResult: result,
     }
   }
   ```

3. **Response Generation**: Creates a natural language response based on the query results
   ```typescript
   async generateAnswer(state: typeof StateAnnotation.State) {
     const promptValue =
       'Given the following user question, corresponding SQL query, ' +
       'and SQL result, answer the user question.\n\n' +
       `Question: ${state.question}\n` +
       `SQL Query: ${state.writtenQuery}\n` +
       `SQL Result: ${state.sqlResult}\n`
     const result = await this.chatLLM.invoke(promptValue)
     return {
       messages: [/* ... */],
       question: '',
       writtenQuery: '',
       sqlResult: '',
     }
   }
   ```

### Security Enhancements

The implementation includes several security enhancements beyond the standard LangChain examples:

1. **Table Filtering**: Only allows access to specific tables
   ```typescript
   const ALLOWED_TABLES = [
     'pages',
     'business_data',
     'page_business_data',
     'businesses',
     'vectle_profiles',
   ] as const
   ```

2. **Business ID Restrictions**: Enforces business_id filtering in all queries
   ```typescript
   // From the prompt template:
   // "For SELECT queries: Always include "business_id = '{business_id}'" in the WHERE clause for all tables"
   ```

3. **Regex Pattern Matching**: Uses precompiled regex patterns for better performance and security
   ```typescript
   private filterTableInfo(fullTableInfo: string): string {
     // Split by CREATE TABLE statements
     const tableBlocks = fullTableInfo
       .split('CREATE TABLE')
       .filter(block => block.trim().length > 0)
       .map(block => 'CREATE TABLE' + block)

     // Filter to only include allowed tables with exact matching using precompiled patterns
     return tableBlocks
       .filter(tableBlock => {
         return ALLOWED_TABLES.some(tableName => {
           const pattern = this.tablePatterns.get(tableName)
           return pattern?.test(tableBlock) || false
         })
       })
       .join('\n\n')
   }
   ```

### Message Handling and Streaming

The implementation includes custom message handling in `lib/core/handlers/db-chat-agent.ts` to support the streaming architecture:

```typescript
export const DB_CHAT_AGENT = {
  APPROVED: 'response:approved',
  REJECTED: 'response:rejected',
}

export const dbChatAgentHandler = {
  isHumanResponse: (input: string) => {
    return input.startsWith('response:')
  },
  parseHumanResponse: (input: string) => {
    return input.split(':')[1]
  },
  // ...other utility functions
}
```

These utilities enable:
1. Parsing special commands like approval/rejection
2. Handling streaming updates
3. Managing message rendering in the UI

## Implementation Status

The DB Agent Chat is fully implemented with the following features:

- ✅ Chat interface with message streaming
- ✅ Thread management
- ✅ SQL query generation and approval
- ✅ Error handling and loading states
- ✅ Example queries and guidance
- ✅ User profile integration 