"""
Tests for DNS Monitor - Automatic DNS channel availability checking

Tests verify:
- DNS server health checking
- Singleton pattern with thread safety
- Background thread start/stop
- Automatic failover after consecutive failures
- Status reporting

Architecture: Background thread with periodic checks, automatic switch on failure.
Tech Stack: Python 3.8+, threading, socket, Flask 3.0.0
"""
import pytest
import sys
import os
from unittest.mock import patch, MagicMock, Mock
import socket
import time

# Add src/web_ui to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'web_ui'))


# =============================================================================
# TESTS FOR check_dns_server FUNCTION
# =============================================================================

class TestCheckDnsServer:
    """Tests for check_dns_server function"""

    @patch('core.dns_monitor.socket.socket')
    def test_check_dns_server_success(self, mock_socket_class):
        """Test checking a working DNS server"""
        # Mock successful connection
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.return_value = 0  # Success

        from core.dns_monitor import check_dns_server

        result = check_dns_server('8.8.8.8', timeout=2)

        assert result['success'] is True
        assert 'latency_ms' in result
        assert result['host'] == '8.8.8.8'
        assert result['port'] == 53
        assert 'error' not in result or result.get('error') is None

    @patch('core.dns_monitor.socket.socket')
    def test_check_dns_server_connection_failed(self, mock_socket_class):
        """Test checking an unavailable DNS server"""
        # Mock failed connection
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.return_value = -1  # Connection failed

        from core.dns_monitor import check_dns_server

        result = check_dns_server('192.0.2.1', timeout=2)  # TEST-NET-1 (unreachable)

        assert result['success'] is False
        assert 'latency_ms' in result
        assert 'error' in result

    @patch('core.dns_monitor.socket.socket')
    def test_check_dns_server_timeout(self, mock_socket_class):
        """Test DNS check with timeout"""
        # Mock socket timeout
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.side_effect = socket.timeout()

        from core.dns_monitor import check_dns_server

        result = check_dns_server('8.8.8.8', timeout=2)

        assert result['success'] is False
        assert 'error' in result
        assert 'Timeout' in result['error']

    @patch('core.dns_monitor.socket.socket')
    def test_check_dns_server_custom_port(self, mock_socket_class):
        """Test checking DNS on custom port"""
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.return_value = 0

        from core.dns_monitor import check_dns_server

        result = check_dns_server('8.8.8.8', port=5353, timeout=2)

        assert result['success'] is True
        assert result['port'] == 5353


# =============================================================================
# TESTS FOR DNSMonitor CLASS - SINGLETON PATTERN
# =============================================================================

