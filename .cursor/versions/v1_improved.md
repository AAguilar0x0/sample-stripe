# User Flows

## Authentication
- Register using work email
    - User enters work email
    - System sends a magic link for authentication
    - User clicks the magic link and is redirected to the `Onboarding Page`
- Login using work email when domain is not yet set up
    - System sends a magic link for authentication
    - User clicks the magic link and is redirected to the `Onboarding Page`

## Onboarding
- Step 1: Business Information
    - System scrapes the `domain` to retrieve business information
    - System retrieves business data of type "features" with the following fields:
        - title
        - description
    - UI displays the business data list
    - User clicks `Next` to save the business data associated with their business
- Step 2: Business Problems
    - System generates 10 `business problems` using the retrieved `business information` and `business_data`
    - UI displays the 10 `business problems` with 3 pre-selected
    - User can select a maximum of 3 `business problems`
    - User clicks `Next` to be redirected to the `Chat (Admin Interface)`
    - Background processing:
        - System saves the generated business problems in the database as:
            - Problems: An independent entity storing problems only
            - Business Problems: A dependent entity associating businesses with problems
                - Selected `business problems` have the field `tracked` set to true

## Chat (Admin Interface)
- Flow variants:
    - Regular Flow
        - UI displays a CTA labeled `Create Campaign` that creates a new chat thread
    - From Onboarding
        - UI displays a `Build a Campaign` action button
        - User clicking the button automatically sends a message in the chat to initiate the Chat agent
        - Chat agent processes the request and displays the Agent Campaign Form
- Agent Campaign Form
    - Form sections:
        - Campaign Problem
            - Displays the problem used to create generated campaign pages
            - Uses pre-existing business problems by default, but is customizable if the user wants to create a custom campaign
        - Campaign Details
            - Title: The campaign title
            - Target Customer: The target audience for generated campaign pages
                - Uses pre-existing `business_data` of `type:target_customer` by default, but is customizable
            - Additional Instructions (Optional): Can be added as payload when generating campaign pages
        - Campaign Output
            - Start Date: When the campaign begins
                - Date and time, defaults to next day at 12:00 midnight
            - End Date: When the campaign ends
                - Date, defaults to the day after the start date
                - NOTE: "The campaign end date must be within 3 months of the start date"
            - Frequency: How often pages are generated, either `Daily` or `Weekly`
    - Form handling options:
        - Save Campaign
            - Creates new database records for:
                - Campaign
                - Business Data (if custom)
                - Business Problem (if custom)
            - Pre-generates campaign pages according to `Campaign Pages Calculation`
                - State is set to `scheduled`
                - Type is `solution`
            - Redirects user to the `Content Calendar (Admin Interface)`
        - Reject
            - Closes the Agent Campaign Form
            - Sends a message to the chat indicating the user does not wish to proceed

## Content Calendar (Admin Interface)
- UI elements:
    - `Add` button in the admin interface header
        - Redirects to Campaign creation flow (Step 1)
            - User selects a single business problem
            - User can proceed with:
                - Cancel: Returns to the Initial Screen for Content Calendar
                - Next: Proceeds to Campaign Details Step (Step 2)
        - Campaign Details Step (Step 2)
            - Displays:
                - Campaign Problem: The problem used to create generated campaign pages
                - Campaign Details:
                    - Title: The campaign title
                    - Target Customer: The audience for generated campaign pages
                    - Additional Instructions (Optional): Can be added as payload when generating campaign pages
                - Campaign Output:
                    - Start Date: When the campaign begins
                        - Date and time, defaults to next day at 12:00 midnight
                    - End Date: When the campaign ends
                        - Date, defaults to the day after the start date
                        - NOTE: "The campaign end date must be within 3 months of the start date"
                    - Frequency: How often pages are generated, either `Daily` or `Weekly`
            - User options:
                - Back: Return to the previous problem selection step
                - Create: Create the Campaign record similar to Agent Campaign Creation and return to the Content Calendar initial screen
    - List of created campaigns
        - For each campaign list item, users can:
            - Edit: Access the campaign edit screen
            - Delete: Permanently remove the campaign
            - View Campaign Pages: See a screen showing all campaign pages

