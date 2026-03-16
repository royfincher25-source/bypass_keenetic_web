"""
Bypass Keenetic Web Interface - Routes

Routes for the web interface with session-based authentication.
"""
from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app
from functools import wraps
from werkzeug.utils import secure_filename
from markupsafe import escape
from concurrent.futures import ThreadPoolExecutor, TimeoutError
import os
import sys
import logging
import json
import subprocess
import requests

logger = logging.getLogger(__name__)

# Thread pool for blocking operations (embedded-optimized: 2 workers max)
executor = ThreadPoolExecutor(max_workers=2)

# Validation constants for embedded devices (128MB RAM)
MAX_ENTRIES_PER_REQUEST = 100  # Максимум записей за один запрос
MAX_ENTRY_LENGTH = 253  # Максимальная длина одной записи (DNS limit)
MAX_TOTAL_INPUT_SIZE = 50 * 1024  # 50KB лимит на общий размер ввода

# Импорты utility-функций
from core.utils import (
    load_bypass_list,
    save_bypass_list,
    validate_bypass_entry,
    run_unblock_update,
    is_ip_address
)
from core.ipset_manager import bulk_add_to_ipset, ensure_ipset_exists, bulk_remove_from_ipset
from core.services import (
    parse_vless_key, vless_config, write_json_config,
    parse_shadowsocks_key, shadowsocks_config,
    parse_trojan_key, trojan_config,
    parse_tor_bridges, tor_config, write_tor_config,
    restart_service, check_service_status
)
from core.app_config import WebConfig

bp = Blueprint('main', __name__, template_folder='templates', static_folder='static')


# =============================================================================
# DECORATORS
# =============================================================================

def login_required(f):
    """
    Decorator to require authentication for a route.
    
    Redirects to /login if user is not authenticated.
    """
    from functools import wraps
    
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('authenticated'):
            return redirect(url_for('main.login'))
        return f(*args, **kwargs)
    
    return decorated_function


def get_csrf_token():
    """Generate or get CSRF token for the session."""
    import secrets
    if 'csrf_token' not in session:
        session['csrf_token'] = secrets.token_hex(32)
    return session['csrf_token']


def csrf_required(f):
    """Decorator to require CSRF token on POST requests."""
    from functools import wraps
    
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if request.method == 'POST':
            token = session.get('csrf_token')
            form_token = request.form.get('csrf_token')
            if not token or not form_token or token != form_token:
                flash('Ошибка безопасности: неверный токен', 'danger')
                logger.warning("CSRF token validation failed")
                return redirect(url_for('main.index'))
        return f(*args, **kwargs)
    
    return decorated_function


# =============================================================================
# ROUTES
# =============================================================================

@bp.route('/')
@login_required
def index():
    """
    Render the main dashboard page.

    Requires authentication. Redirects to /login if not authenticated.
    """
    return render_template('index.html')


@bp.route('/login', methods=['GET', 'POST'])
def login():
    """
    Handle user login.

    GET: Display login form.
    POST: Authenticate user with password.

    On success: Set session['authenticated'] = True, redirect to /
    On failure: Display flash message, redirect to /login
    """
    # Если уже авторизован - редирект на главную
    if session.get('authenticated'):
        return redirect(url_for('main.index'))

    if request.method == 'GET':
        get_csrf_token()

    if request.method == 'POST':
        # CSRF check for login
        token = session.get('csrf_token')
        form_token = request.form.get('csrf_token')
        if not token or not form_token or token != form_token:
            flash('Ошибка безопасности: неверный токен', 'danger')
            logger.warning("CSRF token validation failed on login")
            return redirect(url_for('main.login'))
        
        password = request.form.get('password', '')
        web_password = current_app.config.get('WEB_PASSWORD', 'changeme')

        # Безопасное сравнение паролей (защита от timing attacks)
        import secrets
        if password and web_password and secrets.compare_digest(password, web_password):
            # Успешная авторизация
            session.permanent = True
            session['authenticated'] = True
            logger.info("User logged in successfully")
            return redirect(url_for('main.index'))
        else:
            # Неверный пароль
            logger.warning("Failed login attempt")
            flash('Неверный пароль', 'danger')
            return redirect(url_for('main.login'))

    # GET запрос - показываем форму
    return render_template('login.html')


@bp.route('/logout')
def logout():
    """
    Handle user logout.
    
    Clears session['authenticated'] and redirects to /login.
    """
    session.pop('authenticated', None)
    flash('Вы вышли из системы', 'info')
    return redirect(url_for('main.login'))


@bp.route('/status')
@login_required
def status():
    """
    Render the status page.

    Requires authentication.
    """
    return render_template('base.html', title='Status')


