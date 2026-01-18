# Tutorial Recorder Panel - Design Document

## Overview

This document details the complete design specification for the Tutorial Recorder sync panel, modeled after Google Drive's desktop application. The panel provides sync status, file activity, notifications, and quick access to recording controls.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Color Palette](#color-palette)
3. [Typography](#typography)
4. [Window Specifications](#window-specifications)
5. [Component Library](#component-library)
6. [Screen Specifications](#screen-specifications)
7. [Interactions & Behaviors](#interactions--behaviors)
8. [Data Models](#data-models)
9. [Implementation Roadmap](#implementation-roadmap)

---

## Architecture Overview

### File Structure

```
TutorialRecorder/
├── Sources/
│   ├── main.swift                    # App entry point
│   ├── AppDelegate.swift             # Main app controller, menubar
│   ├── RecordingManager.swift        # OBS recording control
│   ├── SyncManager.swift             # Cloud sync logic
│   ├── NotificationManager.swift     # In-app notifications (NEW)
│   ├── Utils.swift                   # Logging, shell commands
│   └── Windows/
│       ├── MainPanel.swift           # Main panel window (REWRITE)
│       ├── Components/               # Reusable UI components (NEW)
│       │   ├── SidebarView.swift
│       │   ├── HeaderView.swift
│       │   ├── FileRowView.swift
│       │   ├── StatusBanner.swift
│       │   └── QuickLinkButton.swift
│       ├── Screens/                  # Panel screen content (NEW)
│       │   ├── HomeScreen.swift
│       │   ├── SyncActivityScreen.swift
│       │   └── NotificationsScreen.swift
│       ├── Popovers/                 # Dropdown menus (NEW)
│       │   ├── SettingsPopover.swift
│       │   └── ProfilePopover.swift
│       ├── SyncConfigWindow.swift    # Sync configuration
│       ├── SyncStatusWindow.swift    # Legacy (to remove)
│       └── ProgressWindow.swift      # Progress indicator
```

### Component Hierarchy

```
MainPanel (NSPanel)
├── HeaderView
│   ├── AppIcon + Title
│   ├── SearchField (optional, placeholder)
│   ├── PauseSyncButton
│   ├── SettingsButton → SettingsPopover
│   └── ProfileButton → ProfilePopover
├── SidebarView
│   ├── OpenFolderButton
│   └── NavigationItems
│       ├── Home
│       ├── Sync activity
│       └── Notifications (with badge)
└── ContentArea
    ├── HomeScreen (when Home selected)
    ├── SyncActivityScreen (when Sync activity selected)
    └── NotificationsScreen (when Notifications selected)
```

---

## Color Palette

### Primary Colors (Google-style)

| Name | Hex | Usage |
|------|-----|-------|
| Google Blue | `#1A73E8` | Primary actions, selected nav, links |
| Google Blue Light | `#E8F0FE` | Selected nav background |
| Google Blue Hover | `#1557B0` | Button hover states |

### Status Colors

| Name | Hex | Usage |
|------|-----|-------|
| Success Green | `#34A853` | Sync complete, success states |
| Warning Yellow | `#FBBC04` | Warnings, attention needed |
| Warning Yellow BG | `#FEF7E0` | Warning banner background |
| Error Red | `#EA4335` | Errors, recording indicator |
| Info Blue | `#4285F4` | Info notifications |

### Neutral Colors

| Name | Hex | Usage |
|------|-----|-------|
| Text Primary | `#202124` | Main text |
| Text Secondary | `#5F6368` | Subtitle, metadata |
| Text Tertiary | `#80868B` | Disabled, hints |
| Border | `#DADCE0` | Borders, dividers |
| Background | `#FFFFFF` | Main background |
| Background Secondary | `#F1F3F4` | Cards, sidebar |
| Background Hover | `#E8EAED` | Hover states |

### Dark Mode Colors (macOS adaptive)

| Light | Dark | Usage |
|-------|------|-------|
| `#FFFFFF` | `#202124` | Background |
| `#F1F3F4` | `#303134` | Secondary background |
| `#202124` | `#E8EAED` | Primary text |
| `#5F6368` | `#9AA0A6` | Secondary text |

---

## Typography

### Font Family
- **Primary**: SF Pro Text (system font)
- **Monospace**: SF Mono (for file sizes, technical info)

### Font Sizes

| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| Title Large | 22pt | Semibold | 28pt | Screen titles |
| Title Medium | 16pt | Semibold | 22pt | Section headers |
| Title Small | 14pt | Medium | 20pt | Card titles |
| Body | 13pt | Regular | 18pt | Main content |
| Body Small | 12pt | Regular | 16pt | Secondary info |
| Caption | 11pt | Regular | 14pt | Metadata, hints |
| Button | 13pt | Medium | 18pt | Button labels |

---

## Window Specifications

### Main Panel Window

| Property | Value |
|----------|-------|
| Type | NSPanel (floating) |
| Width | 720px |
| Height | 560px |
| Min Width | 600px |
| Min Height | 400px |
| Style | Titled, Closable, Resizable |
| Level | Floating |
| Title Bar | Transparent, hidden title |
| Background | System window background |

### Layout Grid

```
┌──────────────────────────────────────────────────────────────────────┐
│ Header (56px)                                                        │
│ [Icon] Tutorial Recorder          [Search...] [⏸] [⚙] [👤]          │
├────────────────┬─────────────────────────────────────────────────────┤
│ Sidebar        │ Content Area                                        │
│ (200px)        │ (520px)                                             │
│                │                                                     │
│ [Open Folder]  │ [Screen content based on navigation]               │
│                │                                                     │
│ ○ Home         │                                                     │
│ ○ Sync activity│                                                     │
│ ○ Notifications│                                                     │
│                │                                                     │
│                │                                                     │
│                │                                                     │
│                │                                                     │
└────────────────┴─────────────────────────────────────────────────────┘
```

---

## Component Library

### 1. SidebarView

**Purpose**: Navigation between main screens

**Layout**:
```
┌────────────────┐
│ [📁] Open      │  ← Rounded rect button, 180x36px
│     Recordings │
│                │
│ [🏠] Home      │  ← Nav item, 180x36px
│ [🔄] Sync      │    Selected: Blue bg (#E8F0FE)
│     activity   │    Icon: 20x20px
│ [🔔] Notifi-   │    Text: 13pt medium
│     cations    │    Spacing: 12px icon-to-text
└────────────────┘
```

**States**:
- Default: Icon gray (#5F6368), text gray
- Hover: Background #E8EAED
- Selected: Background #E8F0FE, icon blue (#1A73E8), text blue

**Badge** (for Notifications):
- Red circle, 8px diameter
- Position: Top-right of icon
- Shows when unread notifications exist

### 2. HeaderView

**Purpose**: App identity, global actions

**Layout**:
```
┌──────────────────────────────────────────────────────────────────────┐
│ [🎬] Tutorial Recorder            [🔍 Search...]  [⏸] [⚙] [👤]      │
└──────────────────────────────────────────────────────────────────────┘
```

**Components**:
- App icon: 28x28px, system blue
- App name: 16pt semibold
- Search field: 240px wide, 32px tall, rounded, gray background
- Icon buttons: 32x32px, circular hover state
  - Pause/Resume sync toggle
  - Settings (opens dropdown)
  - Profile (opens popover)

### 3. FileRowView

**Purpose**: Display individual file in sync list

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ [📄] filename.mkv                     3.7 MB    [⬆️] [⋮]       │
│      1.2 MB, 45% uploaded                                       │
└─────────────────────────────────────────────────────────────────┘
```

**Dimensions**:
- Row height: 52px
- Icon: 24x24px, left margin 16px
- Filename: 13pt medium, max width 300px, truncate middle
- Subtitle: 12pt regular, gray
- File size column: Right-aligned, 80px
- Status icon: 24x24px, blue circle with white arrow up
- Menu button: 24x24px, appears on hover

**Status Icons**:
- Uploading: Blue circle with up arrow (animated)
- Uploaded: Blue circle with checkmark
- Pending: Gray clock
- Error: Red circle with exclamation

### 4. StatusBanner

**Purpose**: Show sync status or errors

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ [⚠️] 40 errors                                          [View] │
└─────────────────────────────────────────────────────────────────┘
```

**Variants**:
- **Error/Warning**: Yellow background (#FEF7E0), yellow icon, "View" link
- **Success**: Green background, green icon, dismissible
- **Info**: Blue background, blue icon

**Dimensions**:
- Height: 40px
- Corner radius: 8px
- Padding: 12px horizontal
- Icon: 20x20px
- Text: 13pt medium
- Link: 13pt medium, blue

### 5. QuickLinkButton

**Purpose**: Action links in Quick Links section

**Layout**:
```
┌─────────────────────────────────────┐
│ [+] Add more folders to sync        │
└─────────────────────────────────────┘
```

**Dimensions**:
- Height: 40px
- Padding: 12px horizontal
- Icon: 18x18px
- Text: 13pt regular
- Border: 1px #DADCE0
- Corner radius: 20px (pill shape)

**States**:
- Default: White background, gray border
- Hover: Light gray background

---

## Screen Specifications

### Screen 1: Home

**Purpose**: Overview of sync status, recent activity, quick actions

**Layout**:
```
┌─────────────────────────────────────┬───────────────────────────┐
│ Main Content (340px)                │ Right Sidebar (180px)     │
├─────────────────────────────────────┼───────────────────────────┤
│                                     │                           │
│ [🔄] Syncing...                     │ Needs my attention        │
│      142,477 files                  │ ┌─────────────────────┐  │
│                                     │ │ [ℹ] Notification... │  │
│ ┌─ Warning Banner ───────────────┐ │ └─────────────────────┘  │
│ │ [⚠] 40 errors           [View] │ │       [View all]          │
│ └────────────────────────────────┘ │                           │
│                                     │ Quick links               │
│ [File Row 1]                        │ ┌─────────────────────┐  │
│ [File Row 2]                        │ │ + Add folders       │  │
│ [File Row 3]                        │ ├─────────────────────┤  │
│          [View all]                 │ │ ↗ Open Drive web    │  │
│                                     │ ├─────────────────────┤  │
│ ┌─ Card ─────────────────────────┐ │ │ ↗ Open OBS          │  │
│ │ Recording Controls             │ │ ├─────────────────────┤  │
│ │ Start/Stop recording           │ │ │ ⚙ Preferences       │  │
│ └────────────────────────────────┘ │ └─────────────────────┘  │
└─────────────────────────────────────┴───────────────────────────┘
```

**Sync Status Header**:
- Animated sync icon (rotating arrows) or checkmark
- Status text: "Syncing...", "Up to date", "Paused"
- File count or last sync time

**Recent Files Section**:
- Shows 3-5 most recent files being synced
- "View all" button links to Sync Activity screen

**Recording Card** (Tutorial Recorder specific):
- Shows current recording status
- Start/Stop recording button
- Project name when recording

**Right Sidebar - Quick Links**:
- Add more folders to sync
- Open Drive web (opens Google Drive in browser)
- Open OBS
- Preferences (opens settings)

### Screen 2: Sync Activity

**Purpose**: Detailed view of all sync activity

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ [🔄] Syncing...                                                 │
│      142,903 files                                              │
│                                                                 │
│ ┌─ Warning Banner ───────────────────────────────────────────┐ │
│ │ [⚠] 40 errors                                       [View] │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─ Table Header ─────────────────────────────────────────────┐ │
│ │ Name                              File size      Status    │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ [File Row - full width with columns]                           │
│ [File Row]                                                      │
│ [File Row]                                                      │
│ [File Row]                                                      │
│ [File Row]                                                      │
│ [File Row]                                                      │
│ [File Row]                                                      │
│ ...scrollable...                                                │
└─────────────────────────────────────────────────────────────────┘
```

**Table Columns**:
| Column | Width | Content |
|--------|-------|---------|
| Name | Flex (min 250px) | File icon + name + subtitle |
| File size | 100px | Formatted size |
| Status | 80px | Status icon + 3-dot menu |

**Filtering** (future enhancement):
- All files
- Uploading
- Completed
- Errors

### Screen 3: Notifications

**Purpose**: System notifications and alerts

**Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│ Notifications                                                   │
│                                                                 │
│ ┌─ Notification Card ────────────────────────────────────────┐ │
│ │ [ℹ] Recording completed                              [✕]   │ │
│ │     Project "My Tutorial" finished recording.              │ │
│ │     Files have been collected to project folder.           │ │
│ │                                                            │ │
│ │                        [Open Folder]  [Dismiss]            │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─ Notification Card ────────────────────────────────────────┐ │
│ │ [⚠] Sync errors                                      [✕]   │ │
│ │     3 files failed to upload. Check your connection.       │ │
│ │                                                            │ │
│ │                           [View Errors]  [Dismiss]         │ │
│ └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ No more notifications                                           │
└─────────────────────────────────────────────────────────────────┘
```

**Notification Types**:
- **Info**: Blue icon, informational messages
- **Success**: Green icon, completed actions
- **Warning**: Yellow icon, attention needed
- **Error**: Red icon, failures

**Notification Card**:
- Icon: 24x24px, color based on type
- Title: 13pt medium
- Body: 12pt regular, gray, max 3 lines
- Dismiss X: Top-right corner
- Action buttons: Bottom-right, text buttons

---

## Interactions & Behaviors

### Navigation

1. **Sidebar click**: Switch content area to selected screen
2. **Selected state**: Blue background, blue icon/text
3. **Badge**: Red dot on Notifications when unread

### Sync Actions

1. **Pause/Resume button**:
   - Click to toggle sync state
   - Icon changes: ⏸ (pause) ↔ ▶ (resume)
   - Tooltip shows current action

2. **Sync Now** (from menu):
   - Starts immediate sync
   - Status changes to "Syncing..."
   - Icon animates

3. **File row click**:
   - Single click: Select row
   - Double click: Open file in Finder

4. **File row menu (⋮)**:
   - Show in Finder
   - Open in Drive
   - Copy path

### Popovers

1. **Settings Popover** (from ⚙ button):
   ```
   ┌────────────────────┐
   │ Preferences        │
   │ Offline files      │
   │ Error list         │
   ├────────────────────┤
   │ About              │
   │ Help               │
   │ Send feedback      │
   ├────────────────────┤
   │ Quit               │
   └────────────────────┘
   ```

2. **Profile Popover** (from profile button):
   ```
   ┌────────────────────────────┐
   │         [Avatar]          │
   │      Hi, Username!        │
   │    user@email.com         │
   │                           │
   │ [+ Add account] [Disconnect]│
   │                           │
   │ [===    ] 20% of 15 GB    │
   │           Manage storage  │
   │                           │
   │ Privacy · Terms           │
   └────────────────────────────┘
   ```

### Recording Integration

1. **Start Recording**:
   - Shows in Home screen
   - Recording card appears with red indicator
   - Project name displayed

2. **Stop Recording**:
   - Triggers auto-sync if enabled
   - Notification appears
   - Files show in sync activity

### Animations

1. **Sync icon**: Rotating arrows during sync
2. **Progress**: File upload progress (if available)
3. **Transitions**: Fade between screens (200ms)
4. **Hover**: Background color transition (100ms)

---

## Data Models

### SyncStatus

```swift
enum SyncState {
    case idle           // Not syncing, up to date
    case syncing        // Actively syncing
    case paused         // Sync paused by user
    case error          // Sync error occurred
    case notConfigured  // Not set up yet
}

struct SyncStatus {
    var state: SyncState
    var totalFiles: Int
    var completedFiles: Int
    var errorCount: Int
    var lastSyncTime: Date?
    var currentFile: String?
}
```

### FileActivity

```swift
enum FileActivityStatus {
    case pending
    case uploading(progress: Double)
    case uploaded
    case error(message: String)
}

struct FileActivity {
    let id: UUID
    let filename: String
    let path: String
    let size: Int64
    var status: FileActivityStatus
    let timestamp: Date
}
```

### Notification

```swift
enum NotificationType {
    case info
    case success
    case warning
    case error
}

struct AppNotification {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date
    var isRead: Bool
    var actions: [(title: String, action: () -> Void)]
}
```

---

## Implementation Roadmap

### Phase 1: Core Structure (Priority: HIGH)

1. **Create new file structure**
   - Add Components/ directory
   - Add Screens/ directory
   - Add Popovers/ directory

2. **Implement base components**
   - SidebarView with navigation
   - HeaderView with buttons
   - FileRowView

3. **Rewrite MainPanel**
   - New layout with sidebar + content
   - Navigation state management
   - Screen switching

### Phase 2: Home Screen (Priority: HIGH)

1. **Sync status header**
   - Animated sync icon
   - Status text and file count

2. **Warning/error banner**
   - Conditional display
   - View action

3. **Recent files list**
   - FileRowView integration
   - View all link

4. **Recording card**
   - Recording status
   - Start/stop controls

5. **Quick links sidebar**
   - Action buttons
   - External links

### Phase 3: Sync Activity Screen (Priority: MEDIUM)

1. **Full file table**
   - Sortable columns
   - Scrollable list

2. **File row interactions**
   - Selection
   - Context menu
   - Double-click action

### Phase 4: Notifications Screen (Priority: MEDIUM)

1. **NotificationManager**
   - Add/remove notifications
   - Persistence (optional)

2. **Notification cards**
   - Type-based styling
   - Action buttons
   - Dismiss functionality

3. **Badge system**
   - Unread count
   - Clear on view

### Phase 5: Popovers (Priority: LOW)

1. **Settings popover**
   - Menu items
   - Actions

2. **Profile popover**
   - Account info
   - Storage usage
   - Disconnect option

### Phase 6: Polish (Priority: LOW)

1. **Animations**
   - Sync icon rotation
   - Screen transitions
   - Hover effects

2. **Dark mode**
   - Color adaptation
   - Testing

3. **Keyboard shortcuts**
   - Navigation
   - Actions

---

## Testing Checklist

### Functional Tests

- [ ] Sidebar navigation works correctly
- [ ] Home screen displays sync status
- [ ] Recent files show correctly
- [ ] View all navigates to Sync Activity
- [ ] Recording start/stop works
- [ ] Sync Activity shows all files
- [ ] File double-click opens Finder
- [ ] Notifications display correctly
- [ ] Notification dismiss works
- [ ] Settings menu opens
- [ ] Profile popover shows
- [ ] Pause/resume sync works
- [ ] Auto-sync triggers after recording

### Visual Tests

- [ ] Colors match design spec
- [ ] Typography is consistent
- [ ] Spacing is correct
- [ ] Icons render properly
- [ ] Dark mode works
- [ ] Window resizing works
- [ ] Scroll behavior is smooth

### Edge Cases

- [ ] No files to sync
- [ ] Many files (100+)
- [ ] Long filenames
- [ ] Sync errors
- [ ] Network disconnection
- [ ] OBS not running
- [ ] rclone not configured

---

## Appendix: Icon Reference

| Usage | SF Symbol Name | Color |
|-------|---------------|-------|
| App icon | video.circle.fill | System Blue |
| Home nav | house.fill | Gray/Blue |
| Sync activity nav | arrow.triangle.2.circlepath | Gray/Blue |
| Notifications nav | bell.fill | Gray/Blue |
| Open folder | folder.fill | Gray |
| Pause sync | pause.circle | Gray |
| Resume sync | play.circle | Gray |
| Settings | gearshape.fill | Gray |
| Profile | person.circle.fill | Gray |
| Upload status | arrow.up.circle.fill | Blue |
| Uploaded | checkmark.circle.fill | Blue |
| Pending | clock.fill | Gray |
| Error | exclamationmark.circle.fill | Red |
| Warning | exclamationmark.triangle.fill | Yellow |
| Info | info.circle.fill | Blue |
| Success | checkmark.circle.fill | Green |
| Recording | record.circle.fill | Red |
| Close/Dismiss | xmark | Gray |
| Menu | ellipsis | Gray |
| External link | arrow.up.right | Gray |
| Add | plus | Blue |
