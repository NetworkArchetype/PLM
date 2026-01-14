"""
PLM Security Module
Provides security infrastructure for version control and CI policy enforcement.
"""

from .ci_policy_check import _is_protected as is_protected_path
from .check_commit_auth import check_author_authorization, AUTHORIZED_EMAIL, AUTHORIZED_OWNER

__all__ = ['is_protected_path', 'check_author_authorization', 'AUTHORIZED_EMAIL', 'AUTHORIZED_OWNER']
__version__ = '0.1.0'
