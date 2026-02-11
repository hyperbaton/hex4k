# Tech Tree: Branches and Milestones

The tech tree is organized into branches (research tracks) and milestones (unlockable nodes within branches). Branches are defined in a single file, while milestones each have their own file.

## File Locations

```
data/tech/branches.json          # All branches in one file
data/tech/milestones/<milestone_id>.json  # One file per milestone
```

## Branches

### Schema

`data/tech/branches.json` is a single JSON object where each key is a branch ID:

```json
{
  "agriculture": {
    "name": "Agriculture",
    "color": "#4A9B4A",
    "icon": "res://assets/icons/branches/agriculture.svg",
    "starts_from": null,
    "visibility": {
      "always_visible": true
    }
  },
  "engineering": {
    "name": "Engineering",
    "color": "#4682B4",
    "icon": "res://assets/icons/branches/engineering.svg",
    "starts_from": {
      "branch": "construction",
      "milestone": "masonry"
    },
    "visibility": {
      "always_visible": false,
      "show_when": [{ "branch": "construction", "level": 10.0 }]
    }
  }
}
```

### Branch Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name |
| `color` | string | Hex color for UI display |
| `icon` | string | Path to the branch icon asset |
| `starts_from` | Object/null | Parent branch and milestone that unlocks this branch |
| `visibility` | Object | When this branch becomes visible to the player |

**`starts_from`:**

| Field | Type | Description |
|-------|------|-------------|
| `branch` | string | Parent branch ID |
| `milestone` | string | Milestone ID that unlocks this branch |

Set to `null` for branches available from the start.

**`visibility`:**

| Field | Type | Description |
|-------|------|-------------|
| `always_visible` | bool | If true, branch is visible from game start |
| `show_when` | Array | Conditions for the branch to become visible |

Each `show_when` entry:

| Field | Type | Description |
|-------|------|-------------|
| `branch` | string | Branch ID to check |
| `level` | float | Research level threshold in that branch |

## Milestones

### Schema

```json
{
  "name": "Fermentation",
  "description": "Using microorganisms to transform food and drink.",
  "flavor_text": "Optional narrative flavor text.",
  "branch": "gathering_and_crafting",
  "requirements": [
    { "branch": "gathering_and_crafting", "level": 20.0 }
  ],
  "visibility": {
    "always_visible": false,
    "show_when": [
      { "branch": "gathering_and_crafting", "level": 15.0 }
    ]
  },
  "visual": {
    "icon": "res://assets/icons/milestones/fermentation.png"
  }
}
```

### Milestone Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name |
| `description` | string | Description of the milestone |
| `flavor_text` | string | Optional. Narrative text for atmosphere |
| `branch` | string | The branch ID this milestone belongs to |
| `requirements` | Array | Conditions that must be met to unlock this milestone |
| `visibility` | Object | When this milestone becomes visible |
| `visual` | Object | Display properties |

**`requirements`** - each entry:

| Field | Type | Description |
|-------|------|-------------|
| `branch` | string | Branch ID to check |
| `level` | float | Required research level in that branch |

A milestone can require progress in multiple branches. All requirements must be met.

**`visibility`** - same structure as branch visibility:

| Field | Type | Description |
|-------|------|-------------|
| `always_visible` | bool | Visible from game start |
| `show_when` | Array | Conditions for visibility (same format as requirements) |

### How Milestones Unlock Things

Milestones are referenced by other entities through `milestones_required` fields:

- **Buildings**: `requirements.milestones_required` in building JSON files
- **Resources**: `milestones_required` field
- **Units**: `milestones_required` field
- **Modifiers**: `milestones_required` field
- **Tech branches**: `starts_from.milestone` unlocks new branches

When a milestone is unlocked, all entities that required it become available.

## How Research Works

1. Buildings produce `research` resources with a `branch` field, directing points to specific branches
2. Research points accumulate in the branch's `level`
3. When a branch reaches a milestone's required level, the milestone unlocks
4. Players can set a **focus branch** to direct unspecified research points

## Examples

### Root Branch (Always Visible)

```json
{
  "agriculture": {
    "name": "Agriculture",
    "color": "#4A9B4A",
    "icon": "res://assets/icons/branches/agriculture.svg",
    "starts_from": null,
    "visibility": { "always_visible": true }
  }
}
```

### Unlockable Branch

Requires a milestone from another branch and has visibility conditions:

```json
{
  "engineering": {
    "name": "Engineering",
    "color": "#4682B4",
    "icon": "res://assets/icons/branches/engineering.svg",
    "starts_from": {
      "branch": "construction",
      "milestone": "masonry"
    },
    "visibility": {
      "always_visible": false,
      "show_when": [{ "branch": "construction", "level": 10.0 }]
    }
  }
}
```

### Early Milestone (Always Visible)

```json
{
  "name": "Foraging",
  "description": "Collecting wild plants and resources for survival.",
  "branch": "gathering_and_crafting",
  "requirements": [{ "branch": "gathering_and_crafting", "level": 0.0 }],
  "visibility": { "always_visible": true },
  "visual": { "icon": "res://assets/icons/milestones/foraging.png" }
}
```

### Late Milestone (Conditionally Visible)

```json
{
  "name": "Fermentation",
  "description": "Using microorganisms to transform food and drink.",
  "branch": "gathering_and_crafting",
  "requirements": [{ "branch": "gathering_and_crafting", "level": 20.0 }],
  "visibility": {
    "always_visible": false,
    "show_when": [{ "branch": "gathering_and_crafting", "level": 15.0 }]
  },
  "visual": { "icon": "res://assets/icons/milestones/fermentation.png" }
}
```
