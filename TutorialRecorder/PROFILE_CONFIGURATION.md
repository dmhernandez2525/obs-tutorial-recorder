# Profile Configuration Feature

## Overview

The application now includes a **Profile Configuration UI** that allows you to set up your recording profiles with specific sources (displays, cameras, audio inputs).

## What's New

### 1. ✅ Progress Window Always On Top
- **Window Level:** Changed from `.floating` to `.statusBar`
- **Result:** Progress window now stays above **all** windows, including OBS
- **File:** `Sources/Windows/ProgressWindow.swift:46`

### 2. ✅ Profile Configuration UI
- **New Window:** Profile Setup Window
- **Access:** Tutorial Recorder → **Configure Profiles...** (Cmd+P)
- **Features:**
  - Configure 3 profiles: Mac-MultiScreen, MacBook-Single, PC-10Cameras
  - Select displays to capture
  - Select cameras to use
  - Select audio inputs
  - Automatic source detection
  - Save configurations

### 3. ✅ Automatic Profile Creation
- Profiles are created automatically via OBS WebSocket
- Empty profiles are created first
- You can then configure them through the UI

## How To Use

### Step 1: Start Recording (First Time)

1. Click **Tutorial Recorder** menubar icon
2. Click **"Start Recording..."**
3. Select your setup (e.g., "MacBook Setup (One Screen, Native Camera)")
4. Enter project name
5. Click **"Start Recording"**

**What happens:**
- OBS launches
- App creates all 3 profiles automatically (Mac-MultiScreen, MacBook-Single, PC-10Cameras)
- App switches to your selected profile
- Recording starts

**Log output shows:**
```
[SUCCESS] Successfully created profile: MacBook-Single
[SUCCESS] Successfully switched to profile: MacBook-Single
```

### Step 2: Configure Your Profiles

After your first recording, configure each profile:

1. Click **Tutorial Recorder** menubar icon
2. Click **"Configure Profiles..."** (Cmd+P)
3. The Profile Configuration window opens

**In this window:**
- **Top Tabs:** Switch between Mac-MultiScreen, MacBook-Single, PC-10Cameras
- **Left Column (📺 Displays):** Check which displays to capture
- **Middle Column (📷 Cameras):** Check which cameras to use
- **Right Column (🎤 Audio Inputs):** Check which audio sources to record
- **Bottom:** Click "🔄 Refresh Sources" to re-detect available devices

4. Configure each profile for your setups:

**Example - MacBook-Single:**
- ✓ Display 1 (built-in Retina)
- ✓ FaceTime HD Camera
- ✓ Built-in Microphone

**Example - Mac-MultiScreen:**
- ✓ Display 1
- ✓ Display 2
- ✓ Display 3
- ✓ Camera - ZV-E1
- ✓ Microphone - FIFINE

**Example - PC-10Cameras:**
- ✓ Display 1
- ✓ Camera 1
- ✓ Camera 2
- ✓ Camera 3
- ... (up to 10 cameras)
- ✓ Audio inputs from cameras

5. Click **"Save Configuration"**

### Step 3: Recording with Configured Profiles

Next time you start a recording:

1. Select your setup type
2. OBS switches to that profile
3. **Configured sources are automatically loaded** ✨
4. Recording starts with your preferred setup

## Current Status

### ✅ Working Now
1. Progress window always on top
2. Automatic profile creation via WebSocket
3. Profile switching via WebSocket
4. Profile Configuration UI opens
5. Source detection (displays, cameras, audio)
6. Configuration saves to file

### 🚧 Next Steps (To Implement)

The UI is ready, but we still need to implement:

#### 1. Apply Configuration to OBS Profiles

When you save a profile configuration, we need to:
- Add scene collection to the profile
- Add sources to the scene:
  - Display Capture sources for each checked display
  - Video Capture Device sources for each checked camera
  - Audio Input Capture sources for each checked audio input
- Configure ISO recording for each source

**Implementation needed in:**
- `RecordingManager.swift` - Add `applyProfileConfiguration()` function
- Use OBS WebSocket commands:
  - `CreateSceneCollection`
  - `CreateScene`
  - `CreateInput` (for each source)
  - `SetSceneItemEnabled`

#### 2. Load Configuration When Switching Profiles

When switching to a profile during recording start:
- Check if profile has a configuration saved
- If yes: Verify sources exist
- If no: Show warning "Profile not configured yet"

## Technical Details

### Profile Configuration Storage

**Location:** `~/.config/tutorial-recorder/profile-configs.json`

**Format:**
```json
{
  "Mac Setup (Multiple Screens)": {
    "profileName": "Mac-MultiScreen",
    "displays": ["Display 1", "Display 2", "Display 3"],
    "cameras": ["Camera - ZV-E1"],
    "audioInputs": ["Microphone - FIFINE"],
    "isConfigured": true
  },
  "MacBook Setup (One Screen, Native Camera)": {
    "profileName": "MacBook-Single",
    "displays": ["Display 1"],
    "cameras": ["FaceTime HD Camera"],
    "audioInputs": ["Built-in Microphone"],
    "isConfigured": true
  },
  "PC Setup (One Screen, 10 Cameras)": {
    "profileName": "PC-10Cameras",
    "displays": ["Display 1"],
    "cameras": ["Camera 1", "Camera 2", ... "Camera 10"],
    "audioInputs": ["USB Audio", "HDMI Audio"],
    "isConfigured": true
  }
}
```

