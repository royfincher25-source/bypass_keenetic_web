# Scripts Directory

Эта директория содержит скрипты для установки и удаления bypass_keenetic.

## Файлы

- `script.sh` — основной скрипт установки/удаления
- `script.sh.md5` — MD5 хэш для проверки целостности
- `.gitkeep` — файл для отслеживания директории в git

## Обновление скрипта

Для обновления script.sh из репозитория-донора:

```bash
# Скопировать из test проекта
cp ../test/src/bot3/script.sh ./script.sh

# Обновить MD5 хэш
certutil -hashfile script.sh MD5 > script.sh.md5
```

## Использование

Скрипт копируется на роутер при установке через веб-интерфейс:

- **Путь на роутере:** `/opt/root/script.sh`
- **Права:** 755 (исполняемый)
- **Использование:** `script.sh -install` или `script.sh -remove`

## Принцип работы

1. Веб-интерфейс копирует `script.sh` из локальной директории `scripts/`
2. Скрипт размещается в `/opt/root/script.sh` на роутере
3. Скрипт запускается с аргументом `-install` или `-remove`
4. `script.sh` загружает остальные файлы bypass_keenetic с GitHub

## URL для загрузки файлов

Скрипт использует `base_url` из конфигурации `/opt/etc/bot/bot_config.py`:

```python
base_url = "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic/main"
```

**Важно:** Убедитесь, что `bot_config.py` содержит правильный URL!
