#!/usr/bin/env python
"""
OBS Tutorial Recorder - Windows
Launcher script (no console window).
"""

import sys
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

# Import and run
from run import main

if __name__ == "__main__":
    main()
