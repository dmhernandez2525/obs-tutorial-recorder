# OBS Profile Setup Guide

The Tutorial Recorder app automatically switches between different OBS profiles based on your recording setup. You **MUST** create these profiles in OBS Studio before using the app.

## ⚠️ CRITICAL: Profile Names Must Match Exactly

The profile names are **case-sensitive** and must match exactly as shown below. If they don't match, OBS will continue using the default profile.

## Required OBS Profiles

### 1. Mac-MultiScreen
**For:** Mac Setup (Multiple Screens)
**Profile Name in OBS:** `Mac-MultiScreen` ← Copy this exactly

**Recommended Configuration:**
- Multiple display capture sources (Screen 1, Screen 2, Screen 3)
- All your usual cameras and audio sources
- Scene collection optimized for multi-monitor workflow
- ISO recording enabled for each source

### 2. MacBook-Single
**For:** MacBook Setup (One Screen, Native Camera)
**Profile Name in OBS:** `MacBook-Single` ← Copy this exactly

**Recommended Configuration:**
- Single display capture (built-in Retina display)
- Built-in FaceTime HD camera
- Built-in microphone
- Minimal scenes for single-screen workflow
- ISO recording enabled for screen + camera

### 3. PC-10Cameras
**For:** PC Setup (One Screen, 10 Cameras)
**Profile Name in OBS:** `PC-10Cameras` ← Copy this exactly

**Recommended Configuration:**
- Single display capture
- 10 camera sources (Camera - ZV-E1, Camera 2, Camera 3, etc.)
- Audio mixer for all camera inputs
- Scenes optimized for managing multiple camera views
- ISO recording enabled for all sources

## Step-by-Step: How to Create Profiles in OBS

### Creating Your First Profile (MacBook-Single example)

1. **Open OBS Studio**
   - Launch OBS normally

2. **Access Profile Menu**
   - Look at the top menu bar
   - Click **Profile**

3. **Create New Profile**
   - Click **New**
   - A dialog will appear asking for the profile name

4. **Enter EXACT Profile Name**
   - Type: `MacBook-Single` (copy/paste recommended)
   - Click **OK**

5. **Configure This Profile**
   - Add your scenes (e.g., "Tutorial Recording")
   - Add sources:
     - Display Capture (your screen)
     - Video Capture Device (FaceTime HD Camera)
     - Audio Input Capture (microphone)
   - Go to Settings > Output
     - Enable "Advanced" output mode
     - Recording tab: Enable "Advanced Recording" for ISO tracks
   - Save all settings

6. **Repeat for Other Profiles**
   - Profile > New > `Mac-MultiScreen`
   - Profile > New > `PC-10Cameras`
   - Configure each one for your specific setup

### Quick Profile Setup Checklist

- [ ] Created `MacBook-Single` profile (exact spelling)
- [ ] Created `Mac-MultiScreen` profile (exact spelling)
- [ ] Created `PC-10Cameras` profile (exact spelling)
- [ ] Each profile has at least one scene
- [ ] Each profile has display capture configured
- [ ] Each profile has camera sources configured
- [ ] ISO recording enabled in each profile's output settings

## Important Notes

- **Profile names must match exactly** (case-sensitive)
- Each profile can have its own:
  - Scene collections
  - Video/audio settings
  - Encoder settings
  - Output paths (though the app overrides the recording path)
- If a profile doesn't exist, the app will log a warning and continue with the current profile
- You only need to create profiles for the setups you actually use

## Testing Your Setup

1. Launch Tutorial Recorder
2. Click "Start Recording..."
3. Select your setup type from the dropdown
4. The app will automatically switch OBS to the correct profile
5. Check OBS to verify it switched to the right profile and scenes

## Troubleshooting

### ❌ Profile doesn't switch / OBS opens with default "Tutorial Recording" profile

**Most common causes:**

1. **Profile doesn't exist with the exact name**
   - Solution: Go to OBS > Profile menu and verify you see:
     - `Mac-MultiScreen`
     - `MacBook-Single`
     - `PC-10Cameras`
   - If not, create them following the steps above

2. **Profile name has typos or wrong capitalization**
   - Wrong: `macbook-single`, `Macbook-Single`, `MacBook Single`
   - Correct: `MacBook-Single`
   - Solution: Delete the wrong profile and create a new one with the exact name

3. **OBS is already running when you start recording**
   - The app will attempt to switch profiles via WebSocket
   - Check the session log for "Profile switch" messages
   - If it fails, close OBS completely and let the app launch it fresh

**How to verify it's working:**

1. Quit OBS completely (Cmd+Q)
2. Start Tutorial Recorder app
3. Click "Start Recording..."
4. Select "MacBook Setup (One Screen, Native Camera)"
5. Watch OBS launch
6. Check the OBS title bar - it should say: `OBS 32.0.4 - Profile: MacBook-Single`
7. Check the session log in your project folder for:
   - "Launching OBS with profile: MacBook-Single"
   - "Successfully switched to profile: MacBook-Single"

### Other Issues

**Can't find where to create profiles:**
- Look in the top menu bar of OBS Studio
- The menu should be: Profile > New
- Not in Settings or Preferences

**WebSocket connection fails:**
- Make sure OBS WebSocket plugin is installed (included in OBS 28+)
- Check Settings > OBS WebSocket > Enable WebSocket server
- Default port should be 4455

**Session log shows "Profile 'MacBook-Single' does not exist!":**
- The profile literally doesn't exist in OBS
- Go create it: Profile > New > `MacBook-Single`
