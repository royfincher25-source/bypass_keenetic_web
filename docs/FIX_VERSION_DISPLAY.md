# Отсутствие версии на странице обновлений

## Проблема
На странице `http://192.168.1.1:8080/service/updates` не отображается текущая версия проекта.

## Причина
Функция `get_local_version()` в `src/web_ui/core/services.py` искала файл `VERSION` по неправильному пути:
- Старый путь: `project_root/VERSION` (вычислялся относительно расположения `services.py`)
- На роутере: `/opt/VERSION` (не существует)
- Правильный путь: `/opt/etc/web_ui/VERSION`

Также файл `VERSION` не был включен в список файлов для автоматического обновления.

## Решение

### 1. Исправлено в репозитории:
- Функция `get_local_version()` теперь ищет файл по пути `/opt/etc/web_ui/VERSION`
- Файл `VERSION` добавлен в список обновления (`routes.py`)
- Файл `VERSION` добавлен в `install_web.sh` (уже был там, но теперь правильно используется)

### 2. Как применить на роутере:

**Вариант 1: Быстрое исправление**
```bash
ssh root@192.168.1.1
cd /tmp
curl -sL -o add_version.sh "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/add_version_file.sh"
chmod +x add_version.sh
./add_version.sh
```

**Вариант 2: Полное обновление**
Запустите скрипт `fix_all_problems.sh`:
```bash
ssh root@192.168.1.1
cd /tmp
curl -sL -o fix_all.sh "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/fix_all_problems.sh"
chmod +x fix_all.sh
./fix_all.sh
```

**Вариант 3: Обновить через веб-интерфейс**
Нажмите кнопку "Обновить" - файл `VERSION` будет скачан автоматически.

## Проверка
После применения исправлений перейдите на страницу `http://192.168.1.1:8080/service/updates` - текущая версия должна отображаться.

## Что делает скрипт
1. Проверяет наличие файла `/opt/etc/web_ui/VERSION`
2. Если файл отсутствует, скачивает его из репозитория
3. Устанавливает правильные права доступа
4. Перезапускает веб-интерфейс (если используется `fix_all_problems.sh`)