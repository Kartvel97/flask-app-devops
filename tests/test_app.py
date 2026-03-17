import pytest
import json
from src.app import app

# TODO: добавить тесты на error handlers


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_home_endpoint(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b'Flask DevOps Application' in response.data


def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data
    assert data['service'] == 'flask-devops-app'
    assert data['version'] == '1.0.0'


def test_info_endpoint(client):
    response = client.get('/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'hostname' in data
    assert 'python_version' in data
    assert 'environment' in data
    assert 'cpu_usage' in data
    assert 'memory_usage' in data


def test_metrics_endpoint(client):
    response = client.get('/metrics')
    assert response.status_code == 200
    assert response.content_type == 'text/plain; charset=utf-8'
    assert b'# HELP' in response.data or b'# TYPE' in response.data


def test_health_page_endpoint(client):
    response = client.get('/health-page')
    assert response.status_code == 200
    assert b'Health Check' in response.data or b'health' in response.data.lower()


def test_system_info_page_endpoint(client):
    response = client.get('/system-info-page')
    assert response.status_code == 200
    assert b'system' in response.data.lower() or b'info' in response.data.lower()


def test_metrics_page_endpoint(client):
    response = client.get('/metrics-page')
    assert response.status_code == 200
    assert b'metrics' in response.data.lower()


def test_api_system_info_endpoint(client):
    response = client.get('/api/system-info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'hostname' in data
    assert 'platform' in data
    assert 'cpu_cores' in data
    assert 'total_memory' in data
    assert 'cpu_usage' in data
    assert 'memory_usage' in data


def test_api_metrics_endpoint(client):
    response = client.get('/api/metrics')
    assert response.status_code == 200
    assert response.content_type == 'text/plain; charset=utf-8'


def test_404_error(client):
    response = client.get('/nonexistent-endpoint')
    assert response.status_code == 404


def test_health_endpoint_json_format(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, dict)
    assert 'status' in data


def test_metrics_contains_http_requests(client):
    client.get('/health')  # генерим метрики
    response = client.get('/metrics')
    assert response.status_code == 200
    metrics_text = response.data.decode('utf-8')
    assert 'http' in metrics_text.lower() or 'request' in metrics_text.lower()

