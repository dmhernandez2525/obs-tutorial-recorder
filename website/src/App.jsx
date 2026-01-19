import './App.css'

function App() {
  return (
    <div className="app">
      <header className="hero">
        <nav className="nav">
          <div className="logo">OBS Tutorial Recorder</div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#workflow">Workflow</a>
            <a href="#iso-recording">ISO Recording</a>
            <a href="#installation">Install</a>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder" target="_blank" rel="noopener noreferrer" className="github-link">GitHub</a>
          </div>
        </nav>
        <div className="hero-content">
          <div className="badge">macOS Only</div>
          <h1>Professional Tutorial Recording Made Simple</h1>
          <p className="tagline">Automated OBS setup with ISO recordings, auto-transcription, and cloud sync. One-click recording for coding tutorials.</p>
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
            <div className="feature-icon">🎬</div>
            <h3>One-Click Recording</h3>
            <p>Double-click the app, enter a project name, and start recording. OBS launches automatically.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">📹</div>
            <h3>ISO Recordings</h3>
            <p>Each source (screens, camera) recorded separately for maximum editing flexibility.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🎙️</div>
            <h3>Auto Transcription</h3>
            <p>Audio automatically transcribed using Whisper AI. Runs 100% locally, no API needed.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">☁️</div>
            <h3>Cloud Sync</h3>
            <p>Automatic backup to Google Drive with real-time sync status panel.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🖥️</div>
            <h3>Menubar App</h3>
            <p>Native macOS app with status indicator, quick controls, and animated sync icon.</p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">📁</div>
            <h3>Auto Organization</h3>
            <p>Dated folders with raw and exports subdirectories. All files automatically collected.</p>
          </div>
        </div>
      </section>

      <section id="workflow" className="workflow-section">
        <h2>How It Works</h2>
        <div className="workflow">
          <div className="workflow-step">
            <div className="step-number">1</div>
            <h3>Click to Start</h3>
            <p>Double-click the Tutorial Recorder app. Enter your project name.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">2</div>
            <h3>Record</h3>
            <p>OBS launches automatically. All sources record independently.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">3</div>
            <h3>Stop & Collect</h3>
            <p>Click stop. All ISO files collected to your project folder.</p>
          </div>
          <div className="workflow-arrow">→</div>
          <div className="workflow-step">
            <div className="step-number">4</div>
            <h3>Auto Processing</h3>
            <p>Audio extracted, transcription runs, files sync to cloud.</p>
          </div>
        </div>
      </section>

      <section id="iso-recording" className="iso-section">
        <h2>ISO Recording Explained</h2>
        <p className="section-description">Each source is recorded to a separate file for maximum post-production flexibility.</p>
        <div className="iso-grid">
          <div className="iso-card">
            <h3>Screen 1</h3>
            <p className="iso-file">Screen 1.mkv</p>
            <p>Main coding display</p>
          </div>
          <div className="iso-card">
            <h3>Screen 2</h3>
            <p className="iso-file">Screen 2.mkv</p>
            <p>Reference/documentation</p>
          </div>
          <div className="iso-card">
            <h3>Camera</h3>
            <p className="iso-file">Camera.mkv</p>
            <p>Picture-in-picture, reactions</p>
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
            <li>Full resolution per source (no quality loss from combining)</li>
            <li>Crop/reframe any source in post-production</li>
            <li>Mix and match sources during editing</li>
            <li>Keep or discard sources as needed</li>
          </ul>
        </div>
      </section>

      <section className="transcription">
        <h2>Automatic Transcription</h2>
        <p className="section-description">Powered by Whisper AI running locally on your Mac.</p>
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

      <section className="folder-structure">
        <h2>Organized Output</h2>
        <pre className="folder-tree">
{`~/Desktop/Tutorial Recordings/
└── 2026-01-18_project-name/
    ├── raw/
    │   └── 2026-01-18 13-00-00/
    │       ├── Screen 1.mkv
    │       ├── Screen 2.mkv
    │       ├── Camera - ZV-E10.mkv
    │       ├── composite.mov
    │       ├── audio.aac
    │       └── transcript.txt
    ├── exports/
    ├── session.log
    └── metadata.json`}
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
          </div>
          <div className="install-step">
            <h3>2. Configure OBS</h3>
            <p>Enable WebSocket server, add your sources (screens, camera, microphone).</p>
          </div>
          <div className="install-step">
            <h3>3. Grant Permissions</h3>
            <p>Enable Screen Recording, Camera, and Microphone for OBS in System Settings.</p>
          </div>
          <div className="install-step">
            <h3>4. Start Recording</h3>
            <p>Double-click Tutorial Recorder.app on your Desktop!</p>
          </div>
        </div>
      </section>

      <section className="requirements">
        <h2>Requirements</h2>
        <div className="req-grid">
          <div className="req-card">
            <h3>Software</h3>
            <ul>
              <li>macOS 12.0 or later</li>
              <li>Homebrew</li>
            </ul>
          </div>
          <div className="req-card">
            <h3>Hardware</h3>
            <ul>
              <li>Camera (webcam, capture card, etc.)</li>
              <li>Microphone</li>
              <li>One or more displays</li>
            </ul>
          </div>
          <div className="req-card">
            <h3>Auto-Installed</h3>
            <ul>
              <li>OBS Studio</li>
              <li>Source Record plugin</li>
              <li>whisper-cpp</li>
              <li>ffmpeg, rclone</li>
            </ul>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-content">
          <div className="footer-section">
            <h3>OBS Tutorial Recorder</h3>
            <p>Automated recording setup for coding tutorials on macOS.</p>
          </div>
          <div className="footer-section">
            <h3>Links</h3>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder">GitHub Repository</a>
            <a href="https://github.com/dmhernandez2525/obs-tutorial-recorder/blob/main/LICENSE">MIT License</a>
          </div>
        </div>
        <div className="footer-bottom">
          <p>MIT License - Open Source</p>
        </div>
      </footer>
    </div>
  )
}

export default App
