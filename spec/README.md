# Spec organization

Specs remain grouped by RSpec type first so Rails type inference continues to work. Within each type, files are grouped by application feature.

## Feature map

| Feature | Request specs | Model/helper specs | Service specs | Current coverage |
|---|---|---|---|---|
| Authentication | `requests/authentication/` | `models/accounts/` | - | Protected pages and mutation endpoints reject signed-out users |
| Calendar and plans | `requests/calendar/` | `models/calendar/`, `helpers/calendar/` | `services/calendar/` | My/family filtering, monthly list, plan create/update/delete, participation updates, anniversaries and holidays |
| Tasks and templates | `requests/tasks/` | `models/tasks/` | - | Task create/update/delete/toggle, regular tasks, everyday templates and task templates |
| Settings | `requests/settings/` | `models/accounts/user_notification_setting_spec.rb` | - | Birthday and notification settings, missing avatar upload |
| Family communication | `requests/communication/` | - | `services/notifications/family_call_notification_service_spec.rb` | Family call authorization, defaults and notification payloads |
| Weekly summary | `requests/weekly_summary/` | - | `services/notifications/weekly_task_summary_notification_service_spec.rb` | Family task aggregation, date boundaries and signed-out access |
| Scheduled notifications | `requests/notifications/api/` | `models/accounts/user_notification_setting_spec.rb` | `services/notifications/` | API token validation, schedule matching, message generation and OneSignal requests |
| Shared presentation | - | `helpers/shared/` | - | URL linkification and escaping |

Factories remain in `spec/factories/` because they are shared across features.

## Important remaining gaps

1. Browser-level system specs for Turbo and Stimulus interactions are not present.
2. Successful avatar resizing and image-processing failure branches are not covered.
3. Plan notification behavior does not have a direct service spec.
4. Mobile UI and call helper HTML generation are not covered directly.
5. New, edit and show form endpoints have limited direct request coverage.

When adding a feature, add its spec under the matching type and feature directory, then update this map when the coverage boundary changes.
