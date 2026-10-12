"""
Pagarme SDK wrapper with path fix for bundled usage.

The Pagar.me SDK uses absolute imports (from pagarmeapisdk.xxx) which fail
when the SDK is bundled inside another package. This module adds the SDK
directory to sys.path before any SDK imports occur.
"""
import sys
from pathlib import Path

# Add the pagarme_sdk directory to sys.path so that absolute imports
# like "from pagarmeapisdk.xxx import yyy" work correctly
_sdk_path = str(Path(__file__).parent)
if _sdk_path not in sys.path:
    sys.path.insert(0, _sdk_path)

# Now import and expose the main SDK module
from pagarmeapisdk import *
from pagarmeapisdk.pagarmeapisdk_client import PagarmeapisdkClient

__all__ = ['PagarmeapisdkClient']
