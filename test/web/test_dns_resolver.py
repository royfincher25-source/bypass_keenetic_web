"""
Tests for DNS Resolver - Parallel domain resolution

Tests verify:
- Single domain resolution
- Parallel resolution performance
- Handling of invalid domains
- Input validation (None, empty strings, duplicates)
- Batch processing for memory efficiency
"""
import pytest
import sys
import os
from unittest.mock import patch, MagicMock
import socket

# Add src/web_ui to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'web_ui'))

from core.dns_resolver import parallel_resolve, resolve_single


@patch('core.dns_resolver.socket.getaddrinfo')
def test_resolve_single_domain(mock_getaddrinfo):
    """Test resolving a single domain with mocked DNS"""
    # Mock DNS response
    mock_getaddrinfo.return_value = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('142.250.185.46', 0)),
        (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('142.250.185.47', 0)),
    ]
    
    ips = resolve_single('google.com')
    
    assert len(ips) == 2
    assert '142.250.185.46' in ips
    assert '142.250.185.47' in ips


@patch('core.dns_resolver.socket.getaddrinfo')
def test_parallel_resolve_multiple(mock_getaddrinfo):
    """Test parallel resolution of multiple domains with mocked DNS"""
    import time

    # Mock DNS responses for different domains
    def mock_getaddrinfo_side_effect(domain, *args, **kwargs):
        return [
            (socket.AF_INET, socket.SOCK_STREAM, 6, '', (f'192.168.1.{hash(domain) % 256}', 0)),
        ]
    
    mock_getaddrinfo.side_effect = mock_getaddrinfo_side_effect

    domains = ['google.com', 'facebook.com', 'twitter.com', 'youtube.com']

    start = time.time()
    results = parallel_resolve(domains, max_workers=4)
    elapsed = time.time() - start

    assert len(results) == 4
    assert 'google.com' in results
    assert elapsed < 5.0  # Should be fast with parallel


@patch('core.dns_resolver.socket.getaddrinfo')
def test_parallel_resolve_with_invalid(mock_getaddrinfo):
    """Test handling of invalid domains with mocked DNS"""
    # Mock DNS - raise error for invalid domain
    def mock_getaddrinfo_side_effect(domain, *args, **kwargs):
        if 'invalid' in domain:
            raise socket.gaierror("Name or service not known")
        return [
            (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('192.168.1.1', 0)),
        ]
    
    mock_getaddrinfo.side_effect = mock_getaddrinfo_side_effect
    
    domains = ['google.com', 'invalid.domain.that.does.not.exist', 'facebook.com']
    results = parallel_resolve(domains, max_workers=4)

    assert 'google.com' in results
    assert 'facebook.com' in results
    # Invalid domain should have empty list or be skipped


@patch('core.dns_resolver.socket.getaddrinfo')
def test_resolve_single_invalid(mock_getaddrinfo):
    """Test resolving invalid domain with mocked DNS"""
    mock_getaddrinfo.side_effect = socket.gaierror("Name or service not known")
    
    ips = resolve_single('invalid.domain.that.does.not.exist')
    assert len(ips) == 0


def test_parallel_resolve_empty_list():
    """Test parallel resolve with empty list"""
    results = parallel_resolve([])
    assert results == {}


@patch('core.dns_resolver.socket.getaddrinfo')
def test_parallel_resolve_single_worker(mock_getaddrinfo):
    """Test parallel resolve with single worker"""
    mock_getaddrinfo.return_value = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('192.168.1.1', 0)),
    ]
    
    domains = ['google.com', 'facebook.com']
    results = parallel_resolve(domains, max_workers=1)

    assert len(results) == 2
    assert 'google.com' in results
    assert 'facebook.com' in results


@patch('core.dns_resolver.socket.getaddrinfo')
def test_parallel_resolve_with_invalid_inputs(mock_getaddrinfo):
    """Test filtering of None, empty strings, and duplicates"""
    mock_getaddrinfo.return_value = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('192.168.1.1', 0)),
    ]
    
    # Test with None, empty strings, duplicates
    domains = ['google.com', None, '', 'google.com', 'facebook.com', '', None]
    results = parallel_resolve(domains, max_workers=2)
    
    # Should only resolve valid unique domains
    assert 'google.com' in results
    assert 'facebook.com' in results
    assert len(results) == 2  # No duplicates


@patch('core.dns_resolver.socket.getaddrinfo')
def test_parallel_resolve_with_whitespace(mock_getaddrinfo):
    """Test filtering of whitespace-only strings"""
    mock_getaddrinfo.return_value = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('192.168.1.1', 0)),
    ]
    
    domains = ['google.com', '   ', '\t', '\n', 'facebook.com']
    results = parallel_resolve(domains, max_workers=2)
    
    # Should only resolve valid domains
    assert 'google.com' in results
    assert 'facebook.com' in results
    assert len(results) == 2


@patch('core.dns_resolver.load_bypass_list')
@patch('core.dns_resolver.parallel_resolve')
@patch('core.dns_resolver.bulk_add_to_ipset')
@patch('core.dns_resolver.ensure_ipset_exists')
def test_resolve_domains_batch_processing(mock_ensure, mock_bulk, mock_resolve, mock_load):
    """Test that large domain lists are processed in batches"""
    # Mock 1000 domains
    mock_load.return_value = [f'domain{i}.com' for i in range(1000)]
    
    # Mock resolution - return 1 IP per domain
    mock_resolve.return_value = {
        f'domain{i}.com': [f'192.168.1.{i % 256}']
        for i in range(500)  # First batch
    }
    
    mock_bulk.return_value = (True, 'Success')
    
    from core.dns_resolver import resolve_domains_for_ipset
    
    # Should process in batches, not collect all IPs
    result = resolve_domains_for_ipset('/tmp/test.txt')
    
    # Should have processed at least first batch
    assert mock_resolve.called
    # Verify batch processing was used (called multiple times for large list)
    assert mock_resolve.call_count >= 2  # At least 2 batches for 1000 domains


@patch('core.dns_resolver.load_bypass_list')
@patch('core.dns_resolver.parallel_resolve')
@patch('core.dns_resolver.bulk_add_to_ipset')
@patch('core.dns_resolver.ensure_ipset_exists')
def test_resolve_domains_batch_small_list(mock_ensure, mock_bulk, mock_resolve, mock_load):
    """Test batch processing with small list (single batch)"""
    # Mock 100 domains (less than BATCH_SIZE=500)
    mock_load.return_value = [f'domain{i}.com' for i in range(100)]
    
    # Mock resolution
    mock_resolve.return_value = {
        f'domain{i}.com': [f'192.168.1.{i % 256}']
        for i in range(100)
    }
    
    mock_bulk.return_value = (True, 'Success')
    
    from core.dns_resolver import resolve_domains_for_ipset
    
    result = resolve_domains_for_ipset('/tmp/test.txt')
    
    # Should call resolve once for single batch
    assert mock_resolve.call_count == 1


def _is_ip(ip: str) -> bool:
    """Helper to check if string is IP address"""
    import re
    ipv4_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    return bool(re.match(ipv4_pattern, ip)) or ':' in ip