## Vectle Profile (Admin Interface)
- Created after successful user onboarding
- Form fields:
    - Business Name
    - Business Description
    - Profile handle: A unique identifier used as a slug for public profile access
    - Call to Action Text: Text displayed on the CTA button of the public profile page
    - Call to Action Link: URL where users are redirected when clicking the CTA button
    - Brand color: Used to customize the public profile page (e.g., CTA button color)
    - Business Logo: Displayed in the public profile page header
- User can update values by editing and clicking the `Save` button in the admin interface header

## Business Data (Admin Interface)
- UI elements:
    - List of business data items
        - Each item:
            - Displays business data information
            - Can be edited by clicking the edit icon
                - Edit form state allows users to:
                    - Save
                    - Delete
                    - Cancel
    - Add button in the admin interface header
        - Prepends a temporary list item in edit form state
            - User options:
                - Save
                - Delete
                - Cancel
    - Filter list dropdown with options:
        - All
        - Feature
        - Solution
        - Product
        - Service
        - Target Customer

## Catalog Pages (Admin Interface)
- UI elements:
    - List of Page items
        - Sorted by most recent
        - Each Page List Item:
            - Displays page information
            - Can be selected to update the Page Content Preview UI
            - Provides buttons for:
                - Edit: Redirects to Page Edit Screen (errors if page is in scheduled state)
                - External link
    - Add button in admin interface header
        - Redirects to page creation flow
            - Problem Selection Step (Step 1)
                - Search/Create Problem UI:
                    - Users can filter the page list by query
                    - If results are empty, users can create a new problem
                        - System generates an appropriate business problem
                        - The generated problem is auto-selected
                - Displays a list of problems
                - User must select one problem
                - User can click `Create` or `Cancel`
                    - `Create`: Redirects to a generating state screen, then to Catalog Page initial screen after completion
                    - `Cancel`: Returns to previous screen

## Page Content Preview
- Previews public page content
- Two modes:
    - Profile Page (default)
    - Catalog Page (displayed when a catalog page is selected in Catalog Pages Admin Interface)

## Profile (Public Page Content)
- Accessible via `vectle.com/@handle`
- Content sections:
    - About Section: Profile Description
    - Key Features Section: List of `business_data` items
    - Pages Section: Visible when profile has `published` pages

## Catalog Page (Public Page Content)
- Accessible via `vectle.com/@handle/catalog/<slug>`
- Slug automatically updates when page title changes
- Content sections:
    - Title
    - Description
    - Updated date
    - Content
    - Profile Section:
        - Profile Information
        - Learn More link: Redirects to the public profile page
    - Key Features Section:
        - List of associated `business_data` items
        - See all features link: Redirects to the public profile page

## Footer (Admin Interface)
- Content elements:
    - Profile Information
    - Upgrade Subscription redirect button:
        - Redirects to Subscription (Admin Interface)
        - Shows:
            - List of Subscription Plans
                - Each plan item displays:
                    - Plan information
                    - `Select Plan` button: Redirects to stripe checkout session
                    - Active plans have a distinct UI state
            - Subscription Plan tabs:
                - Annual
                - Monthly
                - Filters the displayed plans
    - Account redirect button:
        - Redirects to Account (Admin Interface)
        - Shows:
            - Email
            - For subscribed users:
                - `Manage Subscription` button: Redirects to stripe portal for subscription management
            - For non-subscribed users:
                - Upgrade button: Redirects to Subscription (Admin Interface)
    - Logout

## Subscription
- Types:
    - Free
    - Business
    - Growth
- Constraints:
    - Free Tier: Maximum 3 pages
    - Business Tier: Maximum 500 pages
    - Growth Tier: Maximum 5000 pages
    - Users can only create/add Catalog Pages up to their tier limit
    - Users can only create campaigns that generate pages within their tier limit
    - Downgrade:
        - Put all their most recent pages, down to their new page count limit, into 'unpublished' state

## High Impact Features
- Onboarding
- Campaign Chat Agent
- Campaign Page generation
- Subscription
- Catalog Page Creation
- View Public Page Content
    - Profile Page
    - Catalog Page
- Vectle Profile Mutation
- Business Data Mutation 