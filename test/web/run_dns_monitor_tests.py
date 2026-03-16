"""
Simple test runner for DNS monitor tests without pytest.
Runs basic validation tests.
"""
import sys
import os

# Add src/web_ui to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'web_ui'))

print("=" * 60)
print("DNS Monitor - Basic Tests (without pytest)")
print("=" * 60)

# Test 1: Import test
print("\n[Test 1] Importing dns_monitor module...")
try:
    from core.dns_monitor import DNSMonitor, check_dns_server, get_dns_monitor
    print("✅ PASS: Import successful")
except Exception as e:
    print(f"❌ FAIL: Import failed - {e}")
    sys.exit(1)

# Test 2: Singleton test
print("\n[Test 2] Testing singleton pattern...")
try:
    DNSMonitor._instance = None  # Reset instance
    monitor1 = DNSMonitor()
    monitor2 = DNSMonitor()
    assert monitor1 is monitor2, "Should be same instance"
    print("✅ PASS: Singleton pattern works")
except Exception as e:
    print(f"❌ FAIL: Singleton test failed - {e}")

# Test 3: Initial state test
print("\n[Test 3] Testing initial state...")
try:
    DNSMonitor._instance = None  # Reset instance
    monitor = DNSMonitor()
    assert monitor.is_running() is False, "Should not be running initially"
    status = monitor.get_status()
    assert status['running'] is False
    assert status['failures'] == 0
    print("✅ PASS: Initial state correct")
except Exception as e:
    print(f"❌ FAIL: Initial state test failed - {e}")

# Test 4: Start/Stop test (mocked thread)
print("\n[Test 4] Testing start/stop...")
try:
    DNSMonitor._instance = None  # Reset instance
    monitor = DNSMonitor()
    
    # Start
    monitor.start()
    assert monitor.is_running() is True, "Should be running after start"
    
    # Stop
    monitor.stop()
    assert monitor.is_running() is False, "Should not be running after stop"
    
    print("✅ PASS: Start/Stop works")
except Exception as e:
    print(f"❌ FAIL: Start/Stop test failed - {e}")

# Test 5: check_dns_server function test (with mock)
print("\n[Test 5] Testing check_dns_server with mock...")
try:
    from unittest.mock import patch, MagicMock
    import socket
    
    with patch('core.dns_monitor.socket.socket') as mock_socket_class:
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.return_value = 0  # Success
        
        result = check_dns_server('8.8.8.8', timeout=2)
        
        assert result['success'] is True
        assert 'latency_ms' in result
        assert result['host'] == '8.8.8.8'
        
    print("✅ PASS: check_dns_server works with mock")
except Exception as e:
    print(f"❌ FAIL: check_dns_server test failed - {e}")

# Test 6: check_dns_server failure test
print("\n[Test 6] Testing check_dns_server failure...")
try:
    from unittest.mock import patch, MagicMock
    
    with patch('core.dns_monitor.socket.socket') as mock_socket_class:
        mock_socket = MagicMock()
        mock_socket_class.return_value = mock_socket
        mock_socket.connect_ex.return_value = -1  # Failure
        
        result = check_dns_server('192.0.2.1', timeout=2)
        
        assert result['success'] is False
        assert 'error' in result
        
    print("✅ PASS: check_dns_server failure handled")
except Exception as e:
    print(f"❌ FAIL: check_dns_server failure test failed - {e}")

# Test 7: Failover logic test
print("\n[Test 7] Testing failover logic...")
try:
    from unittest.mock import patch
    
    DNSMonitor._instance = None
    
    def check_side_effect(host, *args, **kwargs):
        if host == '8.8.8.8':  # Primary
            return {'success': False, 'error': 'Timeout'}
        elif host == '9.9.9.9':  # Backup
            return {'success': True, 'latency_ms': 50}
        return {'success': False}
    
    with patch('core.dns_monitor.check_dns_server', side_effect=check_side_effect):
        monitor = DNSMonitor()
        monitor._current_server = {'name': 'Google DNS', 'host': '8.8.8.8', 'port': 53}
        monitor._failures = 2  # Already 2 failures
        
        # Simulate 3rd failure
        monitor._failures += 1
        if monitor._failures >= 3:
            monitor._switch_to_backup()
        
        # Should have switched to backup
        assert monitor._current_server is not None
        assert monitor._current_server['host'] == '9.9.9.9'
        assert monitor._failures == 0
        
    print("✅ PASS: Failover logic works")
except Exception as e:
    print(f"❌ FAIL: Failover test failed - {e}")

# Test 8: Select best primary test
print("\n[Test 8] Testing select best primary...")
try:
    from unittest.mock import patch
    
    DNSMonitor._instance = None
    
    def check_side_effect(host, *args, **kwargs):
        if host == '8.8.8.8':
            return {'success': True, 'latency_ms': 100}
        elif host == '1.1.1.1':
            return {'success': True, 'latency_ms': 50}
        return {'success': False}
    
    with patch('core.dns_monitor.check_dns_server', side_effect=check_side_effect):
        monitor = DNSMonitor()
        monitor._select_best_primary()
        
        # Should select Cloudflare (faster)
        assert monitor._current_server is not None
        assert monitor._current_server['host'] == '1.1.1.1'
        
    print("✅ PASS: Select best primary works")
except Exception as e:
    print(f"❌ FAIL: Select best primary test failed - {e}")

# Test 9: get_dns_monitor helper
print("\n[Test 9] Testing get_dns_monitor helper...")
try:
    DNSMonitor._instance = None
    monitor = get_dns_monitor()
    assert monitor is not None
    assert isinstance(monitor, DNSMonitor)
    print("✅ PASS: get_dns_monitor works")
except Exception as e:
    print(f"❌ FAIL: get_dns_monitor test failed - {e}")

print("\n" + "=" * 60)
print("All basic tests completed!")
print("=" * 60)