@bp.route('/keys')
@login_required
def keys():
    """
    Render the keys and bridges page.

    Requires authentication.
    """
    # Проверка статусов сервисов
    config = WebConfig()
    
    services = {
        'vless': {
            'name': 'VLESS',
            'config': '/opt/etc/xray/vless.json',
            'init': '/opt/etc/init.d/S24xray',
            'status': '❓',
        },
        'shadowsocks': {
            'name': 'Shadowsocks',
            'config': '/opt/etc/shadowsocks.json',
            'init': '/opt/etc/init.d/S22shadowsocks',
            'status': '❓',
        },
        'trojan': {
            'name': 'Trojan',
            'config': '/opt/etc/trojan.json',
            'init': '/opt/etc/init.d/S22trojan',
            'status': '❓',
        },
        'tor': {
            'name': 'Tor',
            'config': '/opt/etc/tor/torrc',
            'init': '/opt/etc/init.d/S35tor',
            'status': '❓',
        },
    }
    
    # Проверка статусов
    for service in services.values():
        service['status'] = check_service_status(service['init'])
        service['config_exists'] = os.path.exists(service['config'])
    
    return render_template('keys.html', services=services)


@bp.route('/keys/<service>', methods=['GET', 'POST'])
@login_required
@csrf_required
def key_config(service: str):
    """
    Handle key configuration for a service.
    
    Args:
        service: Service name (vless, shadowsocks, trojan, tor)
    
    Returns:
        Rendered key configuration page
    """
    config = WebConfig()
    
    services_config = {
        'vless': {
            'name': 'VLESS',
            'config_path': '/opt/etc/xray/vless.json',
            'init_script': '/opt/etc/init.d/S24xray',
        },
        'shadowsocks': {
            'name': 'Shadowsocks',
            'config_path': '/opt/etc/shadowsocks.json',
            'init_script': '/opt/etc/init.d/S22shadowsocks',
        },
        'trojan': {
            'name': 'Trojan',
            'config_path': '/opt/etc/trojan.json',
            'init_script': '/opt/etc/init.d/S22trojan',
        },
        'tor': {
            'name': 'Tor',
            'config_path': '/opt/etc/tor/torrc',
            'init_script': '/opt/etc/init.d/S35tor',
        },
    }
    
    if service not in services_config:
        flash('Неверный сервис', 'danger')
        return redirect(url_for('main.keys'))
    
    svc = services_config[service]
    
    if request.method == 'POST':
        key = request.form.get('key', '').strip()
        
        if not key:
            flash('Введите ключ', 'warning')
            return redirect(url_for('main.key_config', service=service))
        
        try:
            # Парсинг ключа и генерация конфига
            if service == 'vless':
                parsed = parse_vless_key(key)
                cfg = vless_config(key)
                write_json_config(cfg, svc['config_path'])
            elif service == 'shadowsocks':
                parsed = parse_shadowsocks_key(key)
                cfg = shadowsocks_config(key)
                write_json_config(cfg, svc['config_path'])
            elif service == 'trojan':
                parsed = parse_trojan_key(key)
                cfg = trojan_config(key)
                write_json_config(cfg, svc['config_path'])
            elif service == 'tor':
                cfg = tor_config(key)
                write_tor_config(cfg, svc['config_path'])

            # Перезапуск сервиса через ThreadPoolExecutor (неблокирующий)
            try:
                future = executor.submit(restart_service, svc['name'], svc['init_script'])
                success, output = future.result(timeout=30)  # Max 30s wait

                if success:
                    flash(f'✅ {svc["name"]} успешно настроен и перезапущен', 'success')
                else:
                    flash(f'⚠️ Конфигурация сохранена, но ошибка перезапуска: {output}', 'warning')
            except TimeoutError:
                logger.warning(f"Service restart timeout: {svc['name']}")
                flash(f'⏱️ Превышено время ожидания перезапуска {svc["name"]} (30с)', 'warning')

            return redirect(url_for('main.keys'))

        except ValueError as e:
            flash(f'❌ Ошибка в ключе: {str(e)}', 'danger')
            logger.error(f"save_key ValueError: {e}")
        except Exception as e:
            flash(f'❌ Ошибка: {str(e)}', 'danger')
            logger.error(f"save_key Exception: {e}")
    
    # GET запрос - показываем форму
    return render_template('key_generic.html', service=service, service_name=svc['name'])


@bp.route('/bypass')
@login_required
def bypass():
    """
    Render the bypass lists page.

    Requires authentication.
    """
    # Загрузка конфигурации
    config = WebConfig()
    unblock_dir = config.unblock_dir
    
    # Получение списка доступных файлов
    available_files = []
    if os.path.exists(unblock_dir):
        try:
            available_files = [
                f.replace('.txt', '') 
                for f in os.listdir(unblock_dir) 
                if f.endswith('.txt')
            ]
        except Exception as e:
            logger.error(f"Error listing bypass files: {e}")
    
    return render_template('bypass.html', available_files=available_files)


