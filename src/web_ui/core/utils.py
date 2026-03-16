"""
Bypass Keenetic Web Interface - Core Utilities

Memory-optimized utilities for embedded devices (128MB RAM).
- LRU cache with 50 entry limit (reduced from 100)
- Efficient file operations
- Minimal memory footprint
- Log rotation (100KB × 3 = 300KB max)
"""
import os
import re
import time
import subprocess
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import List, Tuple, Optional, Any, Dict

LOG_FILE = os.environ.get('LOG_FILE', '/opt/var/log/web_ui.log')
LOG_MAX_BYTES = 100 * 1024  # 100KB
LOG_BACKUP_COUNT = 3  # 3 backup files = 300KB max

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

if LOG_FILE:
    try:
        log_dir = os.path.dirname(LOG_FILE)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        # RotatingFileHandler с ротацией для embedded-устройств
        file_handler = RotatingFileHandler(
            LOG_FILE,
            maxBytes=LOG_MAX_BYTES,
            backupCount=LOG_BACKUP_COUNT
        )
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
        logging.getLogger().addHandler(file_handler)
        logger.info(f"Log rotation enabled: {LOG_MAX_BYTES} bytes × {LOG_BACKUP_COUNT} files")
    except Exception as e:
        logger.error(f"Failed to setup log rotation: {e}")
        pass

logger = logging.getLogger(__name__)


# =============================================================================
# LRU CACHE (MEMORY-OPTIMIZED)
# =============================================================================

class Cache:
    """
    LRU cache with TTL and memory limit (50 entries for embedded devices).

    Optimized for embedded devices with limited RAM (128MB).
    Reduced from 100 to 50 entries to save ~15KB memory.

    Attributes:
        _cache: Dictionary storing cached values
        _timestamps: Dictionary storing cache timestamps
        _access_order: List tracking access order for LRU eviction
        MAX_ENTRIES: Maximum number of cache entries (default: 50)

    Example:
        >>> Cache.set("key", "value", ttl=60)
        >>> Cache.get("key")
        'value'
        >>> Cache.is_valid("key")
        True
    """

    _cache: Dict[str, Any] = {}
    _timestamps: Dict[str, float] = {}
    _access_order: List[str] = []
    MAX_ENTRIES: int = 50  # Reduced from 100 for embedded devices
    
    @classmethod
    def set(cls, key: str, value: Any, ttl: int = 60) -> None:
        """
        Set cache value with TTL.
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds (default: 60)
        """
        # LRU eviction if cache is full
        if len(cls._cache) >= cls.MAX_ENTRIES and key not in cls._cache:
            cls._evict_oldest()
        
        cls._cache[key] = value
        cls._timestamps[key] = time.time() + ttl
        
        # Update access order
        if key in cls._access_order:
            cls._access_order.remove(key)
        cls._access_order.append(key)
    
    @classmethod
    def get(cls, key: str, default: Any = None) -> Any:
        """
        Get cached value.
        
        Args:
            key: Cache key
            default: Default value if not found or expired
        
        Returns:
            Cached value or default
        """
        if not cls.is_valid(key):
            return default
        
        # Update access order
        if key in cls._access_order:
            cls._access_order.remove(key)
            cls._access_order.append(key)
        
        return cls._cache.get(key, default)
    
    @classmethod
    def is_valid(cls, key: str) -> bool:
        """
        Check if cache entry is valid (exists and not expired).
        
        Args:
            key: Cache key
        
        Returns:
            True if valid, False otherwise
        """
        if key not in cls._cache:
            return False
        
        if time.time() > cls._timestamps.get(key, 0):
            # Expired - remove
            cls._remove(key)
            return False
        
        return True
    
    @classmethod
    def _remove(cls, key: str) -> None:
        """Remove cache entry."""
        cls._cache.pop(key, None)
        cls._timestamps.pop(key, None)
        if key in cls._access_order:
            cls._access_order.remove(key)
    
    @classmethod
    def _evict_oldest(cls) -> None:
        """Evict oldest (least recently used) entry."""
        if cls._access_order:
            oldest = cls._access_order[0]
            cls._remove(oldest)
    
    @classmethod
    def clear(cls) -> None:
        """Clear all cache entries."""
        cls._cache.clear()
        cls._timestamps.clear()
        cls._access_order.clear()

    @classmethod
    def cleanup_expired(cls) -> int:
        """
        Remove expired entries from cache.
        
        Returns:
            Number of entries removed
            
        Example:
            >>> removed = Cache.cleanup_expired()
            >>> print(f"Cleaned up {removed} expired entries")
        """
        now = time.time()
        expired = [k for k, ts in cls._timestamps.items() if now > ts]
        for key in expired:
            cls._remove(key)
        return len(expired)


# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

def validate_bypass_entry(entry: str) -> bool:
    """
    Validate bypass list entry (domain, IP, or comment).
    
    Optimized for minimal memory usage.
    
    Args:
        entry: Entry to validate (domain, IP, or comment)
    
    Returns:
        True if valid, False otherwise
    
    Example:
        >>> validate_bypass_entry("example.com")
        True
        >>> validate_bypass_entry("192.168.1.1")
        True
        >>> validate_bypass_entry("# comment")
        True
        >>> validate_bypass_entry("")
        False
    """
    entry = entry.strip()
    
    # Empty entries are invalid
    if not entry:
        return False
    
    # Comments are valid
    if entry.startswith('#'):
        return True
    
    # Check length (max 253 characters for domain)
    if len(entry) > 253:
        return False
    
    # IPv4 check
    parts = entry.split('.')
    if len(parts) == 4:
        try:
            return all(0 <= int(p) <= 255 for p in parts)
        except ValueError:
            pass  # Not an IP, continue to domain check
    
    # IPv6 check (simple check for colons)
    if ':' in entry:
        return True
    
    # Domain check (must have at least one dot)
    if '.' in entry:
        return True
    
    return False


def is_ip_address(entry: str) -> bool:
    """
    Check if entry is an IP address (IPv4 or IPv6).

    Args:
        entry: Entry to check

    Returns:
        True if IP address, False otherwise

    Example:
        >>> is_ip_address("192.168.1.1")
        True
        >>> is_ip_address("example.com")
        False
        >>> is_ip_address("::1")
        True
    """
    entry = entry.strip()

    # IPv4 check
    parts = entry.split('.')
    if len(parts) == 4:
        try:
            return all(0 <= int(p) <= 255 for p in parts)
        except ValueError:
            pass

    # IPv6 check (simple check for colons)
    if ':' in entry:
        return True

    return False


# =============================================================================
# FILE OPERATIONS
# =============================================================================

def load_bypass_list(filepath: str) -> List[str]:
    """
    Load bypass list from file with caching.
    
    - Caches for 1 minute or until file changes
    - Skips comments and empty lines
    - Memory-optimized for embedded devices
    
    Args:
        filepath: Path to bypass list file
    
    Returns:
        List of bypass entries (without comments/empty lines)
    
    Example:
        >>> load_bypass_list("/opt/etc/unblock/unblocktor.txt")
        ['example.com', 'test.com']
    """
    cache_key = f'bypass:{filepath}'
    
    # Check cache first
    if Cache.is_valid(cache_key):
        cached = Cache.get(cache_key)
        # Check if file has changed
        try:
            mtime = os.path.getmtime(filepath)
            if cached and mtime == cached.get('mtime'):
                return cached['data']
        except (OSError, IOError):
            pass
    
    # File doesn't exist
    if not os.path.exists(filepath):
        return []
    
    # Load from file
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            # Skip comments and empty lines, preserve order
            data = [
                line.strip() for line in f 
                if line.strip() and not line.strip().startswith('#')
            ]
        
        # Cache with mtime
        try:
            mtime = os.path.getmtime(filepath)
        except (OSError, IOError):
            mtime = time.time()
        
        Cache.set(cache_key, {'data': data, 'mtime': mtime}, ttl=60)
        
        return data
    
    except Exception as e:
        logger.error(f"Error loading bypass list {filepath}: {e}")
        return []


