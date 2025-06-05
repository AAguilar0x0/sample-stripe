## Campaign Launch Admin View Components

### Main Components 
* `AgentPlaceholderProblemSelectScreen` - The main component that displays the initial problem selection interface with "Turn On Your Content Engine" heading and problem list
* `AgentProblemItem` - Individual problem item component that displays a problem and its associated campaigns
* `CampaignList` - Component that shows campaigns associated with a problem, with both expanded and compact views
* `AgentCampaignCard` - Card component for displaying and editing campaign details
* `AgentCampaignInterrupt` - Wrapper component that handles the campaign creation flow and form state
* `AgentCampaignFormFields` - Form fields component for campaign creation with accordion sections

### Form Components
* `AgentCampaignAddFormProvider` - Form provider that handles campaign creation submission logic
* `AgentCampaignAddFormHandler` - Handles form initialization and state management
* `BusinessDataSelectionList` - Component for selecting business problems/data
* `ProblemSelectionItem` - Individual problem selection item in the list

### Hooks and Data Management
* `useAgentCampaignFormData` - Custom hook that manages campaign form data and fetches necessary business data
* `useFormContext` - React Hook Form context for form state management
* `trpc.businessProblems.getBusinessProblems` - tRPC query hook for fetching business problems
* `trpc.campaigns.getCampaignsByProblemId` - tRPC query hook for fetching campaigns
* `trpc.businessData.getBusinessDataByType` - tRPC query hook for fetching business data
* `useAdminTabQueryState` - Hook for managing admin tab state

### Key Features
* Problem selection interface with campaign counts
* Campaign creation form with editable sections:
  - Target Problem
  - Customer Information
  - Campaign Details
  - Execution Settings
* Integration with business data and personas
* Form validation and error handling
* Subscription gating for campaign creation
* Loading states and skeletons for better UX

## Add Problem Feature Implementation Plan

### File Structure
```
src/features/db-agent/
├── components/
│   ├── agent-placeholder-states.tsx        # Existing main component
│   ├── agent-problem-create-form.tsx       # New form component
│   └── agent-problem-create-form-pure.tsx  # New pure form component
├── schemas.ts                              # Existing schemas file
└── hooks/
    └── use-problem-create.ts               # New hook for form logic
```

### Available Components and Services
1. Existing tRPC Mutation:
   - `trpc.businessProblems.createBusinessProblems` - Creates new business problems
   - Input schema: `createBusinessProblemsDTOSchema` with businessId and array of problems

2. Reusable UI Components:
   - Form components from existing problem forms
   - Existing validation schemas in `business/schemas.ts`
   - Card component matching existing problem card styles

### Implementation Plan

1. **UI Components and Files Needed:**
   - Update `src/features/db-agent/components/agent-placeholder-states.tsx` to include styled "add a new one" text
   - Create `src/features/db-agent/components/agent-problem-create-form-pure.tsx` for the pure form component
   - Create `src/features/db-agent/components/agent-problem-create-form.tsx` for the wrapper component
   - Create `src/features/db-agent/hooks/use-problem-create.ts` for form logic and API integration

2. **Data Flow:**
   ```
   Click "add a new one" -> Insert Form Card at Top -> Form Input -> 
   Save: createBusinessProblems Mutation -> Refresh Problem List
   Cancel: Remove Form Card
   ```

3. **Required Features:**
   - Form validation (min 1 character for problem text)
   - Loading state during submission
   - Error handling with toast notifications
   - Automatic list refresh after adding
   - Cancel functionality to remove form card
   - Save button with loading state
   - Match existing card styling for consistency

4. **Implementation Steps:**
   1. Update `src/features/db-agent/components/agent-placeholder-states.tsx`:
      ```tsx
      <p>
        Select a problem or{' '}
        <button 
          onClick={handleAddNew}
          className="text-app-blue font-semibold hover:underline"
        >
          add a new one
        </button>
      </p>
      ```
   
   2. Create `src/features/db-agent/components/agent-problem-create-form-pure.tsx`:
      ```tsx
      import { Button } from '@/components/ui/button'
      import { Input } from '@/components/ui/input'
      import type { AgentProblemCreateFormProps } from '../types'

      export function AgentProblemCreateFormPure({
        register,
        onCancel,
        isSubmitting,
        handleSubmit,
      }: AgentProblemCreateFormProps) {
        return (
          <div className="rounded-lg border border-border bg-background p-2">
            <form onSubmit={handleSubmit}>
              <Input 
                placeholder="Enter the problem your business solves"
                {...register('problem')}
              />
              <div className="flex justify-end gap-2 mt-2">
                <Button variant="outline" onClick={onCancel}>
                  Cancel
                </Button>
                <Button type="submit" isLoading={isSubmitting}>
                  Save
                </Button>
              </div>
            </form>
          </div>
        )
      }
      ```

   3. Create `src/features/db-agent/components/agent-problem-create-form.tsx`:
      ```tsx
      import { useProblemCreate } from '../hooks/use-problem-create'
      import { AgentProblemCreateFormPure } from './agent-problem-create-form-pure'

      export function AgentProblemCreateForm({ 
        onCancel,
        onSuccess 
      }: { 
        onCancel: () => void
        onSuccess: () => void 
      }) {
        const { register, handleSubmit, isSubmitting } = useProblemCreate({
          onSuccess
        })

        return (
          <AgentProblemCreateFormPure
            register={register}
            onCancel={onCancel}
            isSubmitting={isSubmitting}
            handleSubmit={handleSubmit}
          />
        )
      }
      ```

   4. Create `src/features/db-agent/hooks/use-problem-create.ts`:
      ```tsx
      import { useForm } from 'react-hook-form'
      import { trpc } from '@/lib/trpc/client'
      import { useCatchErrorToast } from '@/common/hooks'
      import { createBusinessProblemsDTOSchema } from '@/lib/core/dtos/business-problems-dtos'
      import type { z } from 'zod'

      type ProblemCreateForm = z.infer<typeof createBusinessProblemsDTOSchema>

      export function useProblemCreate({ onSuccess }: { onSuccess: () => void }) {
        const catchError = useCatchErrorToast()
        const createProblemMut = trpc.businessProblems.createBusinessProblems.useMutation()

        const form = useForm<ProblemCreateForm>({
          defaultValues: {
            problem: ''
          }
        })

        const onSubmit = async (data: ProblemCreateForm) => {
          await catchError(
            async () => {
              await createProblemMut.mutateAsync(data)
              onSuccess()
            },
            {
              description: 'Problem created successfully'
            }
          )
        }

        return {
          register: form.register,
          handleSubmit: form.handleSubmit(onSubmit),
          isSubmitting: form.formState.isSubmitting
        }
      }
      ```

5. **Location in Codebase:**
   All new files will be in the `src/features/db-agent/` directory following the structure shown above, maintaining consistency with existing patterns and component organization.