@bp.route('/bypass/view/<filename>')
@login_required
def view_bypass(filename: str):
    """
    View contents of a bypass list file.

    Args:
        filename: Name of bypass list file (without .txt extension)

    Returns:
        Rendered bypass view page with file contents
    """
    config = WebConfig()
    
    # Security: sanitize filename
    filename = secure_filename(filename)
    if not filename:
        flash('Неверное имя файла', 'danger')
        return redirect(url_for('main.bypass'))
    
    filepath = os.path.join(config.unblock_dir, f"{filename}.txt")

    # Загрузка списка
    entries = load_bypass_list(filepath)

    return render_template(
        'bypass_view.html',
        filename=filename,
        entries=entries,
        filepath=filepath
    )


@bp.route('/bypass/<filename>/add', methods=['GET', 'POST'])
@login_required
@csrf_required
def add_to_bypass(filename: str):
    """
    Add entries to a bypass list file.

    Args:
        filename: Name of bypass list file (without .txt extension)

    Returns:
        Redirect to view page after processing
    """
    config = WebConfig()
    
    # Security: sanitize filename
    filename = secure_filename(filename)
    if not filename:
        flash('Неверное имя файла', 'danger')
        return redirect(url_for('main.bypass'))
    
    filepath = os.path.join(config.unblock_dir, f"{filename}.txt")

    if request.method == 'POST':
        entries_text = request.form.get('entries', '')

        # Проверка на общий размер ввода (DoS protection)
        if len(entries_text) > MAX_TOTAL_INPUT_SIZE:
            flash(f'Превышен лимит размера ввода (макс. {MAX_TOTAL_INPUT_SIZE // 1024}KB)', 'danger')
            return redirect(url_for('main.bypass'))

        # Разбиваем на отдельные записи
        new_entries = [e.strip() for e in entries_text.split('\n') if e.strip()]

        # Проверка на количество записей (DoS protection)
        if len(new_entries) > MAX_ENTRIES_PER_REQUEST:
            flash(f'Превышено количество записей (макс. {MAX_ENTRIES_PER_REQUEST})', 'danger')
            return redirect(url_for('main.bypass'))

        # Проверка на длину записей (XSS + DoS protection)
        for entry in new_entries:
            if len(entry) > MAX_ENTRY_LENGTH:
                # XSS protection: escape user input
                flash(f'Запись слишком длинная (макс. {MAX_ENTRY_LENGTH} симв.): {escape(entry[:50])}...', 'danger')
                return redirect(url_for('main.bypass'))

        # Загружаем текущий список
        current_list = load_bypass_list(filepath)

        # Добавляем новые записи с валидацией
        added_count = 0
        invalid_entries = []
        ip_entries = []  # Отдельно собираем IP для добавления в ipset

        for entry in new_entries:
            if entry not in current_list:
                if validate_bypass_entry(entry):
                    current_list.append(entry)
                    added_count += 1
                    # Если это IP адрес - добавляем в список для ipset
                    if is_ip_address(entry):
                        ip_entries.append(entry)
                else:
                    invalid_entries.append(entry)

        # Сохраняем список
        save_bypass_list(filepath, current_list)

        # Bulk добавление в ipset (быстро!)
        ipset_msg = ''
        if ip_entries:
            # Убеждаемся что ipset существует
            success, msg = ensure_ipset_exists('unblock')
            if success:
                # Bulk добавление IP
                success, msg = bulk_add_to_ipset('unblock', ip_entries)
                ipset_msg = f" IP в ipset: {len(ip_entries)}"
                logger.info(f"ipset: {msg}")

        # Применяем изменения
        if added_count > 0:
            success, output = run_unblock_update()
            if success:
                flash(f'✅ Успешно добавлено: {added_count} шт.{ipset_msg}. Изменения применены', 'success')
            else:
                flash(f'⚠️ Добавлено {added_count} записей, но ошибка при применении: {output}', 'warning')
        elif invalid_entries:
            # XSS protection: escape user input
            escaped_invalid = [escape(e) for e in invalid_entries[:5]]
            flash(f'⚠️ Все записи уже в списке или невалидны. Нераспознанные: {", ".join(escaped_invalid)}', 'warning')
        else:
            flash('ℹ️ Все записи уже были в списке', 'info')

        return redirect(url_for('main.view_bypass', filename=filename))
    
    # GET запрос - показываем форму
    return render_template('bypass_add.html', filename=filename)


