"""
Tests for DNS Resolver - Parallel domain resolution

Tests verify:
- Single domain resolution
- Parallel resolution performance
- Handling of invalid domains
"""
import pytest
import sys
import os

# Add src/web_ui to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'web_ui'))

from core.dns_resolver import parallel_resolve, resolve_single


def test_resolve_single_domain():
    """Test resolving a single domain"""
    ips = resolve_single('google.com')
    assert len(ips) > 0
    assert all(_is_ip(ip) for ip in ips)


def test_parallel_resolve_multiple():
    """Test parallel resolution of multiple domains"""
    import time

    domains = ['google.com', 'facebook.com', 'twitter.com', 'youtube.com']

    start = time.time()
    results = parallel_resolve(domains, max_workers=4)
    elapsed = time.time() - start

    assert len(results) == 4
    assert 'google.com' in results
    assert elapsed < 5.0  # Should be fast with parallel


def test_parallel_resolve_with_invalid():
    """Test handling of invalid domains"""
    domains = ['google.com', 'invalid.domain.that.does.not.exist', 'facebook.com']
    results = parallel_resolve(domains, max_workers=4)

    assert 'google.com' in results
    assert 'facebook.com' in results
    # Invalid domain should have empty list or be skipped


def test_resolve_single_invalid():
    """Test resolving invalid domain"""
    ips = resolve_single('invalid.domain.that.does.not.exist')
    assert len(ips) == 0


def test_parallel_resolve_empty_list():
    """Test parallel resolve with empty list"""
    results = parallel_resolve([])
    assert results == {}


def test_parallel_resolve_single_worker():
    """Test parallel resolve with single worker"""
    domains = ['google.com', 'facebook.com']
    results = parallel_resolve(domains, max_workers=1)
    
    assert len(results) == 2
    assert 'google.com' in results
    assert 'facebook.com' in results


def _is_ip(ip: str) -> bool:
    """Helper to check if string is IP address"""
    import re
    ipv4_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    return bool(re.match(ipv4_pattern, ip)) or ':' in ip
