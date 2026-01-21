# Quick Start Guide

## First Time Setup (5 minutes)

### Step 1: Create OBS Profiles

Open OBS and create these three profiles with **exact names**:

```
Profile > New > Mac-MultiScreen
Profile > New > MacBook-Single
Profile > New > PC-10Cameras
```

### Step 2: Configure Each Profile

Switch to each profile and set it up:

**For MacBook-Single:**
- Add Scene: "Tutorial Recording"
- Add Source: Display Capture (your screen)
- Add Source: Video Capture Device (FaceTime HD Camera)
- Add Source: Audio Input (microphone)
- Settings > Output > Recording > Enable ISO recording

**For Mac-MultiScreen:**
- Add Scene: "Tutorial Recording"
- Add Sources: Multiple Display Captures (Screen 1, 2, 3)
- Add Sources: Your cameras
- Add Sources: Audio inputs
- Settings > Output > Recording > Enable ISO recording

**For PC-10Cameras:**
- Add Scene: "Tutorial Recording"
- Add Source: Display Capture
- Add Sources: All 10 cameras
- Add Sources: Audio from each camera
- Settings > Output > Recording > Enable ISO recording

### Step 3: Test It

1. Quit OBS (Cmd+Q)
2. Open Tutorial Recorder app
3. Click "Start Recording..."
4. Select "MacBook Setup (One Screen, Native Camera)"
5. Enter a project name
6. Click "Start Recording"

**Expected result:**
- OBS launches automatically
- Title bar shows: `OBS 32.0.4 - Profile: MacBook-Single`
- Recording starts automatically

## Daily Usage

1. Click Tutorial Recorder icon in menubar
2. Click "Start Recording..."
3. Select your current setup (MacBook, Mac, or PC)
4. Enter project name
5. Start recording
6. When done: Click menubar icon > Stop Recording

## If Profile Doesn't Switch

1. Check OBS > Profile menu - do you see all three profiles?
2. Are they spelled exactly right?
   - `MacBook-Single` ✓
   - `Macbook-Single` ✗ (wrong capitalization)
3. Quit OBS completely before starting a recording
4. Check the session log in your project folder for errors

## Profile Name Reference

Copy these exactly:

```
Mac-MultiScreen
MacBook-Single
PC-10Cameras
```

(Copy/paste recommended to avoid typos)