@bp.route('/bypass/<filename>/remove', methods=['GET', 'POST'])
@login_required
@csrf_required
def remove_from_bypass(filename: str):
    """
    Remove entries from a bypass list file.

    Args:
        filename: Name of bypass list file (without .txt extension)

    Returns:
        Redirect to view page after processing
    """
    config = WebConfig()
    
    # Security: sanitize filename
    filename = secure_filename(filename)
    if not filename:
        flash('Неверное имя файла', 'danger')
        return redirect(url_for('main.bypass'))
    
    filepath = os.path.join(config.unblock_dir, f"{filename}.txt")

    if request.method == 'POST':
        entries_text = request.form.get('entries', '')

        # Проверка на общий размер ввода (DoS protection)
        if len(entries_text) > MAX_TOTAL_INPUT_SIZE:
            flash(f'Превышен лимит размера ввода (макс. {MAX_TOTAL_INPUT_SIZE // 1024}KB)', 'danger')
            return redirect(url_for('main.bypass_view', filename=filename))

        # Разбиваем на отдельные записи
        to_remove = [e.strip() for e in entries_text.split('\n') if e.strip()]

        # Проверка на количество записей (DoS protection)
        if len(to_remove) > MAX_ENTRIES_PER_REQUEST:
            flash(f'Превышено количество записей (макс. {MAX_ENTRIES_PER_REQUEST})', 'danger')
            return redirect(url_for('main.bypass_view', filename=filename))

        # Загружаем текущий список
        current_list = load_bypass_list(filepath)

        # Удаляем записи, сохраняя порядок
        original_count = len(current_list)
        current_list = [item for item in current_list if item not in to_remove]
        removed_count = original_count - len(current_list)

        # Bulk удаление из ipset
        ip_entries = [e for e in to_remove if is_ip_address(e) and e in current_list]
        ipset_msg = ''
        if ip_entries:
            success, msg = bulk_remove_from_ipset('unblock', ip_entries)
            ipset_msg = f" IP из ipset: {len(ip_entries)}"
            logger.info(f"ipset: {msg}")

        # Сохраняем список
        save_bypass_list(filepath, current_list)

        # Применяем изменения
        if removed_count > 0:
            success, output = run_unblock_update()
            if success:
                flash(f'✅ Успешно удалено: {removed_count} шт.{ipset_msg}. Изменения применены', 'success')
            else:
                flash(f'⚠️ Удалено {removed_count} записей, но ошибка при применении: {output}', 'warning')
        else:
            flash('ℹ️ Ни одна запись не найдена в списке', 'info')

        return redirect(url_for('main.view_bypass', filename=filename))
    
    # GET запрос - показываем форму
    entries = load_bypass_list(filepath)
    return render_template('bypass_remove.html', filename=filename, entries=entries)


@bp.route('/bypass/<filename>/refresh', methods=['POST'])
@login_required
@csrf_required
def refresh_bypass_ipset(filename: str):
    """
    Refresh ipset from bypass list (resolve domains).

    Resolves all domains in the bypass list and adds their IPs to ipset.
    Uses parallel DNS resolution for speed (100 domains in ~5 seconds).

    Args:
        filename: Name of bypass list file (without .txt extension)

    Returns:
        Redirect to view page after processing

    Example:
        POST /bypass/unblocktor/refresh
        → Resolves domains and adds IPs to ipset
    """
    config = WebConfig()

    # Security: sanitize filename
    filename = secure_filename(filename)
    if not filename:
        flash('Неверное имя файла', 'danger')
        return redirect(url_for('main.bypass'))

    filepath = os.path.join(config.unblock_dir, f"{filename}.txt")

    # Check if file exists
    if not os.path.exists(filepath):
        flash('Файл не найден', 'danger')
        return redirect(url_for('main.view_bypass', filename=filename))

    # Refresh ipset (resolve domains + add IPs)
    from core.ipset_manager import refresh_ipset_from_file
    success, msg = refresh_ipset_from_file(filepath, max_workers=10)

    if success:
        flash(f'✅ {msg}', 'success')
    else:
        flash(f'❌ Ошибка: {msg}', 'danger')

    return redirect(url_for('main.view_bypass', filename=filename))


@bp.route('/bypass/catalog')
@login_required
def bypass_catalog():
    """
    Show list catalog.
    
    Requires authentication.
    """
    from core.list_catalog import get_catalog
    catalog = get_catalog()
    return render_template('bypass_catalog.html', catalog=catalog)


@bp.route('/bypass/catalog/<name>', methods=['POST'])
@login_required
@csrf_required
def download_list(name: str):
    """
    Download list from catalog.
    
    Requires authentication and CSRF token.
    """
    from core.list_catalog import download_list
    
    config = WebConfig()
    dest_dir = config.unblock_dir
    
    success, message, count = download_list(name, dest_dir)
    
    if success:
        flash(f'✅ {message}', 'success')
    else:
        flash(f'❌ {message}', 'danger')
    
    return redirect(url_for('main.bypass_catalog'))


@bp.route('/install')
@login_required
def install():
    """
    Render the install/remove page.

    Requires authentication.
    """
    return render_template('install.html')


