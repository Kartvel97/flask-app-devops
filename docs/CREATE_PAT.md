# Создание Personal Access Token для GHCR

## Проблема

GITHUB_TOKEN может не иметь прав на создание новых пакетов в GHCR, даже с правильными permissions в workflow.

## Решение: Создать Personal Access Token

### Шаг 1: Создать PAT

1. Перейдите на https://github.com/settings/tokens
2. Нажмите **Generate new token** → **Generate new token (classic)**
3. Название: `GHCR_PAT` (или любое другое)
4. Срок действия: выберите нужный (например, 90 дней или No expiration)
5. Права (scopes):
   - ✅ **write:packages** - для записи в Container Registry
   - ✅ **read:packages** - для чтения из Container Registry
   - ✅ **delete:packages** - опционально, для удаления пакетов
6. Нажмите **Generate token**
7. **ВАЖНО:** Скопируйте токен сразу (он показывается только один раз!)

### Шаг 2: Добавить PAT в GitHub Secrets

1. Перейдите в репозиторий → **Settings** → **Secrets and variables** → **Actions**
2. Нажмите **New repository secret**
3. Name: `GHCR_PAT`
4. Value: вставьте скопированный токен
5. Нажмите **Add secret**

### Шаг 3: Обновить workflow

Использовать `GHCR_PAT` вместо `GITHUB_TOKEN` в workflow.

