# 🔧 Исправление маршрутизации трафика

**Проблема:** DNS работает, но сайты не открываются (YouTube, rutracker.org)

**Причина:** Трафик не перенаправляется через Shadowsocks — не настроены правила iptables.

---

## 📋 Диагностика

```bash
# Проверка iptables правил
ssh root@192.168.1.1 -p 222 "iptables-save | grep 1082"

# Если пусто — правила не применены!
```

---

## ✅ Решение (быстрое)

### Способ 1: Автоматическое применение правил

```bash
# 1. Копирование скрипта
scp H:\disk_e\dell\bypass_keenetic-web\scripts\apply_routing.sh root@192.168.1.1:/opt/root/

# 2. Запуск
ssh root@192.168.1.1 -p 222 "sh /opt/root/apply_routing.sh"
```

---

### Способ 2: Вручную (по шагам)

```bash
# Подключение к роутеру
ssh root@192.168.1.1 -p 222

# 1. Создание ipset
ipset create unblocksh hash:net -exist
ipset create unblocktor hash:net -exist
ipset create unblockvless hash:net -exist
ipset create unblocktroj hash:net -exist

# 2. Заполнение ipset
sh /opt/bin/unblock_ipset.sh

# 3. Применение правил iptables
sh /opt/etc/ndm/fs.d/100-redirect.sh

# Выход
exit
```

---

### Способ 3: Перезапуск сервиса unblock

```bash
# Перезапуск S99unblock (применяет правила)
ssh root@192.168.1.1 -p 222 "/opt/etc/init.d/S99unblock restart"
```

---

## 🔍 Проверка после применения

### 1. Проверка ipset:
```bash
ssh root@192.168.1.1 -p 222 "ipset list unblocksh | head -10"
```

**✅ Ожидается:** Список IP адресов

---

### 2. Проверка iptables:
```bash
ssh root@192.168.1.1 -p 222 "iptables-save | grep unblocksh"
```

**✅ Ожидается:**
```
-A PREROUTING -p tcp -m set --match-set unblocksh dst -j REDIRECT --to-ports 1082
-A PREROUTING -p udp -m set --match-set unblocksh dst -j REDIRECT --to-ports 1082
```

---

### 3. Тест доступа:
```cmd
# Windows CMD
nslookup rutracker.org 192.168.1.1

# Должен вернуться IP адрес
# Сайт должен открываться в браузере
```

---

## 📝 Обновление S99unblock (для автозагрузки)

Скрипт `S99unblock` обновлён — теперь он автоматически применяет правила iptables при загрузке.

**Копирование на роутер:**
```bash
scp H:\disk_e\dell\bypass_keenetic-web\src\web_ui\resources\scripts\S99unblock root@192.168.1.1:/opt/etc/init.d/
```

**Или вручную:**
```bash
ssh root@192.168.1.1 -p 222

# Редактирование
vi /opt/etc/init.d/S99unblock

# Добавить после строки "/opt/bin/unblock_ipset.sh":
echo "Setting up iptables redirect rules..."
/opt/etc/ndm/fs.d/100-redirect.sh
```

---

## 🎯 Полный цикл применения

```bash
# 1. Применить правила вручную
ssh root@192.168.1.1 -p 222 "sh /opt/root/apply_routing.sh"

# 2. Обновить S99unblock для автозагрузки
scp H:\disk_e\dell\bypass_keenetic-web\src\web_ui\resources\scripts\S99unblock root@192.168.1.1:/opt/etc/init.d/

# 3. Перезагрузить роутер
ssh root@192.168.1.1 -p 222 "ndmc -c 'system reboot'"

# 4. После перезагрузки проверить
ssh root@192.168.1.1 -p 222 "sh /opt/root/check_routing.sh"
```

---

## 🐛 Частые проблемы

| Проблема | Решение |
|----------|---------|
| **ipset не создаётся** | Проверить модуль ядра: `lsmod \| grep ipset` |
| **iptables не найден** | Установить: `opkg install iptables` |
| **100-redirect.sh не найден** | Копировать: `scp .../100-redirect.sh root@192.168.1.1:/opt/etc/ndm/fs.d/` |
| **Правила сбрасываются** | Обновить S99unblock (см. выше) |

---

## 📞 Проверка работы

После применения правил:

1. ✅ **DNS разрешает** (проверено через nslookup)
2. ✅ **iptables правила есть** (проверено через iptables-save)
3. ✅ **ipset заполнен** (проверено через ipset list)
4. ✅ **Сайты открываются** (YouTube, rutracker.org)

Если всё ещё не работает — проверить логи:
```bash
tail -50 /opt/var/log/web_ui.log
```
