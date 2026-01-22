# Automatic OBS Profile Setup

## 🎉 No Manual Setup Required!

The app now **automatically creates** OBS profiles for you via WebSocket. You don't need to manually create profiles in OBS anymore.

## How It Works

When you start a recording, the app:

1. **Connects to OBS WebSocket**
2. **Checks which profiles exist** in your OBS installation
3. **Automatically creates any missing profiles**:
   - `Mac-MultiScreen`
   - `MacBook-Single`
   - `PC-10Cameras`
4. **Switches to the correct profile** based on your selection
5. **Starts recording** with the right configuration

## What Happens on First Launch

### Scenario: You've never used this app before

1. You select "MacBook Setup (One Screen, Native Camera)"
2. App launches OBS with `--profile "MacBook-Single"`
3. App connects to OBS WebSocket
4. App checks: "Does `MacBook-Single` profile exist?"
5. **If NO**: App creates it automatically
6. **If YES**: App just switches to it
7. Recording starts

### Session Log Output (Example)

When you view the latest session log, you'll see:

```
=============================================
Session started: 2026-01-21 16:45:23
Project: ~/Desktop/Tutorial Recordings/2026-01-21_my-tutorial
Setup: MacBook Setup (One Screen, Native Camera)
=============================================

[INFO] Starting recording for project: my-tutorial
[INFO] Project path: ~/Desktop/Tutorial Recordings/2026-01-21_my-tutorial
[INFO] Setup type: MacBook Setup (One Screen, Native Camera)
[INFO] OBS not running, launching with profile: MacBook-Single...
[INFO] OBS launched with profile MacBook-Single, waiting for WebSocket...
[INFO] Connecting to OBS WebSocket...
[INFO] Connected to OBS WebSocket
[INFO] Ensuring all required OBS profiles exist...
[INFO] Fetching profile list from OBS...
[INFO] Found 1 profiles: Tutorial Recording
[WARN] Profile 'MacBook-Single' not found, creating it...
[INFO] Creating OBS profile: MacBook-Single
[SUCCESS] Successfully created profile: MacBook-Single
[WARN] Profile 'Mac-MultiScreen' not found, creating it...
[INFO] Creating OBS profile: Mac-MultiScreen
[SUCCESS] Successfully created profile: Mac-MultiScreen
[WARN] Profile 'PC-10Cameras' not found, creating it...
[INFO] Creating OBS profile: PC-10Cameras
[SUCCESS] Successfully created profile: PC-10Cameras
[SUCCESS] All required profiles are ready
[INFO] Target profile: MacBook-Single
[INFO] Current OBS profile: MacBook-Single
[SUCCESS] Already on correct profile: MacBook-Single
[INFO] Setting record directory to: ~/Desktop/Tutorial Recordings/2026-01-21_my-tutorial/raw
[INFO] Sending StartRecord command...
[SUCCESS] Recording started successfully
```

## Viewing Session Logs

### Method 1: Via Menu
1. Click Tutorial Recorder icon in menubar
2. Click "View Latest Session Log"
3. Log opens in your default text editor

### Method 2: Manually
1. Go to your project folder
2. Open `session.log` file

Example path:
```
~/Desktop/Tutorial Recordings/2026-01-21_my-tutorial/session.log
```

## What Gets Logged

The session log shows you:
- ✅ OBS connection status
- ✅ Profile existence checks
- ✅ Profile creation attempts
- ✅ Profile switching operations
- ✅ Recording start/stop events
- ✅ File collection operations
- ✅ Any errors or warnings
- ✅ Audio extraction status
- ✅ Auto-transcription triggers

## Important Notes

### Profile Configuration

When profiles are automatically created, they start **empty**. You'll need to configure them **once**:

1. Let the app create the profiles (happens automatically)
2. After first recording, open OBS
3. Switch to each profile (e.g., `MacBook-Single`)
4. Add your sources:
   - Display Capture
   - Video Capture Device (camera)
   - Audio Input
5. Configure ISO recording in Settings > Output
6. Save

**Next time**: The profile already exists with your configuration!

### If OBS Launches With Wrong Profile

**Check the session log!** It will tell you exactly what happened:

```bash
# Via menu
Tutorial Recorder > View Latest Session Log

# Or manually
open ~/Desktop/Tutorial\ Recordings/[latest-folder]/session.log
```

Look for these lines:
- `Creating OBS profile: MacBook-Single` → Profile was created
- `Successfully switched to profile: MacBook-Single` → Switch worked
- `Profile 'MacBook-Single' does not exist!` → Creation failed
- `Already on correct profile: MacBook-Single` → Already correct

### Common Log Patterns

**✅ Success Pattern:**
```
[INFO] Fetching profile list from OBS...
[INFO] Found 3 profiles: MacBook-Single, Mac-MultiScreen, PC-10Cameras
[INFO] Profile 'MacBook-Single' already exists
[SUCCESS] All required profiles are ready
[SUCCESS] Already on correct profile: MacBook-Single
```

**⚠️ First-Time Creation:**
```
[WARN] Profile 'MacBook-Single' not found, creating it...
[SUCCESS] Successfully created profile: MacBook-Single
```

**❌ Error Pattern:**
```
[ERROR] Failed to create profile: MacBook-Single
[ERROR] Response: {"error":"..."}
```

## Troubleshooting

### Profiles aren't being created

1. **Check OBS WebSocket is enabled**
   - OBS > Settings > OBS WebSocket
   - Enable WebSocket server
   - Port: 4455

2. **View the session log** to see what failed
   - Tutorial Recorder > View Latest Session Log
   - Look for error messages

3. **Try manually creating one profile** to test
   - OBS > Profile > New > `Test-Profile`
   - If this works, the app should work too

### Profile created but empty/misconfigured

This is normal! Profiles start empty. Just configure them once:
- Add your scenes and sources
- Set up ISO recording
- Configure output settings
- The app will use this configuration next time

### Can't find session log

The log is created in your project folder:
```
~/Desktop/Tutorial Recordings/YYYY-MM-DD_project-name/session.log
```

If you can't find it:
- Recording may have failed before creating the log
- Check if the project folder was created
- Look in the app's temporary files: `/tmp/obs-tutorial-session.txt`

## Advanced: Manual Profile Creation (Optional)

If you prefer to create profiles manually first:

1. Open OBS
2. Profile > New > `MacBook-Single`
3. Configure all your sources/scenes
4. Repeat for other profiles

**Benefit**: Your profiles are pre-configured before first use
**Downside**: More upfront work

The app will detect these profiles exist and skip creation.
