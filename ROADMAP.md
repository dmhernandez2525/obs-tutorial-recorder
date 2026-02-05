# obs-tutorial-recorder Roadmap

**Version:** 1.0.0
**Last Updated:** February 03, 2026

---

## Vision

Automated OBS setup and recording workflow for tutorial production with ISO recordings, transcription, and cloud sync.

## Current State

- **Status**: Active macOS app; feature set documented
- **Automation**: OBS WebSocket auto-configuration

## Phase Overview

- **Phase 1 (Core)**: Foundation and MVP scope
- **Phase 2 (Expansion)**: Feature depth and integrations
- **Phase 3 (Scale/Polish)**: Reliability, automation, and UX polish

## Phase 1: Core

### OBS Auto-Configuration

- Profiles/scenes via WebSocket
- No manual setup

### Setup Wizard

- First-run multi-step flow
- Profile presets

### Profile Management

- Create/edit/switch profiles
- Menubar controls

### One-Click Session Start

- Project naming
- Start/stop automation

## Phase 2: Expansion

### ISO Recordings

- Per-source outputs
- Source Record integration

### Audio Extraction

- Auto-extract AAC
- Attach to project

### Local Transcription

- Whisper AI pipeline
- Transcript output

## Phase 3: Scale & Polish

### Project Organization

- raw/exports structure
- Dated folders

### Cloud Sync

- rclone integration
- Sync status panel

### Menubar UX Polish

- Status indicators
- Progress windows

## Success Criteria

- All features implemented with tests, lint, typecheck, and build passing
- Documentation updated for any architecture or workflow changes
- No forbidden patterns; follow global standards

## Risks & Dependencies

- External API limits, vendor dependencies, or platform constraints
- Cross-platform requirements (Mac/Windows) where applicable
