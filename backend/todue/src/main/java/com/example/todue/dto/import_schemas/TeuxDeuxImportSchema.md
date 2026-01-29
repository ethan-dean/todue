# TeuxDeux Import Schema

## Overview
This document describes the JSON structure exported from TeuxDeux and how it maps to Todue's database schema.

## TeuxDeux JSON Structure

```json
{
  "workspaces": [
    {
      "id": number,
      "title": string,
      "timezone": string,                    // e.g., "America/New_York"
      "is_default": boolean,
      "custom_color": string,                // hex color without #, e.g., "007718"
      "include_fun": boolean,
      "position": number,
      "created_at": string,                  // ISO 8601 format

      "calendar_todos": [                    // Daily todos (maps to Todue's todos table)
        {
          "id": number,
          "text": string,
          "done": boolean,                   // maps to is_completed
          "current_date": string,            // YYYY-MM-DD, maps to assigned_date
          "position": number,
          "recurring_todo_id": number|null,  // links to recurring_todos
          "details": string|null,            // additional notes (Todue doesn't have this)
          "highlight_identifier": string|null,
          "total_days_swept": number,        // rollover count
          "workspace_id": number,
          "created_at": string,
          "updated_at": string
        }
      ],

      "recurring_todos": [                   // Maps to Todue's recurring_todos table
        {
          "id": number,
          "text": string,
          "start_date": string,              // YYYY-MM-DD
          "position": number,
          "recurrence_rule": string,         // iCal RRULE format (see below)
          "highlight_identifier": string|null,
          "created_at": string,
          "updated_at": string
        }
      ],

      "list_sets": [                         // Groups of lists (maps to Todue's later_list_groups)
        {
          "id": number,
          "name": string,                    // e.g., "Free Time To-Do's", "Lists"
          "position": number,
          "workspace_id": number,
          "created_at": string,
          "updated_at": string,

          "lists": [                         // Individual lists (maps to Todue's later_lists)
            {
              "id": number,
              "uuid": string,
              "name": string,                // e.g., "Grocery list", "Project Ideas"
              "position": number,
              "created_at": string,
              "updated_at": string,

              "todos": [                     // List items (maps to Todue's later_list_items)
                {
                  "id": number,
                  "text": string,
                  "done": boolean,
                  "position": number,
                  "details": string|null,
                  "current_date": null,      // Always null for list items
                  "highlight_identifier": string|null,
                  "recurring_todo_id": null, // Always null for list items
                  "total_days_swept": number,
                  "workspace_id": number,
                  "created_at": string,
                  "updated_at": string
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Recurrence Rule Format

TeuxDeux uses iCal RRULE format:

```
DTSTART:20251003T000000
RRULE:FREQ=DAILY;UNTIL=20260521T000000
```

### Frequency Types
- `FREQ=DAILY` → Todue: DAILY
- `FREQ=WEEKLY` → Todue: WEEKLY
- `FREQ=WEEKLY` with interval 2 → Todue: BIWEEKLY (need to check for INTERVAL=2)
- `FREQ=MONTHLY` → Todue: MONTHLY
- `FREQ=YEARLY` → Todue: YEARLY

### Rule Components
- `DTSTART` - Start date/time
- `FREQ` - Frequency (DAILY, WEEKLY, MONTHLY, YEARLY)
- `UNTIL` - End date (maps to Todue's end_date)
- `INTERVAL` - Repeat interval (e.g., INTERVAL=2 for biweekly)
- `BYMONTHDAY` - Day of month for monthly recurrence

## Mapping to Todue Database

### calendar_todos → todos
| TeuxDeux Field | Todue Field | Notes |
|----------------|-------------|-------|
| id | - | Generate new ID |
| text | text | Direct mapping |
| done | is_completed | Direct mapping |
| current_date | assigned_date | Direct mapping |
| current_date | instance_date | Same as assigned_date for non-recurring |
| position | position | Direct mapping |
| recurring_todo_id | recurring_todo_id | Need to map to new IDs |
| total_days_swept | is_rolled_over | Convert: > 0 means true |
| created_at | created_at | Parse ISO 8601 |
| updated_at | updated_at | Parse ISO 8601 |
| details | - | Todue doesn't support (discard or append to text) |

### recurring_todos → recurring_todos
| TeuxDeux Field | Todue Field | Notes |
|----------------|-------------|-------|
| id | - | Generate new ID, keep mapping for todo references |
| text | text | Direct mapping |
| start_date | start_date | Direct mapping |
| position | position | Direct mapping |
| recurrence_rule | pattern_type | Parse RRULE to extract FREQ |
| recurrence_rule (UNTIL) | end_date | Extract from RRULE |
| created_at | created_at | Parse ISO 8601 |
| updated_at | updated_at | Parse ISO 8601 |

### list_sets → (no direct equivalent, flatten into later_lists)
TeuxDeux has a two-level hierarchy (list_sets → lists), but Todue has a flat list structure.
Option 1: Ignore list_sets, import lists directly
Option 2: Prepend list_set name to list name (e.g., "Free Time To-Do's: Project Ideas")

### lists → later_lists
| TeuxDeux Field | Todue Field | Notes |
|----------------|-------------|-------|
| id | - | Generate new ID |
| name | name | Direct mapping (or prepend list_set name) |
| position | position | Re-calculate across all list_sets |
| created_at | created_at | Parse ISO 8601 |
| updated_at | updated_at | Parse ISO 8601 |

### list todos → later_list_items
| TeuxDeux Field | Todue Field | Notes |
|----------------|-------------|-------|
| id | - | Generate new ID |
| text | text | Direct mapping |
| done | is_completed | Direct mapping |
| position | position | Direct mapping |
| created_at | created_at | Parse ISO 8601 |
| updated_at | updated_at | Parse ISO 8601 |

## Import Considerations

1. **ID Mapping**: Generate new IDs for all entities, maintain a mapping table during import to resolve recurring_todo_id references.

2. **Timezone**: TeuxDeux stores timezone per workspace. Todue stores timezone per user. Use the imported timezone to set/update user's timezone.

3. **Multiple Workspaces**: TeuxDeux supports multiple workspaces, Todue doesn't. Options:
   - Import only the default workspace (is_default: true)
   - Import all workspaces, merging into single user account
   - Let user choose which workspace to import

4. **Past Todos**: TeuxDeux exports historical todos. Consider:
   - Import all (preserves history)
   - Import only from a certain date forward
   - Let user choose

5. **Recurring Todo Instances**: TeuxDeux materializes recurring instances in calendar_todos with recurring_todo_id set. During import:
   - Import the recurring_todos definitions
   - Skip materialized instances (let Todue regenerate virtuals)
   - OR import materialized instances that have been modified (done=true, different position)

6. **details Field**: TeuxDeux has a details field for additional notes. Todue doesn't have this. Options:
   - Discard
   - Append to text with separator
   - Add support for details field in Todue (future enhancement)
