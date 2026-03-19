#!/bin/sh
# Script to fix bot3 references and update configuration on router

echo "=== Fixing bot3 references and updating configuration ==="

# 1. Fix web_config.py if it has wrong repository URL
WEB_CONFIG="/opt/etc/web_ui/core/web_config.py"
if [ -f "$WEB_CONFIG" ]; then
    echo "Checking $WEB_CONFIG..."
    if grep -q "bypass_keenetic-web" "$WEB_CONFIG"; then
        echo "Found wrong repository name, fixing..."
        sed -i 's|royfincher25-source/bypass_keenetic-web|royfincher25-source/bypass_keenetic_web|g' "$WEB_CONFIG"
        sed -i 's|base_url = "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic-web/main"|base_url = "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master"|g' "$WEB_CONFIG"
        echo "✓ Fixed repository name in web_config.py"
    else
        echo "✓ Repository name already correct in web_config.py"
    fi
    
    # Check branch
    if grep -q 'base_url.*main' "$WEB_CONFIG"; then
        echo "Found main branch, changing to master..."
        sed -i 's|/main"|/master"|g' "$WEB_CONFIG"
        echo "✓ Fixed branch in web_config.py"
    else
        echo "✓ Branch already correct in web_config.py"
    fi
fi

# 2. Fix routes.py if it's still using main branch
ROUTES_FILE="/opt/etc/web_ui/routes.py"
if [ -f "$ROUTES_FILE" ]; then
    echo "Checking $ROUTES_FILE..."
    if grep -q "github_branch = 'main'" "$ROUTES_FILE"; then
        echo "Found main branch in routes.py, changing to master..."
        sed -i "s|github_branch = 'main'|github_branch = 'master'|g" "$ROUTES_FILE"
        echo "✓ Fixed branch in routes.py"
    else
        echo "✓ Branch already correct in routes.py"
    fi
    
    if grep -q "bypass_keenetic-web" "$ROUTES_FILE"; then
        echo "Found wrong repository name in routes.py, fixing..."
        sed -i 's|royfincher25-source/bypass_keenetic-web|royfincher25-source/bypass_keenetic_web|g' "$ROUTES_FILE"
        echo "✓ Fixed repository name in routes.py"
    else
        echo "✓ Repository name already correct in routes.py"
    fi
fi

# 3. Remove any bot3 references
echo "Checking for bot3 references..."
for file in /opt/etc/web_ui/scripts/* /opt/etc/web_ui/resources/scripts/*; do
    if [ -f "$file" ]; then
        if grep -q "bot3" "$file"; then
            echo "Found bot3 reference in $file, removing..."
            sed -i '/bot3/d' "$file"
            echo "✓ Removed bot3 reference from $(basename $file)"
        fi
    fi
done

# 4. Restart web UI
echo "Restarting web UI..."
/opt/etc/init.d/S99web_ui restart

echo "=== Fix completed ==="
echo "Please try the 'Обновить' button in the web interface again."