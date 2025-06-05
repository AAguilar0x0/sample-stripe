# DB Agent Chat Implementation Details V2

## Overview

The DB Agent Chat is a feature that enables users to interact with their database using natural language. It provides a chat interface where users can ask questions about their data, and the agent translates these questions into SQL queries, executes them, and returns the results.

This implementation uses LangGraph to create a stateful conversation flow with human-in-the-loop capabilities, allowing users to review and approve SQL queries before execution.

## Implementation Architecture

The DB Agent Chat feature follows a layered architecture that connects the React frontend to the LangGraph-powered backend:

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
                                    │  DBChatAgent (LangGraph)    │
                                    │  (SQL Generation & Execution)│
                                    │                             │
                                    └─────────────────────────────┘
```

## LangGraph Implementation

The core of the implementation is the `DBChatAgent` class in `src/lib/langgraph/db-chat-agent/index.ts`, which uses LangGraph's `StateGraph` to create a directed graph for conversation flow:

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

### State Management

The `DBChatAgent` class uses `DBChatAnnotation` to track conversation state:

```typescript
export const DBChatAnnotation = Annotation.Root({
  messages: Annotation<BaseMessage[]>({
    reducer: (x, y) => x.concat(y),
    default: () => [],
  }),
  writtenQuery: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
  sqlResult: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
  question: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
  userId: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
  vectleProfileId: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
  businessId: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y || x,
  }),
})
```

This state tracks:
- Messages in the conversation
- The SQL query generated from natural language
- The result of executing the SQL query
- The original question asked by the user
- User context (userId, businessId, vectleProfileId)

### Graph Nodes

The `DBChatAgent` class defines the following nodes in the graph:

1. **writeQuery**: Generates SQL from natural language input
   - Uses a structured prompt template to guide the LLM
   - Enforces business_id restrictions for data security
   - Returns the generated SQL query and explanation

2. **humanApproval**: Interrupts execution for user review
   - Uses LangGraph's `interrupt()` function to create a breakpoint
   - Presents the generated SQL to the user for approval/rejection
   - Routes to either executeQuery or rejectedExecution based on user decision

3. **executeQuery**: Runs the approved SQL query
   - Uses `QuerySqlTool` to safely execute the query
   - Returns the result of the query execution

4. **generateAnswer**: Creates a natural language response from results
   - Uses a prompt template to generate a user-friendly answer
   - Formats the response based on the query type (SELECT, INSERT, etc.)

5. **rejectedExecution**: Handles query rejection
   - Provides a graceful response when users reject a query
   - Resets the conversation state for a new question

### Message Handling

The `DBChatAgent` class includes custom message handling to support different message types:

```typescript
createMessage(
  content: string,
  type: MessageType,
  id: string | undefined,
  config?: {
    doNotRender?: boolean
  },
) {
  const newId = config?.doNotRender ? DO_NOT_RENDER_PREFIX + (id ?? uuidv4()) : (id ?? uuidv4())

  switch (type) {
    case 'ai':
      return new AIMessage({
        content,
        id: newId,
        additional_kwargs: { type },
      })
    case 'human':
      return new HumanMessage({
        content,
        id: newId,
        additional_kwargs: {
          type,
        },
      })
    case 'system':
      return new SystemMessage({
        content,
        id: newId,
        additional_kwargs: { type },
      })
    default:
      throw new Error('Invalid message type')
  }
}
```

This allows for:
- Different message types (AI, human, system)
- Hidden messages that shouldn't be rendered in the UI
- Preserving message IDs for tracking

### SQL Generation and Security

The implementation includes several security features:

1. **Structured Prompts**: Uses carefully crafted prompts to guide SQL generation
   ```typescript
   const systemTemplate = `
   Given an input question, create a syntactically correct {dialect} query to run to help find the answer.
   
   IMPORTANT: Data access and mutation restrictions:
   - For SELECT queries: Always include "business_id = '{business_id}'" in the WHERE clause for all tables
   - For INSERT queries: Always set "business_id = '{business_id}'" for new records
   - For UPDATE queries: Always include "business_id = '{business_id}'" in the WHERE clause
   - For DELETE queries: Always include "business_id = '{business_id}'" in the WHERE clause
   `
   ```

2. **Table Information**: Provides database schema information to the LLM
   ```typescript
   const fullTableInfo = await this.getTableInfo()
   ```

3. **Business ID Restrictions**: Enforces business_id filtering in all queries
   ```typescript
   // From the prompt template:
   // "Always include "business_id = '{business_id}'" in the WHERE clause"
   ```

## Service Integration

The `DBChatAgentService` class integrates the `DBChatAgent` into the application:

```typescript
export class DBChatAgentService {
  private chatLLM: BaseChatModel
  private dbAgent
  