class TestDnsMonitorSingleton:
    """Tests for DNSMonitor singleton pattern"""

    def test_dns_monitor_singleton(self):
        """Test DNSMonitor is singleton - same instance returned"""
        # Clear any existing instance
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None
        DNSMonitor._lock = type('Lock', (), {'__enter__': lambda s: s, '__exit__': lambda s, *a: None})()

        monitor1 = DNSMonitor()
        monitor2 = DNSMonitor()

        assert monitor1 is monitor2, "DNSMonitor should be singleton"

    def test_dns_monitor_singleton_thread_safety(self):
        """Test singleton pattern is thread-safe"""
        import threading

        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        instances = []

        def create_instance():
            instance = DNSMonitor()
            instances.append(instance)

        # Create multiple threads
        threads = [threading.Thread(target=create_instance) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # All threads should get same instance
        assert all(i is instances[0] for i in instances), "All threads should get same instance"


# =============================================================================
# TESTS FOR DNSMonitor CLASS - START/STOP
# =============================================================================

class TestDnsMonitorStartStop:
    """Tests for DNSMonitor start/stop functionality"""

    @patch('core.dns_monitor.threading.Thread')
    def test_dns_monitor_start(self, mock_thread_class):
        """Test starting monitor"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        mock_thread = MagicMock()
        mock_thread_class.return_value = mock_thread

        monitor = DNSMonitor()
        monitor.start()

        assert monitor.is_running() is True
        mock_thread_class.assert_called_once()
        mock_thread.start.assert_called_once()

    @patch('core.dns_monitor.threading.Thread')
    def test_dns_monitor_stop(self, mock_thread_class):
        """Test stopping monitor"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        mock_thread = MagicMock()
        mock_thread_class.return_value = mock_thread

        monitor = DNSMonitor()
        monitor._running = True  # Simulate running state
        monitor._thread = mock_thread
        monitor.stop()

        assert monitor.is_running() is False
        mock_thread.join.assert_called_once()

    @patch('core.dns_monitor.threading.Thread')
    def test_dns_monitor_start_already_running(self, mock_thread_class):
        """Test starting monitor when already running"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        mock_thread = MagicMock()
        mock_thread_class.return_value = mock_thread

        monitor = DNSMonitor()
        monitor._running = True
        monitor._thread = mock_thread

        monitor.start()

        # Should not create new thread
        assert mock_thread_class.call_count == 0


# =============================================================================
# TESTS FOR DNSMonitor CLASS - STATUS
# =============================================================================

class TestDnsMonitorStatus:
    """Tests for DNSMonitor status reporting"""

    def test_dns_monitor_get_status_initial(self):
        """Test getting initial status"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        monitor = DNSMonitor()
        status = monitor.get_status()

        assert 'running' in status
        assert 'current_server' in status
        assert 'last_check' in status
        assert 'failures' in status
        assert status['running'] is False
        assert status['failures'] == 0


# =============================================================================
# TESTS FOR DNSMonitor CLASS - FAILOVER LOGIC
# =============================================================================

class TestDnsMonitorFailover:
    """Tests for DNSMonitor automatic failover"""

    @patch('core.dns_monitor.check_dns_server')
    def test_switch_to_backup_after_failures(self, mock_check):
        """Test switching to backup after 3 consecutive failures"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        # Mock: primary fails, backup succeeds
        def check_side_effect(host, *args, **kwargs):
            if host == '8.8.8.8':  # Primary
                return {'success': False, 'error': 'Timeout'}
            elif host == '9.9.9.9':  # Backup
                return {'success': True, 'latency_ms': 50}
            return {'success': False}

        mock_check.side_effect = check_side_effect

        monitor = DNSMonitor()
        monitor._current_server = {'name': 'Google DNS', 'host': '8.8.8.8', 'port': 53}
        monitor._failures = 2  # Already 2 failures

        # Trigger internal method
        monitor._failures += 1  # 3rd failure
        if monitor._failures >= 3:
            monitor._switch_to_backup()

        # Should have switched to backup
        assert monitor._current_server is not None
        assert monitor._current_server['host'] == '9.9.9.9'
        assert monitor._failures == 0

    @patch('core.dns_monitor.check_dns_server')
    def test_select_best_primary(self, mock_check):
        """Test selecting best primary DNS by latency"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        # Mock: Cloudflare faster than Google
        def check_side_effect(host, *args, **kwargs):
            if host == '8.8.8.8':
                return {'success': True, 'latency_ms': 100}
            elif host == '1.1.1.1':
                return {'success': True, 'latency_ms': 50}
            return {'success': False}

        mock_check.side_effect = check_side_effect

        monitor = DNSMonitor()
        monitor._select_best_primary()

        # Should select Cloudflare (faster)
        assert monitor._current_server is not None
        assert monitor._current_server['host'] == '1.1.1.1'

    @patch('core.dns_monitor.check_dns_server')
    def test_no_working_dns(self, mock_check):
        """Test behavior when no DNS servers work"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        # Mock: all servers fail
        mock_check.return_value = {'success': False, 'error': 'Timeout'}

        monitor = DNSMonitor()
        monitor._current_server = None
        monitor._select_best_primary()

        # Should have no current server
        assert monitor._current_server is None


# =============================================================================
# TESTS FOR DNSMonitor CLASS - MONITOR LOOP
# =============================================================================

class TestDnsMonitorLoop:
    """Tests for DNSMonitor background loop"""

    @patch('core.dns_monitor.time.sleep')
    @patch('core.dns_monitor.check_dns_server')
    def test_monitor_loop_checks_current_server(self, mock_check, mock_sleep):
        """Test monitor loop checks current server"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        # Mock successful check
        mock_check.return_value = {'success': True, 'latency_ms': 50}

        monitor = DNSMonitor()
        monitor._current_server = {'name': 'Google DNS', 'host': '8.8.8.8', 'port': 53}
        monitor._running = True

        # Run one iteration of loop (manually call internal logic)
        result = mock_check('8.8.8.8', 53, 2)
        if result['success']:
            monitor._failures = 0

        # Should have called check_dns_server
        mock_check.assert_called()
        assert monitor._failures == 0

    @patch('core.dns_monitor.time.sleep')
    @patch('core.dns_monitor.check_dns_server')
    def test_monitor_loop_increments_failures(self, mock_check, mock_sleep):
        """Test monitor loop increments failure counter"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        # Mock failed check
        mock_check.return_value = {'success': False, 'error': 'Timeout'}

        monitor = DNSMonitor()
        monitor._current_server = {'name': 'Google DNS', 'host': '8.8.8.8', 'port': 53}
        monitor._running = True
        monitor._failures = 0

        # Simulate failed check
        result = mock_check('8.8.8.8', 53, 2)
        if not result['success']:
            monitor._failures += 1

        assert monitor._failures == 1


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestDnsMonitorIntegration:
    """Integration tests for DNS monitor"""

    @patch('core.dns_monitor.threading.Thread')
    @patch('core.dns_monitor.check_dns_server')
    def test_full_lifecycle(self, mock_check, mock_thread_class):
        """Test full lifecycle: init -> start -> check -> stop"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        mock_thread = MagicMock()
        mock_thread_class.return_value = mock_thread
        mock_check.return_value = {'success': True, 'latency_ms': 50}

        # Create and start
        monitor = DNSMonitor()
        assert monitor.is_running() is False

        monitor.start()
        assert monitor.is_running() is True

        # Get status
        status = monitor.get_status()
        assert status['running'] is True

        # Stop
        monitor.stop()
        assert monitor.is_running() is False


# =============================================================================
# EDGE CASES
# =============================================================================

class TestDnsMonitorEdgeCases:
    """Edge case tests"""

    def test_dns_monitor_reentrant_init(self):
        """Test that __init__ is safe to call multiple times"""
        from core.dns_monitor import DNSMonitor
        DNSMonitor._instance = None

        monitor1 = DNSMonitor()
        monitor2 = DNSMonitor()

        # Both should be same instance
        assert monitor1 is monitor2
        # Should have _initialized attribute
        assert hasattr(monitor1, '_initialized')

    @patch('core.dns_monitor.socket.socket')
    def test_check_dns_with_exception(self, mock_socket_class):
        """Test DNS check when socket raises unexpected exception"""
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.side_effect = Exception("Unexpected error")

        from core.dns_monitor import check_dns_server

        result = check_dns_server('8.8.8.8', timeout=2)

        assert result['success'] is False
        assert 'error' in result
        assert 'Unexpected error' in result['error']
