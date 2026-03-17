# 📋 Setup Requirements

**Complete setup guide for deploying the Flask DevOps project from scratch.**

---

## ✅ What Works Out of the Box

After cloning the repository, these components are ready to use:

- ✅ **Application Code** — All Flask application files
- ✅ **Docker Configuration** — Dockerfile and requirements.txt
- ✅ **Terraform Configuration** — Infrastructure as Code ready
- ✅ **Ansible Playbooks** — All automation scripts
- ✅ **GitHub Actions Workflow** — CI/CD pipeline (requires secrets)
- ✅ **Tests** — Pytest configuration and test suite
- ✅ **Monitoring Stack** — Prometheus, Grafana, Loki configurations (Grafana dashboards and alerts automatically configured on deployment)
- ✅ **Backup System** — Automated backup scripts

---

## ⚠️ Required Setup

### 1️⃣ AWS Account & Credentials

```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: eu-central-1
# - Default output format: json
```

---

### 2️⃣ SSH Key in AWS

```bash
# Option 1: Create new key pair in AWS Console
# Go to: EC2 → Key Pairs → Create key pair
# Download the .pem file and save to ~/.ssh/

# Option 2: Create via AWS CLI
aws ec2 create-key-pair \
  --key-name flask-app-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/flask-app-key.pem

chmod 400 ~/.ssh/flask-app-key.pem
```

---

### 3️⃣ Terraform Deployment

```bash
cd terraform
terraform init
terraform plan -var="ssh_key_name=flask-app-key"
terraform apply -var="ssh_key_name=flask-app-key"

# Get the public IP
terraform output public_ip
```

**Expected Output:**
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
Outputs:
public_ip = "YOUR_EC2_PUBLIC_IP"
```

---

### 4️⃣ Ansible Inventory Configuration

```bash
# Copy the example inventory file
cp ansible/inventory.ini.example ansible/inventory.ini

# Edit ansible/inventory.ini
nano ansible/inventory.ini  # or use your preferred editor
```

**Update the following:**
```ini
[flask]
YOUR_EC2_PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/flask-app-key.pem

[flask:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3
```

Replace:
- `YOUR_EC2_PUBLIC_IP` → IP from `terraform output public_ip`
- `~/.ssh/flask-app-key.pem` → Path to your SSH private key

---

### 5️⃣ GitHub Secrets (for CI/CD)

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_HOST` | EC2 public IP | Public IP address of your EC2 instance |
| `AWS_SSH_KEY` | SSH private key content | Full content of your `.pem` file |

**Example:**
```bash
# Get SSH key content
cat ~/.ssh/flask-app-key.pem
# Copy the entire output and paste as AWS_SSH_KEY secret value
```

---

## 🚀 Quick Start Guide

### Step-by-Step Deployment

```bash
# 1. Clone the repository
git clone https://github.com/Kartvel97/flask-app-devops.git
cd flask-app-devops

# 2. Configure AWS credentials
aws configure

# 3. Deploy infrastructure with Terraform
cd terraform
terraform init
terraform apply -var="ssh_key_name=flask-app-key"

# 4. Get the EC2 public IP
terraform output public_ip

# 5. Configure Ansible inventory
cd ../ansible
cp inventory.ini.example inventory.ini
# Edit inventory.ini with your IP and SSH key path

# 6. Deploy the application
ansible-playbook -i inventory.ini deploy-flask-app.yml

# 7. Setup monitoring stack
ansible-playbook -i inventory.ini setup-monitoring.yml
# Note: Grafana dashboards and alerts are automatically configured during deployment

# 8. Setup Nginx + SSL (optional, requires domain)
ansible-playbook -i inventory.ini setup-nginx-ssl.yml \
  -e "domain_name=your-domain.com" \
  -e "email=devops@yourdomain.com"
```

---

## ❌ What Won't Work Without Setup

| Component | Requirement | Status |
|-----------|-------------|--------|
| **GitHub Actions CI/CD** | GitHub Secrets (`AWS_HOST`, `AWS_SSH_KEY`) | ⚠️ Requires setup |
| **S3 Backups** | AWS account (auto-configured) | ✅ Auto-setup after Terraform |
| **Grafana Dashboards** | None | ✅ Auto-imported on deployment |
| **Grafana Alerts** | None | ✅ Auto-configured on deployment |
| **Cloudflare** | Domain name | ⚠️ Optional |
| **SSL Certificates** | Domain name for Let's Encrypt | ⚠️ Optional |

---

## 📝 Pre-Deployment Checklist

- [ ] AWS account created
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] SSH key pair created in AWS
- [ ] Terraform applied successfully (`terraform apply`)
- [ ] Ansible inventory configured with correct IP and SSH key path
- [ ] GitHub secrets configured (for CI/CD automation)
- [ ] Domain name configured (optional, for SSL)

