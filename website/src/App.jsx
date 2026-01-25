import './App.css'

function App() {
  return (
    <div className="app">
      <header className="hero">
        <nav className="nav">
          <div className="logo">
            <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
              <circle cx="16" cy="16" r="14" fill="url(#grad1)" />
              <circle cx="16" cy="16" r="6" fill="white" />
              <circle cx="16" cy="16" r="3" fill="#e53e3e" className="pulse" />
              <defs>
                <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#e53e3e" />
                  <stop offset="100%" stopColor="#c53030" />
                </linearGradient>
              </defs>
            </svg>
            <span>Tutorial Recorder</span>
          </div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#profiles">Profiles</a>
            <a href="#workflow">Workflow</a>
            <a href="#iso-recording">ISO Recording</a>
            <a href="#installation">Install</a>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder" target="_blank" rel="noopener noreferrer" className="github-link">GitHub</a>
          </div>
        </nav>
        <div className="hero-content">
          <div className="badge">macOS Only</div>
          <h1>Professional Tutorial Recording Made Simple</h1>
          <p className="tagline">Automated OBS setup with intelligent profile detection, ISO recordings, local AI transcription, and cloud sync. One-click recording for coding tutorials.</p>
          <div className="hero-buttons">
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder" className="btn btn-primary">Get Started</a>
            <a href="#features" className="btn btn-secondary">Learn More</a>
          </div>
        </div>
      </header>

      <section id="features" className="features">
        <h2>Features</h2>
        <div className="feature-grid">
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <rect x="8" y="12" width="32" height="24" rx="3" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <circle cx="24" cy="24" r="6" fill="#e53e3e"/>
                <path d="M38 18l4-4M38 30l4 4M10 18l-4-4M10 30l-4 4" stroke="#e53e3e" strokeWidth="2"/>
              </svg>
            </div>
            <h3>One-Click Recording</h3>
            <p>Double-click the app, select your profile, enter a project name, and start recording. OBS launches and configures automatically.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <rect x="4" y="8" width="18" height="14" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="26" y="8" width="18" height="14" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="4" y="26" width="18" height="14" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="26" y="26" width="18" height="14" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
              </svg>
            </div>
            <h3>ISO Recordings</h3>
            <p>Each source (screen, camera, audio) recorded to separate files for maximum editing flexibility in post-production.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <path d="M24 8v8M24 32v8M8 24h8M32 24h8" stroke="#e53e3e" strokeWidth="2"/>
                <circle cx="24" cy="24" r="12" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <path d="M24 18v6l4 4" stroke="#e53e3e" strokeWidth="2"/>
              </svg>
            </div>
            <h3>Smart Profile Detection</h3>
            <p>Automatically detects your hardware setup and creates optimized OBS profiles for MacBook, external displays, and multi-monitor configurations.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <path d="M12 36V20a4 4 0 014-4h16a4 4 0 014 4v16" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <path d="M8 36h32M16 28h4M28 28h4M16 22h16" stroke="#e53e3e" strokeWidth="2"/>
                <circle cx="24" cy="10" r="4" fill="#e53e3e"/>
              </svg>
            </div>
            <h3>Local AI Transcription</h3>
            <p>Audio automatically transcribed using Whisper AI. Runs 100% locally on your Mac, no API keys or cloud services needed.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <path d="M24 8l-8 12h16L24 8z" fill="#e53e3e"/>
                <path d="M16 20v16c0 2 2 4 4 4h8c2 0 4-2 4-4V20" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <path d="M20 28h8M20 34h8" stroke="#e53e3e" strokeWidth="2"/>
              </svg>
            </div>
            <h3>Google Drive Sync</h3>
            <p>Automatic backup to Google Drive with real-time sync status panel. Never lose your recordings again.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
                <rect x="8" y="6" width="32" height="6" rx="2" fill="#e53e3e"/>
                <circle cx="12" cy="9" r="1.5" fill="white"/>
                <path d="M8 16h32v24H8V16z" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <circle cx="24" cy="28" r="8" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <circle cx="24" cy="28" r="3" fill="#e53e3e"/>
              </svg>
            </div>
            <h3>Native Menubar App</h3>
            <p>macOS menubar app with recording status indicator, quick controls, session logs, and animated sync icon.</p>
          </div>
        </div>
      </section>

      <section id="profiles" className="profiles-section">
        <h2>Intelligent Profile System</h2>
        <p className="section-description">Automatically detects your hardware and creates optimized OBS profiles. No manual configuration required.</p>
        <div className="profile-grid">
          <div className="profile-card">
            <div className="profile-icon">
              <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
                <rect x="8" y="16" width="48" height="32" rx="4" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="24" y="48" width="16" height="4" fill="#e53e3e"/>
                <rect x="20" y="52" width="24" height="2" rx="1" fill="#e53e3e"/>
                <circle cx="32" cy="32" r="8" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <circle cx="32" cy="32" r="3" fill="#e53e3e"/>
              </svg>
            </div>
            <h3>MacBook Single</h3>
            <p className="profile-desc">Built-in display + FaceTime camera + microphone</p>
            <ul className="profile-sources">
              <li>Screen 1 (1920×1080)</li>
              <li>FaceTime HD Camera</li>
              <li>Built-in Microphone</li>
            </ul>
          </div>
          <div className="profile-card">
            <div className="profile-icon">
              <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
                <rect x="2" y="20" width="28" height="18" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="34" y="12" width="28" height="22" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="44" y="34" width="8" height="8" fill="#e53e3e"/>
                <circle cx="16" cy="29" r="4" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <circle cx="48" cy="23" r="4" stroke="#e53e3e" strokeWidth="2" fill="none"/>
              </svg>
            </div>
            <h3>MacBook + External</h3>
            <p className="profile-desc">MacBook + external display with external camera</p>
            <ul className="profile-sources">
              <li>Screen 1 (MacBook)</li>
              <li>Screen 2 (External)</li>
              <li>External Camera</li>
              <li>External Microphone</li>
            </ul>
          </div>
          <div className="profile-card">
            <div className="profile-icon">
              <svg width="64" height="64" viewBox="0 0 64 64" fill="none">
                <rect x="2" y="16" width="28" height="20" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="34" y="16" width="28" height="20" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
                <rect x="14" y="40" width="36" height="12" rx="2" fill="#e53e3e" opacity="0.2"/>
                <rect x="14" y="40" width="36" height="12" rx="2" stroke="#e53e3e" strokeWidth="2" fill="none"/>
              </svg>
            </div>
            <h3>Dual Monitor</h3>
            <p className="profile-desc">Two displays with external peripherals</p>
            <ul className="profile-sources">
              <li>Screen 1 (Primary)</li>
              <li>Screen 2 (Secondary)</li>
              <li>External Camera</li>
              <li>External Microphone</li>
            </ul>
          </div>
        </div>
        <div className="profile-wizard-info">
          <h3>First-Time Setup Wizard</h3>
          <p>On first launch, the app automatically detects your connected displays, cameras, and microphones, then creates the appropriate OBS profile. You can reconfigure anytime from the menubar.</p>
        </div>
      </section>

      <section id="workflow" className="workflow-section">
        <h2>How It Works</h2>
        <div className="workflow">
          <div className="workflow-step">
            <div className="step-number">1</div>
            <h3>Launch & Setup</h3>
            <p>First time: wizard detects hardware and creates OBS profile automatically.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">2</div>
            <h3>Select & Start</h3>
            <p>Choose profile, enter project name. OBS launches with all sources configured.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">3</div>
            <h3>Record</h3>
            <p>All sources record to separate ISO files. Session log tracks everything.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">4</div>
            <h3>Process & Sync</h3>
            <p>Audio extracted, transcription runs locally, files sync to Google Drive.</p>
          </div>
        </div>
      </section>

      <section id="iso-recording" className="iso-section">
        <h2>ISO Recording with Source Record</h2>
        <p className="section-description">Each source is recorded to a separate file using the Source Record plugin. Full quality, maximum flexibility.</p>
        <div className="iso-grid">
          <div className="iso-card">
            <h3>Screen Capture</h3>
            <p className="iso-file">Screen_1.mov</p>
            <p>Full resolution screen recording</p>
          </div>
          <div className="iso-card">
            <h3>Camera</h3>
            <p className="iso-file">FaceTime_HD_Camera.mov</p>
            <p>Independent camera recording</p>
          </div>
          <div className="iso-card">
            <h3>Audio</h3>
            <p className="iso-file">audio.aac</p>
            <p>Extracted audio track</p>
          </div>
          <div className="iso-card">
            <h3>Composite</h3>
            <p className="iso-file">composite.mov</p>
            <p>Combined fallback recording</p>
          </div>
        </div>
        <div className="iso-benefits">
          <h3>Benefits of ISO Recording</h3>
          <ul>
            <li>Full resolution per source - no quality loss from combining</li>
            <li>Crop, zoom, or reframe any source in post-production</li>
            <li>Mix and match sources during editing</li>
            <li>Replace camera angle without re-recording</li>
            <li>Automatic sync with OBS main recording</li>
          </ul>
        </div>
      </section>

      <section className="transcription">
        <h2>Local AI Transcription</h2>
        <p className="section-description">Powered by whisper-cpp running entirely on your Mac. No API keys, no cloud, no cost.</p>
        <div className="model-grid">
          <div className="model-card">
            <h3>Tiny</h3>
            <p className="model-size">75MB</p>
            <p>Very Fast</p>
            <p className="model-use">Quick drafts, testing</p>
          </div>
          <div className="model-card">
            <h3>Base</h3>
            <p className="model-size">150MB</p>
            <p>Fast</p>
            <p className="model-use">Good balance</p>
          </div>
          <div className="model-card recommended">
            <h3>Small</h3>
            <p className="model-size">500MB</p>
            <p>Medium</p>
            <p className="model-use">Recommended for tutorials</p>
          </div>
          <div className="model-card">
            <h3>Medium</h3>
            <p className="model-size">1.5GB</p>
            <p>Slow</p>
            <p className="model-use">Maximum accuracy</p>
          </div>
        </div>
      </section>

      <section className="coming-soon">
        <div className="coming-soon-badge">Coming Soon</div>
        <h2>Live Recording Assistant</h2>
        <p className="section-description">Control your recordings with natural voice commands. Powered by PersonaPlex full duplex AI.</p>

        <div className="coming-soon-grid">
          <div className="coming-soon-before">
            <h3>Current Experience</h3>
            <ul>
              <li>Click menubar icon</li>
              <li>Select profile from dropdown</li>
              <li>Enter project name</li>
              <li>Click Start button</li>
              <li>Record your tutorial</li>
              <li>Click Stop button</li>
            </ul>
          </div>

          <div className="coming-soon-after">
            <h3>With PersonaPlex</h3>
            <div className="conversation">
              <div className="user-msg">
                <span className="speaker">You:</span> "Start recording the auth tutorial"
              </div>
              <div className="assistant-msg">
                <span className="speaker">Assistant:</span> "Got it, starting authentication tutorial..."
              </div>
              <div className="user-msg">
                <span className="speaker">You:</span> "Add a marker for the login section"
              </div>
              <div className="assistant-msg">
                <span className="speaker">Assistant:</span> "Marker added at 2:45"
              </div>
            </div>
          </div>
        </div>

        <div className="coming-soon-features">
          <div className="cs-feature">
            <span className="cs-stat">&lt;500ms</span>
            <span className="cs-label">Response Time</span>
          </div>
          <div className="cs-feature">
            <span className="cs-stat">Full Duplex</span>
            <span className="cs-label">Natural Interruption</span>
          </div>
          <div className="cs-feature">
            <span className="cs-stat">100%</span>
            <span className="cs-label">Local Processing</span>
          </div>
          <div className="cs-feature">
            <span className="cs-stat">Hands-Free</span>
            <span className="cs-label">Voice Control</span>
          </div>
        </div>
      </section>

      <section className="folder-structure">
        <h2>Organized Output</h2>
        <p className="section-description">Every recording session is automatically organized with session logs and metadata.</p>
        <pre className="folder-tree">
{`~/Desktop/Tutorial Recordings/
└── 2026-01-21_project-name/
    ├── raw/
    │   └── 2026-01-21 14-30-00/
    │       ├── Screen_1.mov        ← ISO screen capture
    │       ├── FaceTime_HD_Camera.mov  ← ISO camera
    │       ├── composite.mov       ← Combined recording
    │       ├── audio.aac           ← Extracted audio
    │       └── transcript.txt      ← AI transcription
    ├── exports/                    ← Your edited videos
    ├── session.log                 ← Full session log
    └── metadata.json               ← Recording metadata`}
        </pre>
      </section>

      <section id="installation" className="installation">
        <h2>Installation</h2>
        <div className="install-steps">
          <div className="install-step">
            <h3>1. Clone & Install</h3>
            <pre><code>{`git clone https://github.com/dmhernandez2525/obs-tutorial-recorder.git
cd obs-tutorial-recorder
./install.sh`}</code></pre>
            <p>The install script automatically installs OBS, Source Record plugin, whisper-cpp, ffmpeg, and all dependencies.</p>
          </div>
          <div className="install-step">
            <h3>2. Grant Permissions</h3>
            <p>When prompted, allow Screen Recording, Camera, and Microphone access for OBS in System Settings → Privacy & Security.</p>
          </div>
          <div className="install-step">
            <h3>3. First Launch</h3>
            <p>Double-click Tutorial Recorder.app. The setup wizard detects your hardware and creates OBS profiles automatically.</p>
          </div>
          <div className="install-step">
            <h3>4. Start Recording</h3>
            <p>Select your profile, enter a project name, and click Start. That's it!</p>
          </div>
        </div>
      </section>

      <section className="requirements">
        <h2>Requirements</h2>
        <div className="req-grid">
          <div className="req-card">
            <h3>System</h3>
            <ul>
              <li>macOS 12.0 (Monterey) or later</li>
              <li>Apple Silicon or Intel Mac</li>
              <li>Homebrew package manager</li>
            </ul>
          </div>
          <div className="req-card">
            <h3>Hardware</h3>
            <ul>
              <li>Built-in or external camera</li>
              <li>Built-in or external microphone</li>
              <li>One or more displays</li>
            </ul>
          </div>
          <div className="req-card">
            <h3>Auto-Installed</h3>
            <ul>
              <li>OBS Studio 32+</li>
              <li>Source Record plugin</li>
              <li>whisper-cpp (local AI)</li>
              <li>ffmpeg, websocat, rclone</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="cta-section">
        <h2>Ready to Start Recording?</h2>
        <p>Get professional tutorial recordings with automatic ISO capture, transcription, and cloud sync.</p>
        <div className="cta-buttons">
          <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder" className="btn btn-primary btn-large">Download on GitHub</a>
          <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder#readme" className="btn btn-secondary btn-large">Read Documentation</a>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-content">
          <div className="footer-section">
            <h3>Tutorial Recorder</h3>
            <p>Automated OBS recording setup for professional coding tutorials on macOS.</p>
          </div>
          <div className="footer-section">
            <h3>Links</h3>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder">GitHub Repository</a>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder/issues">Report Issues</a>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder/blob/main/LICENSE">MIT License</a>
          </div>
          <div className="footer-section">
            <h3>Powered By</h3>
            <a href="https://obsproject.com">OBS Studio</a>
            <a href="https://github.com/exeldro/obs-source-record">Source Record Plugin</a>
            <a href="https://github.com/ggerganov/whisper.cpp">whisper.cpp</a>
          </div>
        </div>
        <div className="footer-bottom">
          <p>MIT License • Open Source</p>
        </div>
      </footer>
    </div>
  )
}

export default App
