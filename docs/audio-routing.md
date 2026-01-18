# Audio Routing for Simultaneous OBS Recording + macOS Dictation

## The Challenge

You want to:
1. Record audio from your FIFINE microphone in OBS
2. Use macOS dictation (speech-to-text) while recording
3. Both should work simultaneously without conflict

## Good News: macOS Handles This Automatically

Unlike some operating systems, **macOS allows multiple applications to access the same audio input device simultaneously**. This means:

- OBS can capture audio from your FIFINE SC3 microphone
- macOS Dictation can also use the same microphone
- Both work at the same time without any additional configuration

### Verification Steps

1. **Start an OBS recording** with the FIFINE mic as your audio source
2. **Trigger dictation** (press `fn` twice or your configured shortcut)
3. **Speak** - you should see:
   - Audio levels moving in OBS mixer
   - Text appearing from dictation
4. **Check the recording** - your voice should be captured

If this works (which it should), you're done! No additional setup needed.

---

## Troubleshooting: If Dictation Doesn't Work While Recording

If you encounter issues, here are solutions:

### Option 1: Check System Preferences

1. **System Settings > Sound > Input**
   - Ensure "fifine SC3" is selected as the input device

2. **System Settings > Keyboard > Dictation**
   - Ensure Dictation is enabled
   - Check the microphone source (should be "fifine SC3" or "Automatic")

### Option 2: Create an Aggregate Audio Device

If apps conflict over the microphone, create an Aggregate Device:

1. Open **Audio MIDI Setup** (in /Applications/Utilities/)
2. Click the **+** button at bottom-left
3. Select **Create Aggregate Device**
4. Check **fifine SC3** in the device list
5. Rename it to "FIFINE Aggregate"
6. Use this aggregate device in both OBS and System Preferences

### Option 3: Use BlackHole (Virtual Audio Cable)

For more advanced routing, install BlackHole:

```bash
brew install blackhole-2ch
```

Then set up audio routing:

1. **Audio MIDI Setup > Create Multi-Output Device**
   - Include: fifine SC3 + BlackHole 2ch
   - This sends mic audio to both destinations

2. **In OBS**: Use BlackHole 2ch as audio input
3. **In System Preferences**: Keep fifine SC3 as input

This creates parallel audio paths that don't interfere.

### Option 4: Use Loopback (Paid, More Features)

[Loopback by Rogue Amoeba](https://rogueamoeba.com/loopback/) provides a GUI for complex audio routing. It's paid software but very reliable.

---

## Recommended Configuration

For most users, the **default macOS behavior works fine**. Only pursue Options 2-4 if you experience actual conflicts.

### OBS Audio Settings

1. **Settings > Audio**
   - Sample Rate: 48 kHz
   - Channels: Stereo

2. **Sources > Audio Input Capture**
   - Device: fifine SC3
   - Don't use "Default" - select the specific device

### Dictation Settings

1. **System Settings > Keyboard > Dictation**
   - Dictation: On
   - Microphone: Automatic (or fifine SC3)
   - Shortcut: Press fn twice (or customize)

---

## Testing Checklist

- [ ] OBS shows audio levels from FIFINE mic
- [ ] Recording captures voice clearly
- [ ] Dictation activates while OBS is recording
- [ ] Dictation accurately transcribes speech
- [ ] No audio dropouts or conflicts
- [ ] Both work simultaneously for extended periods

If all checks pass, your audio routing is working correctly.
