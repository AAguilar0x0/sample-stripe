# Content Calendar Implementation Plan

## Overview

The Content Calendar feature enables businesses to schedule page creation so their catalogs build gradually and stay fresh. Businesses can define campaigns with associated business data and specify how many pages they want to generate and publish on given days of the week. This creates a page "queue" where titles are generated at scheduling time, but full content is only generated at the time of publishing, ensuring content freshness.

## Requirements

1. Campaign Management

   - Create and manage campaigns with name, description, and business data
   - Select specific business data to use for page generation
   - Define page generation prompts for content creation
   - Support for all page types in campaigns

2. Page Scheduling

   - Define recurring scheduling patterns (daily, weekly, monthly)
   - Specify number of pages per occurrence (e.g., 3 pages every day M-F, 10 pages every Monday)
   - Bulk schedule pages with automatic title generation
   - Individual page publish date/time editing

3. Page Queue

   - Generate page titles at scheduling time
   - Generate full page content only at time of publish
   - Track page status (draft, pending, published)
   - Option to generate specific page content ahead of time

4. Admin Interface

   - Campaign index view with list of all campaigns
   - Campaign details view showing all scheduled pages
   - Status indicators for each page (published/pending)
   - Publish date/time display
   - Page title display

5. Calendar Interface
   - Visual calendar showing scheduled content
   - Filtering by campaign and status
   - Drag-and-drop rescheduling
   - Queue visualization

## Database Structure

### Table Structure

**`campaigns`**

- `id`: UUID (Primary Key)
- `name`: Text - Campaign name
- `description`: Text - Campaign description
- `page_count`: Integer - Number of pages to generate
- `business_data_id`: UUID (Foreign Key) - Reference to business data for content generation
- `prompt`: Text - Generation prompt template
- `schedule_date`: Timestamp - Current single schedule date
- `schedule_patterns`: JSONB - Scheduling pattern configuration (daily, weekly, monthly)
- `page_queue`: JSONB - Queue of scheduled pages with metadata
- `created_at`: Timestamp
- `updated_at`: Timestamp
- `user_id`: UUID (Foreign Key) - Owner of the campaign

## Implementation Plan

### Phase 1: Database Schema & Core Infrastructure

**Goal:** Set up the database schema, repositories, and core infrastructure to support campaign scheduling and page queues

#### Files to Modify:

1. **`src/lib/extern/db/supabase/database.types.ts`**

   - Update campaigns schema with new fields for scheduling and page queues
   - Add JSON schema for storing scheduling patterns and page queue data

2. **`src/lib/core/dtos/campaign.ts`**

   - Enhance campaign DTO with scheduling fields and patterns
   - Add campaign schedule types (daily, weekly, monthly)
   - Add page queue types and status definitions
   - Update Zod schemas to include scheduling fields and validations

3. **`src/lib/extern/db/supabase/campaign-repo.ts`**

   - Add methods for managing campaign schedules
   - Implement pattern definition methods
   - Add schedule calculation utilities
   - Add recurring schedule management
   - Add page queue management operations
   - Add schedule optimization utilities

4. **`src/lib/core/controllers/campaigns.ts`**

   - Add scheduling business logic
   - Add methods for generating page titles
   - Add methods for calculating publish dates based on patterns
   - Add handling for recurring schedules
   - Add page queue management methods
   - Add page content generation logic with business data integration
   - Add content optimization strategies
   - Add schedule analysis and recommendations

5. **`src/lib/adapters/trpc/routers/campaigns.ts`**

   - Add procedures for schedule management
   - Add procedures for page queue operations
   - Add procedures for content generation
   - Add procedures for schedule optimization
   - Update existing procedures to accommodate new schema

6. **`src/lib/adapters/trpc/routers/index.ts`**

   - Update router configuration if needed

7. **`src/lib/extern/db/supabase/init.ts`**
   - Add runtime checks for required database structure
   - Log warnings if expected tables/columns are missing
   - Provide schema upgrade instructions for developers

#### Validation:

- Test repository CRUD operations against the updated schema
- Validate scheduling pattern generation
- Test page queue management
- Verify title generation
- Create schema validation tests

### Phase 2: Campaign Scheduling & Page Queue

**Goal:** Implement campaign scheduling UI and page queue management

#### Files to Create:

1. **`src/features/content-calendar/components/schedule-pattern-selector.tsx`**

   - UI for setting scheduling patterns
   - Day selection for weekly schedules
   - Date selection for monthly schedules
   - Pages per occurrence setting

2. **`src/features/content-calendar/components/page-queue-manager.tsx`**

   - UI for managing the page queue
   - Page title display and editing
   - Publish date editing
   - Status management

3. **`src/features/content-calendar/components/bulk-schedule-form.tsx`**

   - Form for bulk scheduling pages
   - Pattern selection
   - Date range selection
   - Pages per occurrence setting

4. **`src/features/content-calendar/hooks/use-campaign-schedule.ts`**

   - Custom hook for schedule management
   - Pattern calculations
   - Date utilities

5. **`src/features/content-calendar/hooks/use-page-queue.ts`**
   - Custom hook for page queue management
   - Status tracking
   - Filtering and sorting

#### Files to Modify:

1. **`src/features/content-calendar/schemas.ts`**

   - Add schemas for scheduling patterns
   - Add schemas for page queue management
   - Update existing campaign schemas

2. **`src/features/content-calendar/components/campaign-add-flow.tsx`**

   - Integrate scheduling pattern selector
   - Add bulk scheduling functionality
   - Enhance business data selection