### Source Detection

**Displays:**
- Uses `NSScreen.screens.count` to detect available displays
- Names them: "Display 1", "Display 2", "Display 3"

**Cameras:**
- Uses `system_profiler SPCameraDataType` to detect video devices
- Fallback: ["FaceTime HD Camera", "Camera - ZV-E1"]

**Audio Inputs:**
- Uses `system_profiler SPAudioDataType` to detect audio devices
- Fallback: ["Built-in Microphone", "Microphone - FIFINE"]

### OBS WebSocket Commands Used

**Profile Management:**
- `GetProfileList` - Lists all profiles
- `CreateProfile` - Creates a new profile
- `GetCurrentProfile` - Gets active profile name
- `SetCurrentProfile` - Switches to a profile

**Source Management (To Implement):**
- `CreateInput` - Adds a source
- `SetInputSettings` - Configures source settings
- `GetInputList` - Lists available input types

## Testing

### Test Profile Configuration UI

1. Launch Tutorial Recorder
2. Click **"Configure Profiles..."**
3. Window should appear with 3 tabs
4. Click "🔄 Refresh Sources"
5. Check the console logs for detected sources
6. Select some checkboxes
7. Click "Save Configuration"
8. Check `~/.config/tutorial-recorder/profile-configs.json`

### Verify Progress Window

1. **Quit OBS** completely
2. Start a recording
3. **Progress window should appear on top of everything**
4. Watch it stay visible even when OBS launches

### Check Session Logs

1. Start and stop a recording
2. Click **"View Latest Session Log"** (Cmd+L)
3. Look for:
   - `[SUCCESS] Successfully created profile: MacBook-Single`
   - `[INFO] Current OBS profile: Tutorial Recording`
   - `[SUCCESS] Successfully switched to profile: MacBook-Single`

## Known Issues

### Profile Is Empty After Creation

**Status:** Expected behavior

When profiles are created via WebSocket, they start empty (no scenes, no sources). You need to either:
1. **Option A:** Manually configure each profile once in OBS
2. **Option B:** Use the Profile Configuration UI (once OBS source creation is implemented)

### Visual Profile Switch

**Status:** Expected behavior

You'll see OBS briefly show the default profile, then switch to your selected profile. This happens because:
- OBS launches with its default/last-used profile
- We can only switch profiles after OBS is running
- The switch happens before recording starts
- Final recording uses the correct profile

## Files Modified

1. **Sources/Windows/ProgressWindow.swift**
   - Changed window level to `.statusBar` for always-on-top

2. **Sources/Windows/ProfileSetupWindow.swift** ⭐ NEW
   - Profile configuration UI
   - Source detection
   - Configuration save/load

3. **Sources/AppDelegate.swift**
   - Added `profileSetupWindow` property
   - Added "Configure Profiles..." menu item (Cmd+P)
   - Added `showProfileSetup()` method

4. **build.sh**
   - Added ProfileSetupWindow.swift to compilation

## Next Development Steps

To complete the profile configuration feature:

### 1. Implement OBS Source Creation

**File:** `RecordingManager.swift`

Add function:
```swift
func applyProfileConfiguration(_ config: ProfileConfiguration) {
    // 1. Switch to profile
    // 2. Create scene collection
    // 3. Create scene "Tutorial Recording"
    // 4. Add display capture sources
    // 5. Add video device sources (cameras)
    // 6. Add audio input sources
    // 7. Configure ISO recording
    // 8. Save
}
```

### 2. Integrate with Recording Start

**File:** `RecordingManager.swift:208-210`

After `ensureProfilesExist()`:
```swift
// Load and apply saved configuration
if let config = loadProfileConfig(for: setupType) {
    if config.isConfigured {
        applyProfileConfiguration(config)
    } else {
        logWarning("Profile \(setupType.displayName) not configured yet")
    }
}
```

### 3. Add First-Time Setup Wizard

**Trigger:** First launch or when no profiles are configured

Show profile configuration window automatically:
```swift
func checkProfileConfigurations() {
    let configs = loadAllProfileConfigs()
    let unconfigured = configs.filter { !$0.value.isConfigured }

    if unconfigured.count == 3 {
        // No profiles configured, show wizard
        showProfileSetupWizard()
    }
}
```

## Build

✅ **Status:** Compiled successfully
📦 **Location:** `~/Desktop/Tutorial Recorder.app`

**To test:**
1. Launch the app
2. Click **"Configure Profiles..."**
3. Explore the UI
4. Check detected sources
5. Save a configuration
6. Verify saved file exists

The foundation is ready! Next steps are to implement the OBS source creation logic to actually apply these configurations to the profiles.
