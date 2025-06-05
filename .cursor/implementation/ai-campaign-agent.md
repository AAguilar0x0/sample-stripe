# DB Campaign Agent Implementation Details

## Overview

The DB Campaign Agent is a specialized AI assistant that helps users create marketing campaigns through a conversational interface. It provides a chat experience where users can request campaign creation, receive suggestions, and interactively refine campaign parameters before finalizing them.

This implementation follows a similar pattern to the [AI Agent Chat](./ai-agent-chat.md) but is specifically tailored for campaign generation workflows with an interactive approval process.

## Implementation Architecture

The Campaign Agent feature follows a layered architecture that connects the React frontend to the LangChain-powered backend, following the standard data flow pattern:

```
Frontend (React)                    Backend (Node.js)
┌─────────────────────┐             ┌─────────────────────────────┐
│                     │             │                             │
│ agent-onboarding-   │  tRPC API   │  dbChatAgentRouter         │
│    chat.tsx         │◄────────────┤  (tRPC Router)             │
│  (React Component)  │             │                             │
│         │           │             │                             │
│         │           │             │         │                   │
│         ▼           │             │         ▼                   │
│  useDbAgentThreadId │             │                             │
│  useOnboardingAgent │             │  OnboardingAgentController  │
│     Chat (Hooks)    │             │  (Controller)               │
│                     │             │                             │
└─────────────────────┘             │         │                   │
                                    │         ▼                   │
                                    │                             │
                                    │  OnboardingAgent            │
                                    │  (LangGraph Agent Class)    │
                                    │                             │
                                    │         │                   │
                                    │         ▼                   │
                                    │                             │
                                    │  LangChain & LangGraph      │
                                    │  (Campaign Generation)      │
                                    │                             │
                                    └─────────────────────────────┘
```

## Component Structure

```
src/
├── features/
│   └── db-agent/
│       ├── components/
│       │   ├── agent-onboarding-chat.tsx     # Main chat interface component
│       │   ├── agent-placeholder-states.tsx  # Loading/error/starter UI states
│       │   ├── agent-empty-state.tsx         # Initial empty chat state
│       │   └── agent-campaign-interrupt.tsx  # Campaign form UI component
│       └── hooks/
│           ├── useDbAgentThreadId.ts         # Thread management hook
│           └── useOnboardingAgentChat.ts     # Chat state management hook
├── lib/
│   ├── adapters/
│   │   └── trpc/
│   │       └── routers/
│   │           └── db-chat-agent.ts          # tRPC router for agent
│   ├── core/
│   │   ├── controllers/
│   │   │   └── db-chat-agent.ts              # Controller for handling requests
│   │   ├── handlers/
│   │   │   └── db-chat-agent.ts              # Message handling utilities
│   ├── langgraph/
│   │   └── onboarding-agent/                 # LangGraph implementation
│   │       ├── index.ts                      # Core OnboardingAgent class
│   │       ├── schemas.ts                    # TypeScript and Zod schemas
│   │       ├── prompts.ts                    # System prompts for different nodes
│   │       ├── tools.ts                      # Agent tools
│   │       └── utils.ts                      # Helper utilities
│   └── extern/
│       └── index.ts                          # Service provider registration
```

## Implementation Details

### Main Components

1. **AgentOnboardingChat**
   - Entry point component in `agent-onboarding-chat.tsx`
   - Handles loading states and error conditions
   - Uses `useDbAgentThreadId` hook for thread management
   - Fetches business data using tRPC queries
   - Initializes the chat experience with appropriate state transitions

2. **AgentOnboardingChatUI**
   - Core chat interface component in `agent-onboarding-chat.tsx`
   - Manages message display and streaming content
   - Handles user interactions (send message, campaign callbacks)
   - Directly communicates with backend via tRPC mutations
   - Switches between normal chat and campaign form interfaces

3. **useDbAgentThreadId**
   - Internal hook for thread ID management
   - Maintains thread state in localStorage
   - Provides functions to generate new threads or retrieve existing ones
   - Tracks whether a user has an active thread

