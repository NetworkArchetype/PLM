"""
PLM Security Module
Provides security infrastructure for version control and CI policy enforcement.
"""

from .ci_policy_check import verify_protected_paths, get_protected_paths, is_authorized_actor

__all__ = ['verify_protected_paths', 'get_protected_paths', 'is_authorized_actor']
__version__ = '0.1.0'
