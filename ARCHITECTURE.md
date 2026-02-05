# obs-tutorial-recorder Architecture

**Version:** 1.0.0
**Last Updated:** February 03, 2026

---

## System Overview

Automated OBS setup and recording workflow for tutorial production with ISO recordings, transcription, and cloud sync.

## High-Level Diagram

```
Users / Operators
        │
        ▼
obs-tutorial-recorder Core
        │
        ├── Local State / Data Storage
        └── External Integrations / APIs
        │
        ▼
Outputs (UI, Reports, Exports, Logs)
```

## Technology Stack

- macOS menubar app
- OBS WebSocket
- whisper-cpp
- rclone

## Directory Structure (Top-Level)

```
automator/
config/
docker-compose.yml
docs/
install.sh
LICENSE
README.md
render.yaml
ROADMAP.md
scripts/
TutorialRecorder/
website/
```

## Data Flow

1. User initiates action (UI/CLI/task).
2. Core logic processes input, validates rules, and triggers integrations.
3. State is persisted (local files, DB, or external systems).
4. Output is rendered to UI, exported, or logged.

## Deployment & Runtime

- Docker Compose
- Render deployment

## Security & Quality

- Follow global forbidden/required patterns and lint/typecheck rules
- No hardcoded secrets; use environment variables
- Log errors through approved logger patterns (no console.*)

## Observability

- Structured logs for key workflows
- Health checks for integrations and background tasks
