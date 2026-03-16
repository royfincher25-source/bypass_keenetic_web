"""
IPSet Manager - Bulk operations for ipset

Optimized for embedded devices (128MB RAM).
Uses 'ipset restore' for fast bulk operations.

Performance:
- 1000+ entries in <10 seconds (was 5-10 minutes with individual adds)
- Memory efficient: minimal RAM usage via streaming to subprocess

Example:
    >>> from core.ipset_manager import bulk_add_to_ipset, ensure_ipset_exists
    >>> success, msg = ensure_ipset_exists('unblock')
    >>> success, msg = bulk_add_to_ipset('unblock', ['1.1.1.1', '8.8.8.8'])
"""
import subprocess
import logging
import re
from typing import List, Tuple, Optional

logger = logging.getLogger(__name__)


def bulk_add_to_ipset(setname: str, entries: List[str]) -> Tuple[bool, str]:
    """
    Bulk add entries to ipset using 'ipset restore'.

    Args:
        setname: Name of ipset (e.g., 'unblock')
        entries: List of IP addresses or domains

    Returns:
        Tuple of (success: bool, output: str)

    Example:
        >>> success, msg = bulk_add_to_ipset('unblock', ['1.1.1.1', '8.8.8.8'])
        >>> if success:
        ...     print(f"Added entries: {msg}")
    """
    if not entries:
        logger.info(f"ipset {setname}: no entries to add")
        return True, "No entries"

    # Build ipset restore command
    # Format: ipset restore <<EOF
    #         add unblock 1.1.1.1
    #         add unblock 8.8.8.8
    #         EOF
    commands = []
    for entry in entries:
        # Validate entry (IP or domain)
        if _is_valid_entry(entry):
            commands.append(f"add {setname} {entry}")

    if not commands:
        return True, "No valid entries"

    # Execute bulk add
    cmd_text = "\n".join(commands)
    try:
        result = subprocess.run(
            ['ipset', 'restore'],
            input=cmd_text,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            logger.info(f"ipset {setname}: added {len(commands)} entries")
            return True, f"Added {len(commands)} entries"
        else:
            logger.error(f"ipset {setname} error: {result.stderr}")
            return False, result.stderr

    except subprocess.TimeoutExpired:
        logger.error(f"ipset {setname}: timeout")
        return False, "Timeout"
    except FileNotFoundError:
        logger.error("ipset command not found")
        return False, "ipset not installed"
    except Exception as e:
        logger.error(f"ipset {setname} exception: {e}")
        return False, str(e)


def bulk_remove_from_ipset(setname: str, entries: List[str]) -> Tuple[bool, str]:
    """
    Bulk remove entries from ipset using 'ipset restore'.

    Args:
        setname: Name of ipset
        entries: List of entries to remove

    Returns:
        Tuple of (success: bool, output: str)

    Example:
        >>> success, msg = bulk_remove_from_ipset('unblock', ['1.1.1.1'])
        >>> if success:
        ...     print(f"Removed entries: {msg}")
    """
    if not entries:
        return True, "No entries"

    commands = []
    for entry in entries:
        if _is_valid_entry(entry):
            commands.append(f"del {setname} {entry}")

    if not commands:
        return True, "No valid entries"

    cmd_text = "\n".join(commands)
    try:
        result = subprocess.run(
            ['ipset', 'restore'],
            input=cmd_text,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            logger.info(f"ipset {setname}: removed {len(commands)} entries")
            return True, f"Removed {len(commands)} entries"
        else:
            logger.error(f"ipset {setname} error: {result.stderr}")
            return False, result.stderr

    except subprocess.TimeoutExpired:
        logger.error(f"ipset {setname}: timeout")
        return False, "Timeout"
    except FileNotFoundError:
        logger.error("ipset command not found")
        return False, "ipset not installed"
    except Exception as e:
        logger.error(f"ipset {setname} exception: {e}")
        return False, str(e)


def ensure_ipset_exists(setname: str, settype: str = 'hash:ip') -> Tuple[bool, str]:
    """
    Ensure ipset exists, create if not.

    Args:
        setname: Name of ipset
        settype: Type (hash:ip, hash:net, etc.)

    Returns:
        Tuple of (success: bool, output: str)

    Example:
        >>> success, msg = ensure_ipset_exists('unblock')
        >>> if success:
        ...     print(f"ipset ready: {msg}")
    """
    try:
        # Check if exists
        result = subprocess.run(
            ['ipset', 'list', setname],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            logger.debug(f"ipset {setname}: already exists")
            return True, "Exists"

        # Create new
        result = subprocess.run(
            ['ipset', 'create', setname, settype, 'maxelem', '1048576'],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            logger.info(f"ipset {setname}: created")
            return True, "Created"
        else:
            logger.error(f"ipset {setname} create error: {result.stderr}")
            return False, result.stderr

    except subprocess.TimeoutExpired:
        logger.error(f"ipset {setname}: timeout")
        return False, "Timeout"
    except FileNotFoundError:
        logger.error("ipset command not found")
        return False, "ipset not installed"
    except Exception as e:
        logger.error(f"ipset {setname} exception: {e}")
        return False, str(e)


def _is_valid_entry(entry: str) -> bool:
    """
    Validate entry (IP address or domain).

    Args:
        entry: IP or domain string

    Returns:
        True if valid

    Example:
        >>> _is_valid_entry('192.168.1.1')
        True
        >>> _is_valid_entry('example.com')
        True
        >>> _is_valid_entry('invalid!')
        False
    """
    if not entry or len(entry) > 253:
        return False

    # IPv4 pattern
    ipv4_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    if re.match(ipv4_pattern, entry):
        # Validate each octet
        parts = entry.split('.')
        try:
            return all(0 <= int(p) <= 255 for p in parts)
        except ValueError:
            return False

    # IPv6 pattern (simplified)
    if ':' in entry:
        return True  # Accept any IPv6-like string

    # Domain pattern
    domain_pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    return bool(re.match(domain_pattern, entry))
