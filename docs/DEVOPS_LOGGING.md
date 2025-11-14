# 📋 DevOps: Работа с логами

## 🎯 Основные подходы к логам

### 1. Логи Docker контейнеров

#### Просмотр логов приложения
```bash
# Последние 100 строк
sudo docker logs flask-app --tail 100

# Логи в реальном времени (follow)
sudo docker logs flask-app -f

# Логи с временными метками
sudo docker logs flask-app -t

# Логи за последние 10 минут
sudo docker logs flask-app --since 10m

# Логи между двумя временными метками
sudo docker logs flask-app --since "2025-11-14T10:00:00" --until "2025-11-14T11:00:00"
```

#### Логи всех контейнеров
```bash
# Все контейнеры
sudo docker ps --format "{{.Names}}" | xargs -I {} sudo docker logs {} --tail 50

# Только мониторинг
sudo docker logs prometheus --tail 100
sudo docker logs grafana --tail 100
sudo docker logs loki --tail 100
```

#### Поиск в логах
```bash
# Поиск ошибок
sudo docker logs flask-app 2>&1 | grep -i error

# Поиск по паттерну
sudo docker logs flask-app 2>&1 | grep -E "ERROR|WARN|500|504"

# Поиск с контекстом (5 строк до и после)
sudo docker logs flask-app 2>&1 | grep -i error -A 5 -B 5

# Подсчет ошибок
sudo docker logs flask-app 2>&1 | grep -i error | wc -l
```

### 2. Системные логи (systemd/journalctl)

#### Логи сервисов
```bash
# Логи Docker daemon
sudo journalctl -u docker --since "1 hour ago" -f

# Логи Nginx
sudo journalctl -u nginx -f

# Все системные логи
sudo journalctl -f

# Логи за сегодня
sudo journalctl --since today

# Логи с приоритетом ERROR и выше
sudo journalctl -p err -f
```

#### Поиск в системных логах
```bash
# Поиск по ключевому слову
sudo journalctl | grep -i "error\|fail\|critical"

# Логи конкретного процесса
sudo journalctl _PID=$(pgrep flask-app)

# Логи за период
sudo journalctl --since "2025-11-14 10:00:00" --until "2025-11-14 11:00:00"
```

### 3. Централизованное логирование (Loki)

#### Через Grafana UI
1. Откройте Grafana: http://YOUR_IP:3000
2. Перейдите в **Explore**
3. Выберите datasource **Loki**
4. Используйте LogQL запросы:

```logql
# Все логи Flask приложения
{container="flask-app"}

# Только ошибки
{container="flask-app"} |= "error"

# Ошибки с уровнем ERROR
{container="flask-app"} | json | level="ERROR"

# HTTP ошибки 5xx
{container="flask-app"} | json | status_code=~"5.."

# Логи за последний час с ошибками
{container="flask-app"} |= "error" [1h]

# Поиск по тексту
{container="flask-app"} |~ "timeout|connection refused"
```

#### Через API Loki
```bash
# Запрос логов через API
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="flask-app"}' \
  --data-urlencode 'start=1699996800000000000' \
  --data-urlencode 'end=1699997400000000000' \
  --data-urlencode 'limit=100' | jq

# Последние логи
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={container="flask-app"}' \
  --data-urlencode 'limit=100' | jq
```

### 4. Мониторинг в реальном времени

#### Мультиплексор логов (multitail)
```bash
# Установка
sudo apt install multitail

# Просмотр нескольких логов одновременно
multitail -s 2 \
  -l "sudo docker logs -f flask-app" \
  -l "sudo docker logs -f prometheus" \
  -l "sudo docker logs -f grafana"
```

#### Собственный скрипт для мониторинга
```bash
#!/bin/bash
# monitor-logs.sh

watch -n 2 'echo "=== Flask App ===" && \
  sudo docker logs flask-app --tail 5 && \
  echo "" && \
  echo "=== Prometheus ===" && \
  sudo docker logs prometheus --tail 3 && \
  echo "" && \
  echo "=== System Errors ===" && \
  sudo journalctl -p err --since "1 minute ago" --no-pager | tail -3'
```

### 5. Анализ и статистика