4. **useOnboardingAgentChat**
   - Primary hook managing chat state and interactions
   - Handles message sending, streaming, and state updates
   - Manages campaign interrupt state transitions
   - Provides callback functions for campaign form submissions

5. **AgentCampaignInterrupt**
   - Specialized form component that appears during campaign creation
   - Accepts initial data from the LLM for pre-filling fields
   - Handles submission of campaign parameters back to the chat flow
   - Provides UI for approving or modifying suggested campaign settings

### Data Flow

The campaign agent follows this flow:

1. User initiates chat through the starter screen
2. The `AgentOnboardingChat` component fetches necessary data and renders `AgentOnboardingChatUI`
3. User can:
   - Ask general questions handled via regular chat flow
   - Request campaign creation (via "Build me a campaign" button or direct message)
4. When campaign creation is requested:
   - The message is sent to the backend via tRPC
   - Backend processes the request and generates campaign suggestions
   - Response includes campaign parameters in structured format
   - Frontend detects the campaign state and shows `AgentCampaignInterrupt` component
5. User interacts with the campaign form to:
   - Review and modify suggested parameters
   - Submit the final campaign settings
   - Cancel the operation if needed
6. After submission:
   - Campaign data is sent back to the agent via callback
   - Backend processes the approved campaign
   - Conversation continues in chat mode with confirmation
   - Campaign is created in the database

### Campaign Interrupt Flow

A key feature of this implementation is the "interrupt" workflow for campaign creation:

```
Normal Chat ──> Campaign Request ──> Campaign Form Interrupt ──> Form Submission ──> Back to Chat
```

This is implemented through state management in `useOnboardingAgentChat`:

```typescript
const [stateInterrupt, setStateInterrupt] = useState<{
  llm_output: CampaignFormData;
} | null>(null);

// When a message is detected as a campaign request
useEffect(() => {
  if (lastMessage?.content?.includes('campaign_parameters')) {
    // Parse the campaign data
    const campaignData = parseCampaignData(lastMessage.content);
    
    // Trigger the interrupt
    setStateInterrupt({ llm_output: campaignData });
  }
}, [lastMessage]);
```

The campaign form interrupt is implemented in `AgentCampaignInterrupt` component, which:
1. Receives initial campaign parameters from the LLM
2. Provides form validation and modification capabilities
3. Submits the finalized parameters back to the chat flow via callback

### Backend Implementation

#### tRPC Router (lib/adapters/trpc/routers/db-chat-agent.ts)

The router defines the API endpoints for the campaign agent:

- `stream`: Mutation for streaming chat messages and campaign data
- `createCampaign`: Mutation for finalizing campaign creation
- Both validate inputs using Zod schemas and route to controller methods

#### Controller (lib/core/controllers/db-chat-agent.ts)

The controller handles:

- Processing chat messages and detecting campaign requests
- Formatting campaign data for the frontend
- Handling campaign creation once approved
- Streaming responses throughout the process

#### Message Handling (lib/core/handlers/db-chat-agent.ts)

This utility module provides:

- Constants for special message types
- Parser functions for extracting campaign data from messages
- Validation of message structure and content
- Helper functions to determine which messages should be rendered to users

```typescript
export const dbChatAgentHandler = {
  shouldRender: (messageId: string) => {
    // Hide system messages and internal processing messages
    return !messageId.includes('system') && !messageId.includes(DO_NOT_RENDER_PREFIX);
  },
  // Other utility functions
}
```

### LangGraph Implementation Details

The LangGraph implementation in the `src/lib/langgraph/onboarding-agent` directory is built around the `OnboardingAgent` class, which provides the core functionality for the campaign agent.

#### State Management (index.ts)

The agent uses LangGraph's state management system with two main annotation types:

```typescript
const ConfigurableAnnotation = Annotation.Root({
  businessId: Annotation<string>(),
})

export const OnboardingStateAnnotation = Annotation.Root({
  messages: Annotation<BaseMessage[]>({
    reducer: (x, y) => x.concat(y),
    default: () => [],
  }),
  nextRepresentative: Annotation<NodeRepresentativeType>({
    default: () => NODE_REPRESENTATIVES.RESPOND,
    reducer: (x, y) => y ?? x,
  }),
  campaignFeedback: Annotation<string>({
    default: () => '',
    reducer: (x, y) => y ?? x,
  }),
  generatedCampaign: Annotation<CampaignGenerate>({
    default: () => ({
      name: '',
      description: '',
      problem: {
        problem_id: '',
        the_problem: '',
      },
      target_customer: {
        business_data_id: '',
        the_customer: '',
        customer_description: '',
      },
    }),
    reducer: (x, y) => y ?? x,
  }),
})
```

This provides a structured way to track:
- Conversation messages
- Current conversation path
- Campaign feedback from users
- Generated campaign details

#### Node Implementation

The OnboardingAgent contains three main nodes that define the conversation flow:

1. **Support Node**: Handles general conversations and intent detection
```typescript
async support(
  state: typeof OnboardingStateAnnotation.State,
): Promise<typeof OnboardingStateAnnotation.Update> {
  const SYSTEM_TEMPLATE = getSupportSystemTemplate()
  const systemMessage = this.createMessage(SYSTEM_TEMPLATE, 'system', uuidv4())
  
  // Generate response to user question
  const trimmedMessages = await this.trimConversationMessages(state.messages)
  const supportResponse = await this.chatLLM.invoke([systemMessage, ...trimmedMessages])
  
  // Analyze if the user is requesting a campaign
  const CATEGORIZATION_SYSTEM_TEMPLATE = getCategorizationSystemTemplate()
  const CATEGORIZATION_HUMAN_TEMPLATE = getCategorizationHumanTemplate()
  const categorizationResponse = await this.chatLLM
    .withStructuredOutput(categorizationResponseSchema)
    .invoke([/* templates and messages */])
  
  return {
    messages: [supportResponse],
    nextRepresentative: categorizationResponse.nextRepresentative,
  }
}
```

2. **Campaign Node**: Generates campaign suggestions based on business data
```typescript
async campaign(
  state: typeof OnboardingStateAnnotation.State,
  config: RunnableConfig<typeof ConfigurableAnnotation.State>,
) {
  // Fetch business data from database
  const queryTool = new QuerySqlTool(this.db)
  const [businessInfo, businessProblems, businessData] = 
    await Promise.allSettled([/* database queries */])
  
  // Generate structured campaign suggestion
  const structuredResponse = await this.chatLLM
    .withStructuredOutput(campaignGenerateSchema)
    .invoke([/* messages with business context */])
  
  // Generate natural language explanation
  const reviewGeneratedCampaignResponse = await this.chatLLM
    .invoke([/* review messages */])
  
  return new Command({
    goto: NODES.REVIEW_CAMPAIGN,
    update: {
      messages: [reviewGeneratedCampaignResponse],
      generatedCampaign: structuredResponse,
    },
  })
}
```

3. **ReviewCampaign Node**: Handles user feedback on campaign suggestions
```typescript
async reviewCampaign(state: typeof OnboardingStateAnnotation.State) {
  const result = interrupt<CampaignFeedbackInterrupt, CampaignFeedbackResponse>({
    question: 'Do you like to proceed with this campaign?',
    llm_output: state.generatedCampaign,
  })

  if (result.response === CAMPAIGN_FEEDBACK_RESPONSES.IMPROVE) {
    return new Command({
      update: { campaignFeedback: result.feedback },
      goto: NODES.CAMPAIGN,
    })
  }
  
  if (result.response === CAMPAIGN_FEEDBACK_RESPONSES.APPROVED) {
    // Handle acceptance
  } else {
    // Handle rejection
  }
}
```

#### Graph Definition

The LangGraph is defined in the `graph()` method:

```typescript
graph() {
  const workflow = new StateGraph(OnboardingStateAnnotation, ConfigurableAnnotation)
    .addNode(NODES.SUPPORT, this.support.bind(this))
    .addNode(NODES.CAMPAIGN, this.campaign.bind(this))
    .addNode(NODES.REVIEW_CAMPAIGN, this.reviewCampaign.bind(this))
    .addEdge(START, NODES.SUPPORT)
    .addConditionalEdges(NODES.SUPPORT, async (state) => {
      if (state.nextRepresentative === NODE_REPRESENTATIVES.CAMPAIGN) {
        return NODES.CAMPAIGN
      }
      return END
    })
    .addEdge(NODES.CAMPAIGN, NODES.REVIEW_CAMPAIGN)
    .addConditionalEdges(NODES.REVIEW_CAMPAIGN, async (state) => {
      if (state.campaignFeedback) {
        return NODES.CAMPAIGN
      }
      return END
    })
    .addEdge(NODES.REVIEW_CAMPAIGN, END)

  return workflow
}
```

This creates a directed graph with the following flow:
1. Start → Support node (general conversation)
2. Support → Campaign node (if campaign intent detected) or End (general response)
3. Campaign → ReviewCampaign (show campaign for approval)
4. ReviewCampaign → Campaign (if feedback provided) or End (if approved/rejected)

#### Human-in-the-Loop Implementation

The implementation uses LangGraph's `interrupt()` function to create a human-in-the-loop approval workflow for campaigns:

```typescript
const result = interrupt<CampaignFeedbackInterrupt, CampaignFeedbackResponse>({
  question: 'Do you like to proceed with this campaign?',
  llm_output: state.generatedCampaign,
})
```

This allows for three possible responses:
- `CAMPAIGN_FEEDBACK_RESPONSES.IMPROVE`: User provides feedback and wants revisions
- `CAMPAIGN_FEEDBACK_RESPONSES.APPROVED`: User approves the campaign as is
- `CAMPAIGN_FEEDBACK_RESPONSES.REJECTED`: User rejects the campaign entirely

#### Prompt Templates

The implementation uses structured prompts for different nodes:

- Support node uses a general conversation prompt
- Campaign node uses prompts enriched with business data
- Categorization uses specialized prompts to detect campaign intent

This structured approach ensures consistent and appropriate responses at each stage.

### UI Components

The implementation includes several specialized UI components:

1. **AgentPlaceholderStates**
   - Loading, error, and starter states with appropriate messaging
   - Visual cues to guide users through the chat initiation process

2. **AgentEmptyState**
   - Initial state when a thread is created but no messages exist
   - Provides example queries and a direct "Build Campaign" button

3. **AgentCampaignInterrupt**
   - Form for campaign parameter review and modification
   - Validation of campaign parameters
   - Submission controls with loading states

### Client-Side State Management

Client-side state is managed through custom hooks:

1. **useDbAgentThreadId**
   - Uses local storage to persist thread IDs
   - Provides functions to create new threads or retrieve existing ones
   - Tracks whether an active thread exists

2. **useOnboardingAgentChat**
   - Manages the core chat state including messages and streaming
   - Handles message sending and receiving
   - Detects and manages campaign interrupt states
   - Provides callback functions for form submissions

### Integration with Business Data

The campaign agent integrates with business data through:

1. **Business Context**
   - Fetches business data via SQL queries
   - Uses data about:
     - Business information
     - Business problems
     - Target customer data
   - This data informs campaign suggestions

2. **Campaign Creation**
   - Integrates approved campaign parameters with business data
   - Creates campaigns linked to the specific business
   - Uses structured output with proper references to business problems and target customers

## Implementation Status

The Campaign Agent is fully implemented with the following features:

- ✅ Chat interface with message streaming
- ✅ Thread management and persistence
- ✅ Campaign parameter generation based on business data
- ✅ Interactive campaign form with validation
- ✅ Human-in-the-loop approval process
- ✅ Campaign creation and confirmation
- ✅ Error handling and loading states
- ✅ Business data integration 