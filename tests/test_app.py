"""
Unit tests for Flask application
"""
import pytest
import json
from src.app import app


@pytest.fixture
def client():
    """Create a test client for the Flask application"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_home_endpoint(client):
    """Test home page endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'Flask DevOps Application' in response.data


def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data
    assert data['service'] == 'flask-devops-app'
    assert data['version'] == '1.0.0'


def test_info_endpoint(client):
    """Test system info endpoint"""
    response = client.get('/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'hostname' in data
    assert 'python_version' in data
    assert 'environment' in data
    assert 'cpu_usage' in data
    assert 'memory_usage' in data


def test_metrics_endpoint(client):
    """Test Prometheus metrics endpoint"""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert response.content_type == 'text/plain; charset=utf-8'
    # Check for Prometheus metrics format
    assert b'# HELP' in response.data or b'# TYPE' in response.data


def test_health_page_endpoint(client):
    """Test health page HTML endpoint"""
    response = client.get('/health-page')
    assert response.status_code == 200
    assert b'Health Check' in response.data or b'health' in response.data.lower()


def test_system_info_page_endpoint(client):
    """Test system info page HTML endpoint"""
    response = client.get('/system-info-page')
    assert response.status_code == 200
    assert b'system' in response.data.lower() or b'info' in response.data.lower()


def test_metrics_page_endpoint(client):
    """Test metrics page HTML endpoint"""
    response = client.get('/metrics-page')
    assert response.status_code == 200
    assert b'metrics' in response.data.lower()


def test_api_system_info_endpoint(client):
    """Test API system info endpoint"""
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
    """Test API metrics endpoint"""
    response = client.get('/api/metrics')
    assert response.status_code == 200
    assert response.content_type == 'text/plain; charset=utf-8'


def test_404_error(client):
    """Test 404 error handling"""
    response = client.get('/nonexistent-endpoint')
    assert response.status_code == 404


def test_health_endpoint_json_format(client):
    """Test health endpoint returns valid JSON"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, dict)
    assert 'status' in data


def test_metrics_contains_http_requests(client):
    """Test that metrics endpoint contains HTTP request metrics"""
    # Make a request first to generate metrics
    client.get('/health')
    response = client.get('/metrics')
    assert response.status_code == 200
    # Check for HTTP request metrics
    metrics_text = response.data.decode('utf-8')
    assert 'http' in metrics_text.lower() or 'request' in metrics_text.lower()