@bp.route('/stats')
@login_required
def stats():
    """
    Render the statistics page.

    Requires authentication.
    """
    config = WebConfig()
    
    # Статистика по сервисам
    services = {
        'vless': {
            'name': 'VLESS',
            'init': '/opt/etc/init.d/S24xray',
            'config': '/opt/etc/xray/vless.json',
        },
        'shadowsocks': {
            'name': 'Shadowsocks',
            'init': '/opt/etc/init.d/S22shadowsocks',
            'config': '/opt/etc/shadowsocks.json',
        },
        'trojan': {
            'name': 'Trojan',
            'init': '/opt/etc/init.d/S22trojan',
            'config': '/opt/etc/trojan.json',
        },
        'tor': {
            'name': 'Tor',
            'init': '/opt/etc/init.d/S35tor',
            'config': '/opt/etc/tor/torrc',
        },
    }
    
    # Проверка статусов
    for svc in services.values():
        svc['status'] = check_service_status(svc['init'])
        svc['config_exists'] = os.path.exists(svc['config'])
    
    # Статистика по спискам обхода
    unblock_dir = config.unblock_dir
    bypass_lists = []
    total_domains = 0
    
    if os.path.exists(unblock_dir):
        for filename in os.listdir(unblock_dir):
            if filename.endswith('.txt'):
                filepath = os.path.join(unblock_dir, filename)
                try:
                    with open(filepath, 'r') as f:
                        lines = [line.strip() for line in f if line.strip() and not line.startswith('#')]
                        count = len(lines)
                        total_domains += count
                        bypass_lists.append({
                            'name': filename,
                            'count': count,
                            'path': filepath,
                        })
                except Exception as e:
                    logger.error(f"stats Exception reading {filename}: {e}")
    
    # Общая статистика
    active_services = sum(1 for s in services.values() if s['status'] == '✅ Активен')
    config_files = sum(1 for s in services.values() if s['config_exists'])
    
    stats_data = {
        'total_services': len(services),
        'active_services': active_services,
        'config_files': config_files,
        'total_bypass_lists': len(bypass_lists),
        'total_domains': total_domains,
        'services': services,
        'bypass_lists': bypass_lists,
    }
    
    return render_template('stats.html', stats=stats_data)


@bp.route('/service')
@login_required
def service():
    """
    Render the service menu page.

    Requires authentication.
    """
    # Проверка статуса DNS Override
    dns_override_enabled = False
    try:
        result = subprocess.run(
            ['ndmc', '-c', 'show running | grep dns-override'],
            capture_output=True, text=True, shell=True, timeout=5
        )
        dns_override_enabled = (result.returncode == 0 and 'dns-override' in result.stdout)
    except Exception as e:
        logger.error(f"Error checking DNS Override status: {e}")
        dns_override_enabled = False

    return render_template('service.html', dns_override_enabled=dns_override_enabled)


@bp.route('/service/restart-unblock', methods=['POST'])
@login_required
@csrf_required
def service_restart_unblock():
    """
    Restart the unblock service.

    Requires authentication.
    """
    init_script = '/opt/etc/init.d/S99unblock'
    success, output = restart_service('Unblock', init_script)
    
    if success:
        flash('✅ Unblock-сервис успешно перезапущен', 'success')
    else:
        flash(f'⚠️ Ошибка перезапуска: {output}', 'danger')
    
    return redirect(url_for('main.service'))


@bp.route('/service/restart-router', methods=['POST'])
@login_required
@csrf_required
def service_restart_router():
    """
    Restart the router.

    Requires authentication.
    """
    try:
        subprocess.run(['ndmc', '-c', 'system', 'reboot'], timeout=30)
        flash('✅ Команда на перезагрузку отправлена', 'success')
    except Exception as e:
        flash(f'❌ Ошибка: {str(e)}', 'danger')
        logger.error(f"service_reboot Exception: {e}")
    
    return redirect(url_for('main.service'))


@bp.route('/service/restart-all', methods=['POST'])
@login_required
@csrf_required
def service_restart_all():
    """
    Restart all VPN services.

    Requires authentication.
    """
    services = [
        ('Shadowsocks', '/opt/etc/init.d/S22shadowsocks'),
        ('Tor', '/opt/etc/init.d/S35tor'),
        ('VLESS', '/opt/etc/init.d/S24xray'),
        ('Trojan', '/opt/etc/init.d/S22trojan'),
    ]
    
    results = []
    for name, init_script in services:
        try:
            if os.path.exists(init_script):
                result = subprocess.run(
                    ['sh', init_script, 'restart'],
                    capture_output=True, text=True, timeout=60
                )
                status = '✅' if result.returncode == 0 else '❌'
                results.append(f"{status} {name}")
            else:
                results.append(f"⚠️ {name} (скрипт не найден)")
        except Exception as e:
            results.append(f"❌ {name}: {str(e)}")
            logger.error(f"service_restart_all Exception for {name}: {e}")
    
    flash('Перезапуск сервисов: ' + ', '.join(results), 'success')
    return redirect(url_for('main.service'))


