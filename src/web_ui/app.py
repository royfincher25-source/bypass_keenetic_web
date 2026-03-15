"""
Bypass Keenetic Web Interface - Main Application

Flask application for Keenetic router bypass management.
"""
import os
import sys
import secrets
from functools import wraps
from flask import Flask, session, request, abort
from datetime import timedelta

from core.config import WebConfig


def csrf_token(f):
    """Decorator to require CSRF token on POST requests."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if request.method == 'POST':
            token = session.get('csrf_token')
            form_token = request.form.get('csrf_token')
            if not token or not form_token or token != form_token:
                abort(403)
        return f(*args, **kwargs)
    return decorated_function


# Make CSRF decorator available for routes
app = None

def create_app(config_class=None):
    """
    Create and configure the Flask application.
    
    Args:
        config_class: Optional configuration class to use.
                     If None, uses WebConfig from core.config.
    
    Returns:
        Configured Flask application instance
    """
    global app
    app = Flask(__name__)
    
    # Генерация случайного SECRET_KEY если не задан в окружении
    secret_key = os.environ.get('SECRET_KEY')
    if not secret_key:
        secret_key = secrets.token_hex(32)
    app.config['SECRET_KEY'] = secret_key
    
    # Загрузка конфигурации из WebConfig
    if config_class is None:
        config = WebConfig()
    else:
        config = config_class()
    
    # Применение конфигурации из WebConfig
    app.config['WEB_HOST'] = config.web_host
    app.config['WEB_PORT'] = config.web_port
    app.config['WEB_PASSWORD'] = config.web_password
    app.config['ROUTER_IP'] = config.router_ip
    
    # Конфигурация сессий
    app.config['SESSION_COOKIE_NAME'] = 'bypass_session'
    app.config['SESSION_COOKIE_HTTPONLY'] = True
    app.config['SESSION_COOKIE_SECURE'] = False  # False для HTTP, True для HTTPS
    app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=24)

    # Регистрация маршрутов
    from routes import bp, register_routes
    app.register_blueprint(bp)
    register_routes(app)

    return app


if __name__ == '__main__':
    app = create_app()
    app.run(
        host=app.config['WEB_HOST'],
        port=app.config['WEB_PORT'],
        debug=False
    )