  constructor(
    private readonly db: SqlDatabase,
    private readonly postgresSaver: PostgresSaver,
  ) {
    this.chatLLM = new ChatOpenAI({
      model: 'gpt-4o-mini',
      temperature: 0,
      apiKey: env.OPENAI_API_KEY,
    })
    this.dbAgent = new DBChatAgent(this.chatLLM, this.db)
  }

  async getGraphState(threadId: string) {
    const config = {
      configurable: { thread_id: threadId },
      streamMode: 'updates' as const,
    }

    const graph = this.dbAgent.graph().compile({
      checkpointer: this.postgresSaver,
    })

    return graph.getState({
      ...config,
    })
  }
  
  async stream(
    userData: {
      userId: string
      vectleProfileId: string
      businessId: string
    },
    payload: { input: string; threadId: string; inputId: string },
  ) {
    const streamModes: StreamMode[] = ['updates', 'messages']
    const threadConfig = {
      configurable: { thread_id: payload.threadId },
      streamMode: streamModes,
    }
    const graph = this.dbAgent.graph().compile({
      checkpointer: this.postgresSaver,
    })

    if (dbChatAgentHandler.isHumanResponse(payload.input)) {
      const acceptedResponse = dbChatAgentHandler.parseHumanResponse(payload.input)

      return graph.stream(
        new Command({
          resume: {
            action: acceptedResponse,
          },
        }),
        threadConfig,
      )
    }

    const humanMessage = this.dbAgent.createMessage.bind(
      this,
      payload.input,
      'human',
      payload.inputId,
    )()
    return graph.stream(
      {
        messages: [humanMessage],
        userId: userData.userId,
        vectleProfileId: userData.vectleProfileId,
        businessId: userData.businessId,
        question: payload.input,
      },
      threadConfig,
    )
  }
}
```

Key features:
1. **Persistent State**: Uses `PostgresSaver` to persist conversation state
2. **Streaming Responses**: Implements streaming for real-time updates
3. **Human-in-the-Loop**: Handles approval/rejection commands

## Frontend Integration

The frontend integrates with this backend through tRPC:

```typescript
// In db-agent-chat.tsx
const sendMessage = async (message: string) => {
  try {
    const stream = trpc.dbChatAgent.stream.useMutation()
    
    // Send the message
    const response = await stream.mutateAsync({
      input: message,
      threadId: threadId,
      inputId: generateId(),
    })
    
    // Handle streaming updates
    for await (const update of response) {
      // Update UI with streaming content
    }
  } catch (error) {
    // Handle errors
  }
}

// Handle approval/rejection
const handleApproval = async (approved: boolean) => {
  const action = approved ? DB_CHAT_AGENT.APPROVED : DB_CHAT_AGENT.REJECTED
  await sendMessage(action)
}
```

## Key Improvements in V2

1. **Modular Architecture**: Separation of concerns between the LangGraph implementation and service integration
2. **Enhanced Security**: Improved business_id filtering and table restrictions
3. **Better Prompting**: More detailed prompt templates for SQL generation and answer formatting
4. **Streaming Optimization**: Improved streaming with multiple stream modes
5. **Type Safety**: Better type definitions with Zod schemas for validation

## Implementation Status

The DB Agent Chat is fully implemented with the following features:

- ✅ LangGraph-based conversation flow
- ✅ Human-in-the-loop SQL approval
- ✅ Persistent conversation state
- ✅ Streaming responses
- ✅ Business context security
- ✅ Natural language to SQL translation
- ✅ SQL execution and result formatting 