@bp.route('/service/dns-override/<action>', methods=['POST'])
@login_required
@csrf_required
def service_dns_override(action):
    """
    Enable or disable DNS Override.

    Requires authentication.
    """
    import time
    enable = (action == 'on')

    try:
        # Проверка наличия ndmc
        result = subprocess.run(['which', 'ndmc'], capture_output=True, text=True)
        if result.returncode != 0:
            # ndmc не найден, пробуем альтернативные команды
            flash('⚠️ ndmc не найден. DNS Override недоступен.', 'warning')
            logger.warning("ndmc command not found")
            return redirect(url_for('main.service'))
        
        # Включение/выключение DNS Override
        cmd = ['ndmc', '-c', 'ip dns-override'] if enable else ['ndmc', '-c', 'no ip dns-override']
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            # Попытка с альтернативной командой
            cmd_alt = ['ndmc', '-c', 'opkg dns-override'] if enable else ['ndmc', '-c', 'no opkg dns-override']
            result_alt = subprocess.run(cmd_alt, capture_output=True, text=True, timeout=10)
            
            if result_alt.returncode != 0:
                flash(f'❌ Ошибка: {result_alt.stderr or result.stderr}', 'danger')
                logger.error(f"DNS Override error: {result_alt.stderr or result.stderr}")
                return redirect(url_for('main.service'))
        
        time.sleep(2)
        
        # Сохранение конфигурации
        subprocess.run(['ndmc', '-c', 'system', 'configuration', 'save'], timeout=10)
        
        # Автоматическая перезагрузка
        flash('✅ DNS Override ' + ('включен' if enable else 'выключен') + '. Роутер будет перезагружен...', 'success')
        logger.info("DNS Override changed, rebooting...")
        
        # Асинхронная перезагрузка (не блокируем ответ)
        subprocess.Popen(['ndmc', '-c', 'system', 'reboot'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
    except Exception as e:
        flash(f'❌ Ошибка: {str(e)}', 'danger')
        logger.error(f"service_dns_override Exception: {e}")

    return redirect(url_for('main.service'))


@bp.route('/service/backup', methods=['GET', 'POST'])
@login_required
def service_backup():
    """
    Create backup of configuration files.

    Requires authentication.
    """
    if request.method == 'POST':
        # CSRF check for POST requests
        token = session.get('csrf_token')
        form_token = request.form.get('csrf_token')
        if not token or not form_token or token != form_token:
            flash('Ошибка безопасности: неверный токен', 'danger')
            logger.warning("CSRF token validation failed in service_backup")
            return redirect(url_for('main.service'))

        from core.services import create_backup

        success, message = create_backup()

        if success:
            flash(f'✅ {message}', 'success')
        else:
            flash(f'❌ {message}', 'danger')

        return redirect(url_for('main.service'))

    # GET - показать страницу бэкапа
    return render_template('backup.html')


@bp.route('/service/updates')
@login_required
def service_updates():
    """
    Show updates page.

    Requires authentication.
    """
    from core.services import get_local_version, get_remote_version
    
    local_version = get_local_version()
    remote_version = get_remote_version()
    
    need_update = True
    if local_version != 'N/A' and remote_version != 'N/A':
        try:
            if tuple(map(int, local_version.split('.'))) >= tuple(map(int, remote_version.split('.'))):
                need_update = False
        except ValueError:
            pass
            logger.warning(f"get_updates_version: version parse error - local={local_version}, remote={remote_version}")
    
    return render_template('updates.html', 
                          local_version=local_version,
                          remote_version=remote_version,
                          need_update=need_update)


@bp.route('/service/updates/run', methods=['POST'])
@login_required
@csrf_required
def service_updates_run():
    """
    Run update process.

    Requires authentication.
    """
    try:
        flash('⏳ Загрузка обновлений...', 'info')

        # GitHub repository configuration
        github_repo = 'royfincher25-source/bypass_keenetic_web'
        github_branch = 'main'
        bot_source_path = 'src/bot3'
        bot_dest_dir = '/opt/etc/bot'

        files = ['bot_config.py', 'handlers.py', 'menu.py', 'utils.py', 'main.py']

        # Создаем директорию назначения
        os.makedirs(bot_dest_dir, exist_ok=True)

        for filename in files:
            url = f'https://raw.githubusercontent.com/{github_repo}/{github_branch}/{bot_source_path}/{filename}'
            try:
                response = requests.get(url, timeout=30)
                response.raise_for_status()

                filepath = os.path.join(bot_dest_dir, filename)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(response.text)

                logger.info(f"Updated {filename}")

            except requests.exceptions.RequestException as e:
                logger.error(f'Error downloading {filename}: {e}')
                flash(f'⚠️ Ошибка загрузки {filename}: {str(e)}', 'warning')
            except OSError as e:
                logger.error(f'Error writing {filename}: {e}')
                flash(f'⚠️ Ошибка записи {filename}: {str(e)}', 'warning')

        flash('✅ Обновление завершено!', 'success')
    except Exception as e:
        flash(f'❌ Ошибка обновления: {str(e)}', 'danger')
        logger.error(f"service_updates_run Exception: {e}")

    return redirect(url_for('main.service_updates'))


@bp.route('/install', methods=['GET', 'POST'])
@login_required
@csrf_required
def service_install():
    """
    Run installation script.

    Requires authentication.
    """
    if request.method == 'POST':
        script_path = '/opt/root/script.sh'
        local_script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'script.sh')
        resources_dir = os.path.join(os.path.dirname(__file__), 'resources')

        try:
            flash('⏳ Копирование скрипта установки...', 'info')

            # Проверка наличия локального скрипта
            if not os.path.exists(local_script_path):
                flash('❌ Ошибка: локальный скрипт не найден', 'danger')
                logger.error(f"Local script not found: {local_script_path}")
                return redirect(url_for('main.service_install'))

            # Чтение локального скрипта
            with open(local_script_path, 'r', encoding='utf-8') as f:
                script_content = f.read()

            # Создание директории назначения
            os.makedirs(os.path.dirname(script_path), exist_ok=True)

            # Запись скрипта на роутер
            with open(script_path, 'w', encoding='utf-8') as f:
                f.write(script_content)
            os.chmod(script_path, 0o755)

            flash('✅ Скрипт скопирован', 'success')
            logger.info(f"Script copied to {script_path}")

            # Копирование ресурсов на роутер
            if os.path.exists(resources_dir):
                flash('⏳ Копирование ресурсов...', 'info')
                resources_dest = '/opt/etc/web_ui/resources'
                os.makedirs(resources_dest, exist_ok=True)

                # Копирование файлов ресурсов
                import shutil
                for item in os.listdir(resources_dir):
                    src_item = os.path.join(resources_dir, item)
                    dest_item = os.path.join(resources_dest, item)
                    if os.path.isfile(src_item):
                        shutil.copy2(src_item, dest_item)
                    elif os.path.isdir(src_item):
                        if os.path.exists(dest_item):
                            shutil.rmtree(dest_item)
                        shutil.copytree(src_item, dest_item)

                flash('✅ Ресурсы скопированы', 'success')
                logger.info(f"Resources copied to {resources_dest}")

        except Exception as e:
            flash(f'❌ Ошибка копирования: {str(e)}', 'danger')
            logger.error(f"service_install copy Exception: {e}")
            return redirect(url_for('main.service_install'))
        
        try:
            flash('⏳ Установка началась...', 'info')
            
            process = subprocess.Popen(
                [script_path, '-install'],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            output_lines = []
            for line in process.stdout:
                output_lines.append(line.strip())
                flash(f'⏳ {line.strip()}', 'info')
            
            process.wait(timeout=600)
            
            if process.returncode == 0:
                flash('✅ Установка bypass_keenetic_web завершена', 'success')
            else:
                flash('❌ Ошибка установки', 'danger')
                
        except subprocess.TimeoutExpired:
            flash('❌ Превышен таймаут (10 минут)', 'danger')
            logger.error("service_install: timeout exceeded (10 minutes)")
        except Exception as e:
            flash(f'❌ Ошибка: {str(e)}', 'danger')
            logger.error(f"service_install Exception: {e}")
    
    return render_template('install.html')


@bp.route('/remove', methods=['GET', 'POST'])
@login_required
@csrf_required
def service_remove():
    """
    Run removal script.

    Requires authentication.
    """
    if request.method == 'POST':
        script_path = '/opt/root/script.sh'
        local_script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'script.sh')

        if not os.path.exists(script_path):
            try:
                flash('⏳ Копирование скрипта...', 'info')

                # Проверка наличия локального скрипта
                if not os.path.exists(local_script_path):
                    flash('❌ Ошибка: локальный скрипт не найден', 'danger')
                    logger.error(f"Local script not found: {local_script_path}")
                    return redirect(url_for('main.service_remove'))

                # Чтение локального скрипта
                with open(local_script_path, 'r', encoding='utf-8') as f:
                    script_content = f.read()

                # Создание директории назначения
                os.makedirs(os.path.dirname(script_path), exist_ok=True)

                # Запись скрипта на роутер
                with open(script_path, 'w', encoding='utf-8') as f:
                    f.write(script_content)
                os.chmod(script_path, 0o755)

                flash('✅ Скрипт скопирован', 'success')
                logger.info(f"Script copied to {script_path}")

            except Exception as e:
                flash(f'❌ Ошибка копирования скрипта: {str(e)}', 'danger')
                logger.error(f"service_remove copy Exception: {e}")
                return redirect(url_for('main.service_remove'))
        
        try:
            flash('⏳ Удаление началось...', 'info')
            
            process = subprocess.Popen(
                [script_path, '-remove'],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            for line in process.stdout:
                flash(f'⏳ {line.strip()}', 'info')
            
            process.wait(timeout=300)
            
            if process.returncode == 0:
                flash('✅ Удаление завершено', 'success')
            else:
                flash('❌ Ошибка удаления', 'danger')
                
        except subprocess.TimeoutExpired:
            flash('❌ Превышен таймаут (5 минут)', 'danger')
            logger.error("service_remove: timeout exceeded (5 minutes)")
        except Exception as e:
            flash(f'❌ Ошибка: {str(e)}', 'danger')
            logger.error(f"service_remove Exception: {e}")
    
    return render_template('install.html')


# =============================================================================
# DNS MONITOR ROUTES
# =============================================================================

@bp.route('/service/dns-monitor')
@login_required
def dns_monitor_status():
    """Show DNS monitor status"""
    from core.dns_monitor import get_dns_monitor
    monitor = get_dns_monitor()
    status = monitor.get_status()
    return render_template('dns_monitor.html', status=status)


@bp.route('/service/dns-monitor/start', methods=['POST'])
@login_required
@csrf_required
def dns_monitor_start():
    """Start DNS monitor"""
    from core.dns_monitor import get_dns_monitor
    monitor = get_dns_monitor()
    monitor.start()
    flash('✅ DNS monitor started', 'success')
    return redirect(url_for('main.dns_monitor_status'))


@bp.route('/service/dns-monitor/stop', methods=['POST'])
@login_required
@csrf_required
def dns_monitor_stop():
    """Stop DNS monitor"""
    from core.dns_monitor import get_dns_monitor
    monitor = get_dns_monitor()
    monitor.stop()
    flash('ℹ️ DNS monitor stopped', 'info')
    return redirect(url_for('main.dns_monitor_status'))


@bp.route('/service/dns-monitor/check', methods=['POST'])
@login_required
@csrf_required
def dns_monitor_check():
    """Force DNS check"""
    from core.dns_monitor import get_dns_monitor, check_dns_server

    monitor = get_dns_monitor()

    # Check current server
    if monitor._current_server:
        result = check_dns_server(
            monitor._current_server['host'],
            monitor._current_server['port']
        )
        if result['success']:
            flash(f"✅ DNS OK: {result['latency_ms']}ms", 'success')
        else:
            flash(f"❌ DNS failed: {result['error']}", 'danger')
    else:
        flash('⚠️ No DNS server selected', 'warning')

    return redirect(url_for('main.dns_monitor_status'))


# =============================================================================
# ROUTE REGISTRATION
# =============================================================================

def register_routes(app):
    """
    Register all routes with the Flask application.
    
    This function is called by create_app() to register all routes.
    The blueprint is already registered, this function can be used
    for additional route registration if needed.
    
    Args:
        app: Flask application instance
    """
    # Blueprint already registered in create_app()
    # This function exists for future extensibility
    pass


@bp.route('/logs')
@login_required
def view_logs():
    """
    View application logs.
    
    Requires authentication.
    """
    log_file = os.environ.get('LOG_FILE', '/opt/var/log/web_ui.log')
    lines = []
    error_lines = []
    
    try:
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                all_lines = f.readlines()
                lines = all_lines[-100:]  # Last 100 lines
                error_lines = [l for l in all_lines if 'ERROR' in l or 'CRITICAL' in l][-20:]
    except Exception as e:
        logger.error(f"view_logs Exception: {e}")
        flash(f'❌ Ошибка чтения логов: {str(e)}', 'danger')
    
    return render_template('logs.html', 
                          log_lines=lines, 
                          error_lines=error_lines,
                          log_file=log_file)


@bp.route('/logs/clear', methods=['POST'])
@login_required
@csrf_required
def clear_logs():
    """
    Clear application logs.
    
    Requires authentication.
    """
    log_file = os.environ.get('LOG_FILE', '/opt/var/log/web_ui.log')
    
    try:
        if os.path.exists(log_file):
            with open(log_file, 'w') as f:
                f.write('')
            flash('✅ Логи очищены', 'success')
        else:
            flash('⚠️ Файл логов не найден', 'warning')
    except Exception as e:
        flash(f'❌ Ошибка: {str(e)}', 'danger')
        logger.error(f"clear_logs Exception: {e}")
    
    return redirect(url_for('main.view_logs'))


# =============================================================================
# SHUTDOWN HOOKS
# =============================================================================

def shutdown_executor():
    """
    Gracefully shutdown ThreadPoolExecutor.

    Call this function during application shutdown to prevent resource leaks.
    """
    logger.info("Shutting down ThreadPoolExecutor...")
    executor.shutdown(wait=False)
    logger.info("ThreadPoolExecutor stopped")