3. **`src/features/content-calendar/components/campaign-edit-flow.tsx`**

   - Add page queue management
   - Integrate schedule editing
   - Add individual page editing

4. **`src/features/content-calendar/components/campaign-details-step.tsx`**

   - Add scheduling options
   - Enhance prompts for page generation
   - Add page count management

5. **`src/features/content-calendar/hooks.ts`**
   - Add shared hook functionality for schedule management
   - Update existing hooks to support new scheduling features

### Phase 3: Admin Interface & Content Generation

**Goal:** Implement admin interface for campaign and page management, and content generation system

#### Files to Create:

1. **`src/features/content-calendar/components/campaign-table.tsx`**

   - Enhanced table of all campaigns
   - Filtering and sorting options
   - Action buttons
   - Status indicators

2. **`src/features/content-calendar/components/campaign-detail-view.tsx`**

   - Comprehensive campaign details
   - Tab-based interface for different aspects
   - Metrics and summary

3. **`src/features/content-calendar/components/page-queue-table.tsx`**

   - Table of all pages in queue
   - Status filters
   - Date filtering
   - Bulk actions

4. **`src/features/content-calendar/components/page-preview.tsx`**
   - Preview of generated page content
   - Edit options
   - Publish controls

#### Files to Modify:

1. **`src/features/content-calendar/components/campaign-list.tsx`**

   - Replace with enhanced campaign table
   - Add filtering and action options
   - Show scheduling information

2. **`src/features/content-calendar/content-calendar-content.tsx`**
   - Update to include new views
   - Add tabs for different content types
   - Enhance navigation
   - Add page queue management
   - Add content generation controls

### Phase 4: Calendar View & Advanced Management

**Goal:** Implement calendar view and advanced campaign management features

#### Files to Create:

1. **`src/features/content-calendar/components/calendar-view.tsx`**

   - Monthly calendar view of scheduled pages
   - Color coding by campaign
   - Status indicators
   - Day/week/month toggles

2. **`src/features/content-calendar/components/calendar-day-detail.tsx`**

   - Detail view of a specific day
   - List of scheduled pages
   - Quick actions
   - Metrics

3. **`src/features/content-calendar/components/drag-drop-scheduler.tsx`**

   - Drag and drop interface for page rescheduling
   - Visual feedback
   - Conflict detection

4. **`src/features/content-calendar/hooks/use-calendar-data.ts`**
   - Prepare data for calendar display
   - Group by date and campaign
   - Calculate status summaries

#### Files to Modify:

1. **`src/features/content-calendar/content-calendar-content.tsx`**

   - Add calendar view option
   - Implement view switching
   - Add date navigation
   - Add filter controls

2. **`src/features/content-calendar/hooks.ts`**
   - Add calendar view state
   - Add date range selection
   - Enhance query params

#### Validation:

- Test calendar visualization
- Verify drag-and-drop functionality
- Test date navigation
- Validate view switching
- Check performance with many events

## Directory Structure

```
src/
├── features/
│   └── content-calendar/
│       ├── components/
│       │   ├── campaign-table.tsx
│       │   ├── campaign-detail-view.tsx
│       │   ├── campaign-list.tsx
│       │   ├── campaign-add-flow.tsx
│       │   ├── campaign-edit-flow.tsx
│       │   ├── campaign-details-step.tsx
│       │   ├── schedule-pattern-selector.tsx
│       │   ├── page-queue-manager.tsx
│       │   ├── page-queue-table.tsx
│       │   ├── bulk-schedule-form.tsx
│       │   ├── page-preview.tsx
│       │   ├── calendar-view.tsx
│       │   ├── calendar-day-detail.tsx
│       │   └── drag-drop-scheduler.tsx
│       ├── hooks/
│       │   ├── use-campaign-schedule.ts
│       │   ├── use-page-queue.ts
│       │   └── use-calendar-data.ts
│       ├── content-calendar-content.tsx
│       └── schemas.ts
├── lib/
│   ├── core/
│   │   ├── dtos/
│   │   │   └── campaign.ts
│   │   └── controllers/
│   │       └── campaigns.ts
│   │
│   ├── adapters/
│   │   └── trpc/
│   │       └── routers/
│   │           ├── campaigns.ts
│   │           └── index.ts
│   └── extern/
│       └── db/
│           └── supabase/
│               ├── campaign-repo.ts
│               └── database.types.ts
```

## Resources

- **Required Resources**:
  - 1 Full-stack Developer
  - 1 UI/UX Designer for admin and calendar interfaces
  - Design assets for calendar components

## Dependencies and Risks

### Dependencies

- Next.js App Router
- tRPC setup
- Supabase database
- Shadcn UI components
- React Hook Form
- Zod validation
- Date-fns or similar date library
- React DnD for drag-and-drop functionality
- Business Data generation capability

### Risks

- Content generation quality: Ensure business data is properly utilized
- Performance with large page queues: Implement pagination and optimization
- Scheduling complexity: Start with simple patterns and expand gradually
- Calendar performance: Implement virtualization for large datasets

## Future Enhancements

1. **Advanced Content Generation**:

   - AI-powered title suggestions
   - Content quality predictions
   - Automated SEO optimization

2. **Content Performance Analytics**:

   - Page view tracking
   - Engagement metrics
   - Schedule optimization based on performance

3. **Integration with External Platforms**:
   - Social media scheduling
   - Email campaign coordination
   - RSS feed generation

## Success Metrics

- Scheduled Page Count: Average of 10+ pages scheduled per business
- Publication Rate: >95% of scheduled pages published on time
- User Engagement: >80% of businesses using the calendar weekly
- Content Freshness: Decrease in content age by 30%
