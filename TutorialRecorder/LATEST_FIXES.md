# Latest Fixes - January 21, 2026

## Issues Fixed

### 1. ✅ Progress Window Always On Top
**Problem:** Progress window ("Connecting to OBS...") could be hidden behind other windows
**Fix:** Set window level to `.floating` and added `.fullScreenAuxiliary` behavior
**File:** `Sources/Windows/ProgressWindow.swift:46-47`

Now the progress window will always stay on top of all other windows, even when OBS launches.

### 2. ✅ Profile Switching Detection Bug
**Problem:** Current profile always showed as "unknown" in logs
**Root Cause:** Looking for wrong JSON field name
- Was looking for: `"profileName"`
- Should be: `"currentProfileName"`

**Fix:** Updated regex pattern in `extractProfileName()` function
**File:** `Sources/RecordingManager.swift:603`

Now logs will correctly show:
```
[INFO] Current OBS profile: MacBook-Single
```
Instead of:
```
[INFO] Current OBS profile: unknown
```

### 3. ✅ OBS Command-Line Profile Argument Doesn't Work
**Problem:** Tried to launch OBS with `--profile "MacBook-Single"` argument, but OBS on macOS doesn't support this
**Result:** OBS always launched with default profile ("Tutorial Recording"), then switched via WebSocket

**Fix:** Removed command-line profile argument, rely entirely on WebSocket switching
**File:** `Sources/RecordingManager.swift:175-195`

**Old approach:**
```bash
open -a /Applications/OBS.app --args --profile "MacBook-Single"  # Doesn't work!
```

**New approach:**
1. Launch OBS normally
2. Wait for WebSocket connection
3. Create profiles if needed (via WebSocket)
4. Switch to correct profile (via WebSocket)
5. Start recording

### 4. ✅ Increased Wait Times for Reliability
**Changes:**
- OBS launch wait: 10s → 12s (ensures OBS fully started)
- Profile switch wait: 2s → 3s (ensures profile fully loaded)
- Added user feedback: "Profile switched, waiting for OBS to stabilize..."

**File:** `Sources/RecordingManager.swift:191, 291-293`

## How It Works Now

### Complete Flow

1. **User clicks "Start Recording..."**
2. **Selects setup type** (e.g., MacBook Setup)
3. **Progress window appears** (always on top)
4. **OBS launches** (normal launch, no profile argument)
5. **App waits 12 seconds** for OBS to fully start
6. **App connects to WebSocket**
7. **App checks existing profiles**
8. **App creates missing profiles** automatically:
   - Mac-MultiScreen
   - MacBook-Single
   - PC-10Cameras
9. **App checks current profile**
10. **App switches to target profile** (e.g., MacBook-Single)
11. **App waits 3 seconds** for profile to stabilize
12. **App sets recording directory**
13. **Recording starts** with correct profile!

### What You'll See

**Progress Window Messages:**
1. "Launching OBS..."
2. "Waiting for OBS to start..."
3. "Connecting to OBS WebSocket..."
4. "Connecting to OBS... (attempt 1/30)"
5. "Checking OBS profiles..."
6. "Verifying OBS profile..."
7. "Switching to MacBook Setup (One Screen, Native Camera) profile..."
8. "Profile switched, waiting for OBS to stabilize..."
9. "Setting up recording..."
10. "Starting recording..."

**Session Log Output:**
```
[INFO] OBS not running, launching...
[INFO] OBS launched, waiting for WebSocket...
[INFO] Connecting to OBS WebSocket...
[INFO] Connected to OBS WebSocket
[INFO] Ensuring all required OBS profiles exist...
[INFO] Fetching profile list from OBS...
[INFO] Found 2 profiles: Tutorial Recording, Untitled
[WARNING] Profile 'MacBook-Single' not found, creating it...
[SUCCESS] Successfully created profile: MacBook-Single
[SUCCESS] All required profiles are ready
[INFO] Target profile: MacBook-Single
[INFO] Current OBS profile: Tutorial Recording  ← Now shows actual profile!
[INFO] Switching OBS profile from 'Tutorial Recording' to 'MacBook-Single'
[SUCCESS] Successfully switched to profile: MacBook-Single  ← Now working!
[INFO] Setting record directory...
[SUCCESS] Recording started successfully
```

## Testing Results

Based on your latest recording session:
- ✅ Profiles created successfully
- ✅ Profile switching works
- ✅ Recording starts correctly
- ⚠️ User sees OBS start with default profile, then switch (visual glitch)

## Remaining Known Limitation

**Visual Profile Switching:**
Since we can't use command-line arguments, you'll briefly see OBS start with "Tutorial Recording" profile, then switch to "MacBook-Single" after 1-2 seconds. This is normal and expected.

**Why this happens:**
- OBS always starts with its last-used or default profile
- We can only switch profiles after OBS launches and WebSocket connects
- The switch happens within seconds, before recording actually starts
- The recording WILL use the correct profile

**Verification:**
After starting a recording, check:
1. OBS title bar should show: `OBS 32.0.4 - Profile: MacBook-Single`
2. Session log should show: `[SUCCESS] Successfully switched to profile: MacBook-Single`
3. Your MacBook camera/screen sources should be active (if you configured them)

## Next Steps

### First Time After This Update

1. **Quit OBS completely** (Cmd+Q)
2. **Quit Tutorial Recorder** (if running)
3. **Launch Tutorial Recorder** fresh
4. **Start a recording** with "MacBook Setup"
5. **Watch the progress window** (now always on top!)
6. **Wait for OBS to launch and switch**
7. **Check session log**: Tutorial Recorder → View Latest Session Log

### Expected Behavior

- Progress window stays on top ✓
- OBS launches with default profile (briefly)
- OBS switches to MacBook-Single (within 2-3 seconds)
- Recording starts with correct profile ✓
- Session log shows all profile operations ✓

### If Issues Persist

1. **View the session log** (Cmd+L or via menu)
2. Look for these success indicators:
   - `[SUCCESS] Successfully created profile: MacBook-Single`
   - `[SUCCESS] Successfully switched to profile: MacBook-Single`
   - `[SUCCESS] Recording started successfully`
3. Check OBS Profile menu manually
4. Verify all 3 profiles exist in OBS

## Summary

**What's fixed:**
- ✅ Progress window always on top
- ✅ Profile detection shows actual name (not "unknown")
- ✅ Removed non-working command-line argument
- ✅ Increased wait times for stability
- ✅ Better user feedback during process

**What works:**
- ✅ Automatic profile creation
- ✅ Profile switching via WebSocket
- ✅ Session logging
- ✅ Recording with correct profile

**Known limitation:**
- ⚠️ Brief visual switch from default to target profile (unavoidable without command-line support)

**Build:** `~/Desktop/Tutorial Recorder.app`