---

## 💡 Recommendations

### For Local Testing

- Run the application locally using Docker:
  ```bash
  docker build -t flask-app -f docker/Dockerfile .
  docker run -p 5000:5000 flask-app
  ```
- Run tests without AWS:
  ```bash
  pip install -r docker/requirements.txt
  pip install -r tests/requirements.txt
  pytest tests/ -v
  ```

### For Full Deployment

- AWS account required (free tier available)
- SSH key pair required
- Domain name recommended for SSL certificates
- Estimated setup time: **15-30 minutes** for experienced users, **1-2 hours** for beginners

---

## 🎯 Summary

The project is **not fully "out of the box"** but requires minimal setup:
- ✅ All code and configurations are ready
- ⚠️ AWS credentials and SSH key setup required
- ⚠️ Ansible inventory configuration needed
- ✅ Complete documentation provided

---

## 📚 Additional Resources

- 📖 [Main README](README.md) — Full project documentation

---

**Need Help?**  
Open an issue on GitHub or contact the project maintainer.

---

# 🇺🇦 Вимоги для налаштування

**Повний посібник з налаштування проєкту Flask DevOps з нуля.**

---

## ✅ Що працює "з коробки"

Після клонування репозиторію ці компоненти готові до використання:

- ✅ **Код застосунку** — Всі файли Flask застосунку
- ✅ **Docker конфігурація** — Dockerfile та requirements.txt
- ✅ **Terraform конфігурація** — Infrastructure as Code готовий
- ✅ **Ansible playbooks** — Всі скрипти автоматизації
- ✅ **GitHub Actions workflow** — CI/CD pipeline (потребує secrets)
- ✅ **Тести** — Pytest конфігурація та набір тестів
- ✅ **Стек моніторингу** — Конфігурації Prometheus, Grafana, Loki (дашборди та алерти Grafana автоматично налаштовуються при деплої)
- ✅ **Система бэкапів** — Автоматизовані скрипти бэкапів

---

## ⚠️ Необхідне налаштування

### 1️⃣ AWS аккаунт та облікові дані

```bash
# Встановити AWS CLI (якщо не встановлено)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Налаштувати облікові дані AWS
aws configure
# Ввести:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: eu-central-1
# - Default output format: json
```

---

### 2️⃣ SSH ключ в AWS

```bash
# Варіант 1: Створити нову пару ключів в AWS Console
# Перейти: EC2 → Key Pairs → Create key pair
# Завантажити .pem файл і зберегти в ~/.ssh/

# Варіант 2: Створити через AWS CLI
aws ec2 create-key-pair \
  --key-name flask-app-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/flask-app-key.pem

chmod 400 ~/.ssh/flask-app-key.pem
```

---

### 3️⃣ Деплой через Terraform

```bash
cd terraform
terraform init
terraform plan -var="ssh_key_name=flask-app-key"
terraform apply -var="ssh_key_name=flask-app-key"

# Отримати публічний IP
terraform output public_ip
```

**Очікуваний результат:**
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
Outputs:
public_ip = "YOUR_EC2_PUBLIC_IP"
```

---

### 4️⃣ Налаштування Ansible inventory

```bash
# Скопіювати приклад inventory файлу
cp ansible/inventory.ini.example ansible/inventory.ini

# Відредагувати ansible/inventory.ini
nano ansible/inventory.ini  # або використайте свій редактор
```

**Оновити наступне:**
```ini
[flask]
YOUR_EC2_PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/flask-app-key.pem