#### Топ ошибок
```bash
# Самые частые ошибки
sudo docker logs flask-app 2>&1 | \
  grep -i error | \
  sort | uniq -c | \
  sort -rn | head -10
```

#### Статистика по статус кодам
```bash
# Подсчет HTTP статус кодов
sudo docker logs flask-app 2>&1 | \
  grep -oP 'HTTP/\d\.\d"\s+\K\d{3}' | \
  sort | uniq -c | sort -rn
```

#### Время ответа
```bash
# Извлечение времени ответа из логов
sudo docker logs flask-app 2>&1 | \
  grep -oP 'response_time=\K[\d.]+' | \
  awk '{sum+=$1; count++} END {print "Avg:", sum/count, "ms"}'
```

### 6. Экспорт и сохранение логов

#### Сохранение логов в файл
```bash
# Сохранить логи за сегодня
sudo docker logs flask-app --since today > flask-app-$(date +%Y%m%d).log

# Сжать старые логи
gzip flask-app-*.log

# Экспорт с метаданными
sudo docker logs flask-app --timestamps > flask-app-full.log
```

#### Ротация логов
```bash
# Настроить log rotation для Docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

### 7. Полезные команды для диагностики

#### Быстрая диагностика
```bash
# Проверка здоровья всех сервисов
for container in $(sudo docker ps --format "{{.Names}}"); do
  echo "=== $container ==="
  sudo docker logs $container --tail 5
  echo ""
done

# Поиск проблем за последний час
echo "=== Errors in last hour ==="
sudo docker logs flask-app --since 1h 2>&1 | grep -i error
sudo journalctl --since "1 hour ago" -p err
```

#### Мониторинг ресурсов + логи
```bash
# Комбинированный мониторинг
watch -n 5 '
  echo "=== Containers ==="
  sudo docker ps --format "table {{.Names}}\t{{.Status}}"
  echo ""
  echo "=== Recent Errors ==="
  sudo docker logs flask-app --since 5m 2>&1 | grep -i error | tail -3
  echo ""
  echo "=== Memory ==="
  free -h | grep Mem
'
```

### 8. Best Practices

#### ✅ Что делать:
- Использовать структурированное логирование (JSON)
- Добавлять корреляционные ID для трейсинга
- Настраивать уровни логирования (DEBUG, INFO, WARN, ERROR)
- Централизовать логи (Loki, ELK, etc.)
- Настраивать алерты на критические ошибки
- Ротировать логи для экономии места

#### ❌ Чего избегать:
- Логировать чувствительные данные (пароли, токены)
- Логировать слишком много (шум)
- Хранить логи бесконечно
- Игнорировать предупреждения

### 9. Инструменты для работы с логами

```bash
# jq - для работы с JSON логами
sudo docker logs flask-app 2>&1 | jq 'select(.level=="ERROR")'

# less - для просмотра больших файлов
sudo docker logs flask-app 2>&1 | less

# tail -f - для мониторинга в реальном времени
tail -f /var/log/syslog

# grep с регулярными выражениями
sudo docker logs flask-app 2>&1 | grep -E "ERROR|WARN|(5[0-9]{2})"

# awk - для обработки
sudo docker logs flask-app 2>&1 | awk '/ERROR/ {print $1, $2, $NF}'
```

### 10. Алерты на основе логов

#### Настройка алертов в Prometheus
```yaml
# monitoring/prometheus/alerts.yml
- alert: HighErrorRate
  expr: rate(flask_http_requests_total{status=~"5.."}[5m]) > 0.1
  for: 5m
  annotations:
    summary: "High error rate detected"
```

#### Алерты в Grafana
- Создайте alert rule в Grafana
- Используйте LogQL запросы
- Настройте уведомления (email, Slack, etc.)

---

## 🚀 Быстрый старт для вашего проекта

```bash
# 1. Проверить все логи
cd /path/to/project
./scripts/check-app-remote.sh

# 2. Мониторинг в реальном времени
sudo docker logs flask-app -f

# 3. Поиск ошибок
sudo docker logs flask-app 2>&1 | grep -i error

# 4. Открыть Grafana для централизованного просмотра
# http://YOUR_IP:3000 → Explore → Loki
```