def save_bypass_list(filepath: str, sites: List[str]) -> None:
    """
    Save bypass list to file atomically.
    
    - Atomic write via .tmp file
    - Preserves order (no sorting)
    - Clears cache after save
    - Memory-optimized
    
    Args:
        filepath: Path to bypass list file
        sites: List of bypass entries to save
    
    Example:
        >>> save_bypass_list("/opt/etc/unblock/unblocktor.txt", 
        ...                  ["example.com", "test.com"])
    """
    temp_path = filepath + '.tmp'
    
    try:
        # Atomic write via temporary file
        with open(temp_path, 'w', encoding='utf-8') as f:
            # Preserve original order
            f.write('\n'.join(sites))
        
        # Atomic replace
        os.replace(temp_path, filepath)
        
        # Clear cache for this file
        cache_key = f'bypass:{filepath}'
        Cache._cache.pop(cache_key, None)
        Cache._timestamps.pop(cache_key, None)
        if cache_key in Cache._access_order:
            Cache._access_order.remove(cache_key)
    
    except Exception as e:
        logger.error(f"Error saving bypass list {filepath}: {e}")
        # Cleanup temp file on error
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except (OSError, IOError):
            pass
        raise


# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

def get_script_path(script_name: str) -> Optional[str]:
    """
    Get path to deployment script.
    
    Searches in multiple locations:
    1. /opt/etc/unblock/ (router production)
    2. deploy/router/ (development)
    3. Current directory
    
    Args:
        script_name: Name of script (e.g., 'unblock_update.sh')
    
    Returns:
        Full path to script or None if not found
    """
    # Router production paths
    possible_paths = [
        f"/opt/etc/unblock/{script_name}",
        f"/opt/etc/ndm/{script_name}",
    ]
    
    # Development paths (relative to project root)
    try:
        project_root = Path(__file__).parent.parent.parent
        dev_paths = [
            project_root / "deploy" / "router" / script_name,
            project_root / "scripts" / "deploy" / script_name,
        ]
        possible_paths.extend(str(p) for p in dev_paths)
    except Exception:
        pass
    
    # Current directory
    possible_paths.append(script_name)
    
    # Find first existing path
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    return None


def run_unblock_update() -> Tuple[bool, str]:
    """
    Run unblock_update.sh script to apply bypass list changes.
    
    Returns:
        Tuple of (success: bool, output: str)
    
    Example:
        >>> success, output = run_unblock_update()
        >>> if success:
        ...     print("Changes applied successfully")
    """
    script_path = get_script_path('unblock_update.sh')
    
    if not script_path:
        logger.error("unblock_update.sh script not found")
        return False, "Script not found"
    
    try:
        result = subprocess.run(
            ['sh', script_path],
            capture_output=True,
            text=True,
            timeout=60  # 60 second timeout
        )
        
        success = result.returncode == 0
        output = result.stdout.strip() or result.stderr.strip()
        
        if success:
            logger.info(f"unblock_update.sh completed successfully: {output}")
        else:
            logger.error(f"unblock_update.sh failed: {output}")
        
        return success, output
    
    except subprocess.TimeoutExpired:
        logger.error("unblock_update.sh timed out")
        return False, "Timeout"
    except Exception as e:
        logger.error(f"Error running unblock_update.sh: {e}")
        return False, str(e)


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def cleanup_memory() -> None:
    """
    Cleanup memory by clearing cache.
    
    Call periodically to prevent memory leaks on embedded devices.
    
    Example:
        >>> cleanup_memory()  # Call every 100 operations
    """
    Cache.clear()
    logger.debug("Memory cleanup completed")
