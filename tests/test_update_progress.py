import pytest
import sys
import os

# Add the core directory to path to avoid importing the web_ui package
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'web_ui', 'core'))

from update_progress import UpdateProgress

def test_update_progress_state():
    # Test that UpdateProgress class exists and works
    progress = UpdateProgress()
    assert progress.status == 'idle'