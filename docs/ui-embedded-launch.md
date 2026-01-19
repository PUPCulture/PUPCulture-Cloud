# UI Embedded Launch (Role-Based, One-Click)

This document captures the **layout structure first** for a role-based Admin UI launch experience that supports a one-click, embedded link with no login prompt. The layout is intentionally structured before implementation details so the UI and backend flows can align on the desired experience.

## Goals

- Enable a one-click, embedded link to open the Admin UI without a login prompt.
- Respect role-based access so users only see the sections they are permitted to use.
- Provide clear context about *who* is signed in (role + tenant) even when login is bypassed.

## Layout Structure (First-Pass)

### 1) Shell / App Frame

- **Top Bar**
  - Logo + environment label (e.g., Prod, Staging)
  - Current user summary (role badge + tenant name)
  - “Switch context” dropdown (if multi-tenant is enabled)
  - “Support” link / help icon

- **Left Nav (Role-Aware)**
  - Grouped navigation sections with role-scoped visibility.
  - Example groups:
    - **Operations**: Dashboard, Live Events, Logs
    - **Management**: Bots, API Keys, Rules (Admin+)
    - **Billing/Plans**: Usage, Invoices (Owner+)

- **Main Content Area**
  - Route-based content with a consistent page header.
  - Page header includes title, breadcrumbs, and a contextual call-to-action button.

### 2) Embedded Launch Entry Point

- **Launch Card (for sharing / embedding)**
  - Title: “Open Admin UI”
  - Description: Short copy explaining access scope (e.g., “Role: Analyst · Tenant: Northwind”).
  - Primary CTA button: “Open Admin UI” (one-click).
  - Secondary CTA: “Copy link” (optional).

- **Post-Launch Banner (inside UI)**
  - A slim banner confirms the access context:
    - “You are viewing as Analyst (Tenant: Northwind).”
  - Includes a “Request higher access” or “Contact admin” link.

### 3) Role-Based Page Framing

Each page should reinforce role boundaries visually and contextually:

- **Page Header**
  - Title + short subtitle describing the purpose.
  - Role badge aligned to the right (e.g., “Read-only”).

- **Primary Panel**
  - The core content for the role (e.g., read-only lists for Analysts).

- **Secondary Panel**
  - Helpful side info: docs, activity, audit trail.
  - If actions are restricted, show disabled controls with short tooltips.

### 4) Empty/No Access State

- **Inline Access State Component**
  - Friendly message: “You don’t have access to this section.”
  - Explanation: “Ask an Admin to grant access to X.”
  - CTA: “Request access” (opens email or support channel).

## Information Architecture (First-Pass)

```
Admin UI
├── Dashboard (all roles)
├── Live Events (all roles)
├── Bots
│   ├── Bot List (Admin+)
│   └── Bot Details (Admin+)
├── API Keys (Admin+)
├── Rules (Admin+)
├── Usage (Owner+)
└── Settings
    ├── Team (Owner+)
    └── Tenants (Owner+)
```

## One-Click Embedded Link Notes (UX Only)

- The embedded link should open directly to the requested route (e.g., `/dashboard`).
- If the role does not allow that route, redirect to the closest allowed route and show a banner explaining the redirect.
- The UI should never present a login screen when launched via the embedded link.

## Next Steps (Implementation Follow-Up)

- Decide the exact role taxonomy (Viewer, Analyst, Admin, Owner).
- Define the “embedded link” payload (e.g., signed token + tenant + role).
- Align API response models for role-based nav and route access.

