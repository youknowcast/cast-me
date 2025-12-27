# AGENTS.md - Context & Summary for AI Agents

## Project Overview
**CastMe** is a Ruby on Rails application focused on personal/family organization. It provides features for calendar management, task tracking, planning, and capturing moments. The application is built to be responsive and interactive using modern Rails techniques (Hotwire).

## Tech Stack
### Backend
-   **Framework**: Ruby on Rails 7.0
-   **Language**: Ruby (version specified in `.ruby-version`)
-   **Database**: SQLite (configured for Development, Test, and Production in `config/database.yml`)
    -   *ORM*: Active Record

### Frontend
-   **Templating**: Slim (`.slim`) files instead of standard ERB.
-   **CSS Framework**: Tailwind CSS (via `tailwindcss-rails`) + DaisyUI.
-   **Interactivity**: Hotwire (Turbo + Stimulus).
-   **Scripting**: TypeScript (compiled via `esbuild`).
-   **Icons**: Likely FontAwesome or Heroicons (inferred from usage patterns generally, to be verified in views).

## Key Domain Models
-   **User**: Authentication managed via Devise.
-   **Plan**: Represents calendar events. Supports multiple **participants** (users) via `PlanParticipant`. Tracks `last_edited_by_id`.
-   **Task**: Represents actionable items, categorized by priority.
-   **PlanParticipant**: Junction model for Users and Plans, tracking `status` (joined, declined, pending).
-   **Family**: Represents groups of users for shared visibility.

## Architecture Highlights
-   **Mobile Optimization**: Uses a fixed Bottom Navigation Bar (`_bottom_nav.html.slim`) on mobile instead of the sidebar. Content stacks vertically on smaller screens.
-   **Calendar Interactivity**:
    -   Uses **Turbo Frames** (`daily_details`) for sectional updates.
    -   **Unified Interaction**: `calendar_interaction_controller.ts` manages both date selection and user filtering, ensuring state (date, user, scope) is preserved.
    -   **Grouping**: Daily views group items by User.
-   **Data Consistency**: Uses `CalendarData` concern in controllers to standardize schedule fetching across different actions (Create/Update/Filter).
-   **Side Panel**: A dedicated side panel container (`#side-panel`) exists in the layout for dynamic content loading (e.g., forms).

## Development Guidelines
1.  **Views**: Always use **Slim** syntax. Do not create `.erb` files.
2.  **Styling**: Use **Tailwind CSS** + **DaisyUI**.
3.  **JavaScript**:
    -   Standard Stimulus setup: `application.js` imports `controllers/index.js`, which uses `controllers/application.js` for the instance.
    -   Use **TypeScript** (`.ts`) for controllers.
    -   Avoid inline JavaScript.
4.  **Testing**: Use **RSpec** (`spec/`).

## Key Configuration Files
-   `Procfile.dev`: Runs Rails and `yarn build --watch` for JS.
-   `package.json`: Build script uses `esbuild` targeting `app/javascript/application.js`.
-   `db/Schemafile`: Database schema managed via **Ridgepole**.
-   `config/routes.rb`: definition of available endpoints.

