import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src', 'web_ui'))

def test_add_to_bypass_exists():
    """Test that add_to_bypass function exists"""
    from routes import add_to_bypass
    assert add_to_bypass is not None
    print("✓ add_to_bypass function exists")

def test_optimized_scripts_exist():
    """Test that optimized scripts exist and are valid"""
    import os
    
    scripts = [
        'src/web_ui/resources/scripts/unblock_ipset.sh',
        'src/web_ui/resources/scripts/unblock_dnsmasq.sh',
        'src/web_ui/resources/scripts/unblock_update.sh'
    ]
    
    for script in scripts:
        assert os.path.exists(script), f"Script {script} not found"
        
        # Check script is executable (only on Unix systems, skip on Windows)
        if os.name != 'nt':
            assert os.access(script, os.X_OK), f"Script {script} is not executable"
    
    print("✓ All optimized scripts exist")

def test_routes_optimization():
    """Test that routes.py has been optimized"""
    routes_file = 'src/web_ui/routes.py'
    
    with open(routes_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check for optimized logic
    assert 'ip_entries' in content, "IP entries handling not found"
    assert 'domain_entries' in content, "Domain entries handling not found"
    assert 'bulk_add_to_ipset' in content, "Bulk add to ipset not found"
    
    print("✓ routes.py has been optimized")