[flask:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3
```

Замінити:
- `YOUR_EC2_PUBLIC_IP` → IP з `terraform output public_ip`
- `~/.ssh/flask-app-key.pem` → Шлях до вашого приватного SSH ключа

---

### 5️⃣ GitHub Secrets (для CI/CD)

Перейти до вашого GitHub репозиторію → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Додати наступні secrets:

| Secret Name | Value | Опис |
|-------------|-------|------|
| `AWS_HOST` | EC2 публічний IP | Публічна IP адреса вашого EC2 інстанса |
| `AWS_SSH_KEY` | Вміст SSH приватного ключа | Повний вміст вашого `.pem` файлу |

**Приклад:**
```bash
# Отримати вміст SSH ключа
cat ~/.ssh/flask-app-key.pem
# Скопіювати весь вивід і вставити як значення secret AWS_SSH_KEY
```

---

## 🚀 Швидкий старт

### Покроковий деплой

```bash
# 1. Клонувати репозиторій
git clone https://github.com/Kartvel97/flask-app-devops.git
cd flask-app-devops

# 2. Налаштувати облікові дані AWS
aws configure

# 3. Розгорнути інфраструктуру через Terraform
cd terraform
terraform init
terraform apply -var="ssh_key_name=flask-app-key"

# 4. Отримати публічний IP EC2
terraform output public_ip

# 5. Налаштувати Ansible inventory
cd ../ansible
cp inventory.ini.example inventory.ini
# Відредагувати inventory.ini з вашим IP та шляхом до SSH ключа

# 6. Задеплоїти застосунок
ansible-playbook -i inventory.ini deploy-flask-app.yml

# 7. Налаштувати стек моніторингу
ansible-playbook -i inventory.ini setup-monitoring.yml
# Примітка: Дашборди та алерти Grafana автоматично налаштовуються під час деплою

# 8. Налаштувати Nginx + SSL (опціонально, потрібен домен)
ansible-playbook -i inventory.ini setup-nginx-ssl.yml \
  -e "domain_name=your-domain.com" \
  -e "email=devops@yourdomain.com"
```

---

## ❌ Що не працюватиме без налаштування

| Компонент | Вимога | Статус |
|-----------|--------|--------|
| **GitHub Actions CI/CD** | GitHub Secrets (`AWS_HOST`, `AWS_SSH_KEY`) | ⚠️ Потребує налаштування |
| **S3 бэкапи** | AWS аккаунт (автоматично налаштовується) | ✅ Автоматично після Terraform |
| **Grafana дашборди** | Немає | ✅ Автоматично імпортуються при деплої |
| **Grafana алерти** | Немає | ✅ Автоматично налаштовуються при деплої |
| **Cloudflare** | Домен | ⚠️ Опціонально |
| **SSL сертифікати** | Домен для Let's Encrypt | ⚠️ Опціонально |

---

## 📝 Чеклист перед деплоєм

- [ ] AWS аккаунт створено
- [ ] AWS CLI встановлено та налаштовано (`aws configure`)
- [ ] SSH пара ключів створена в AWS
- [ ] Terraform успішно застосовано (`terraform apply`)
- [ ] Ansible inventory налаштовано з правильним IP та шляхом до SSH ключа
- [ ] GitHub secrets налаштовано (для автоматизації CI/CD)
- [ ] Домен налаштовано (опціонально, для SSL)

---

## 💡 Рекомендації

### Для локального тестування

- Запустити застосунок локально через Docker:
  ```bash
  docker build -t flask-app -f docker/Dockerfile .
  docker run -p 5000:5000 flask-app
  ```
- Запустити тести без AWS:
  ```bash
  pip install -r docker/requirements.txt
  pip install -r tests/requirements.txt
  pytest tests/ -v
  ```

### Для повного деплою

- Потрібен AWS аккаунт (доступний безкоштовний рівень)
- Потрібна пара SSH ключів
- Рекомендується домен для SSL сертифікатів
- Орієнтовний час налаштування: **15-30 хвилин** для досвідчених користувачів, **1-2 години** для початківців

---

## 🎯 Підсумок

Проєкт **не працює повністю "з коробки"**, але потребує мінімального налаштування:
- ✅ Весь код та конфігурації готові
- ⚠️ Потрібно налаштувати облікові дані AWS та SSH ключ
- ⚠️ Потрібна конфігурація Ansible inventory
- ✅ Надано повну документацію

---

## 📚 Додаткові ресурси

- 📖 [Головний README](README.md) — Повна документація проєкту

---

**Потрібна допомога?**  
Створіть issue на GitHub або зв'яжіться з автором проєкту.
