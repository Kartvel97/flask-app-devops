from flask import Flask, Response, request, render_template, jsonify
import random
import socket
import os
import time
import psutil
import platform
import logging
import traceback
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from datetime import datetime

app = Flask(__name__)

# Simple logging setup (learned from Python logging documentation)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics (learned from prometheus_client documentation)
# Using Counter, Histogram, and Gauge to track application metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP Requests', ['method', 'endpoint', 'status_code'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency', ['endpoint'])
CPU_USAGE = Gauge('app_cpu_usage_percent', 'CPU usage percentage')
MEMORY_USAGE = Gauge('app_memory_usage_mb', 'Memory usage in MB')
ACTIVE_USERS = Gauge('app_active_users', 'Active users count')

quotes = [
    "Das Schönste, was wir erleben können, ist das Geheimnisvolle. (Albert Einstein)",
    "Vergiss nie, wie weit du schon gekommen bist.",
    "Die besten Geschichten schreibt das Leben selbst.",
    "Jeder Mensch trägt ein Licht in sich.",
    "Manchmal muss man loslassen, um frei zu sein.",
    "Veränderung beginnt mit dem ersten Schritt.",
    "Wo ein Wille ist, ist auch ein Weg.",
    "Die Stille sagt oft mehr als tausend Worte.",
    "Es ist nie zu spät, das zu werden, was man hätte sein können.",
    "Ein Lächeln ist der kürzeste Weg zwischen zwei Menschen.",
    "Wenn du das Licht nicht findest, sei selbst das Licht.",
    "Liebe ist kein Wort, sondern ein Gefühl, das man lebt.",
    "Die Zeit heilt nicht alles, aber sie rückt vieles ins rechte Licht.",
    "Du bist genug, so wie du bist.",
    "Das Leben ist zu kurz für irgendwann.",
    "Jeder Tag ist eine zweite Chance.",
    "Am Ende wird alles gut. Wenn es nicht gut wird, ist es noch nicht das Ende. (Oscar Wilde)",
    "Glück ist das einzige, das sich verdoppelt, wenn man es teilt.",
    "Man sieht nur mit dem Herzen gut. Das Wesentliche ist für die Augen unsichtbar. (Antoine de Saint-Exupéry)",
    "Die besten Dinge im Leben sind nicht die, die man für Geld bekommt. (Albert Einstein)",
    "Träume nicht dein Leben, sondern lebe deinen Traum.",
    "Wer den Tag mit einem Lächeln beginnt, hat ihn bereits gewonnen.",
    "Hello World!",
    "Automate all the things!",
    "Infrastructure as Code - the future!"
]

def get_system_metrics():
    """Get system metrics for Prometheus"""
    CPU_USAGE.set(psutil.cpu_percent())
    MEMORY_USAGE.set(psutil.virtual_memory().used / 1024 / 1024)
    ACTIVE_USERS.set(random.randint(1, 100))

def format_uptime(seconds):
    """Format uptime seconds to human readable"""
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    
    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"

def format_timestamp(timestamp):
    """Format timestamp to readable date"""
    return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')

@app.before_request
def before_request():
    """Log request start"""
    request.start_time = time.time()
    logger.info(f"Request: {request.method} {request.path}")

@app.after_request
def after_request(response):
    """Log request completion and update metrics"""
    get_system_metrics()
    if hasattr(request, 'start_time'):
        latency = time.time() - request.start_time
        # Update Prometheus metrics (learned from prometheus_client examples)
        REQUEST_LATENCY.labels(request.path).observe(latency)
        REQUEST_COUNT.labels(request.method, request.path, response.status_code).inc()
        
        # Simple logging
        if response.status_code >= 400:
            logger.warning(f"Request completed: {request.method} {request.path} - Status: {response.status_code}")
        else:
            logger.info(f"Request completed: {request.method} {request.path} - Status: {response.status_code}")
    return response

@app.route("/")
def home():
    quote = random.choice(quotes)
    hostname = socket.gethostname()
    return f"""
    <html>
        <head>
            <title>Flask DevOps App</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                .quote {{ font-size: 24px; color: #333; margin-bottom: 20px; padding: 20px; background: #f8f9fa; border-left: 4px solid #007bff; }}
                .info {{ color: #666; margin: 10px 0; padding: 8px; }}
                .status {{ color: #28a745; font-weight: bold; }}
                .nav-links {{ margin-top: 20px; }}
                .nav-links a {{ display: inline-block; margin: 5px 10px; padding: 10px 15px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }}
                .nav-links a:hover {{ background: #0056b3; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Flask DevOps Application</h1>
                <div class="quote">"{quote}"</div>
                <div class="info"><strong>Host:</strong> {hostname}</div>
                <div class="info"><strong>Deployed with:</strong> Ansible + Docker</div>
                <div class="status">Application is running successfully</div>
                
                <div class="nav-links">
                    <h3>Standard Endpoints:</h3>
                    <a href="/health">Health Check (JSON)</a>
                    <a href="/info">System Info (JSON)</a>
                    <a href="/metrics">Prometheus Metrics</a>
                    
                    <h3 style="margin-top: 20px;">Pages:</h3>
                    <a href="/health-page">Health Check</a>
                    <a href="/system-info-page">System Info</a>
                    <a href="/metrics-page">Metrics</a>
                </div>
            </div>
        </body>
    </html>
    """

@app.route("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "service": "flask-devops-app",
        "version": "1.0.0"
    }

@app.route("/info")
def info():
    return {
        "hostname": socket.gethostname(),
        "python_version": os.environ.get('PYTHON_VERSION', '3.11'),
        "environment": os.environ.get('FLASK_ENV', 'production'),
        "cpu_usage": f"{psutil.cpu_percent()}%",
        "memory_usage": f"{psutil.virtual_memory().percent}%"
    }

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), mimetype='text/plain')

# ========== BEAUTIFUL PAGES ========== #

@app.route("/health-page")
def health_page():
    """Beautiful Health Check page"""
    current_time = time.time()
    health_data = {
        "service": "flask-devops-app",
        "status": "healthy",
        "timestamp": current_time,
        "version": "1.0.0",
        "uptime": format_uptime(current_time - psutil.boot_time()),
        "formatted_time": format_timestamp(current_time)
    }
    return render_template('health.html', health=health_data)

@app.route("/system-info-page")
def system_info_page():
    """Beautiful System Info page"""
    try:
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        system_data = {
            "hostname": platform.node(),
            "platform": f"{platform.system()} {platform.release()}",
            "cpu_cores": psutil.cpu_count(),
            "total_memory": round(memory.total / (1024**3), 2),
            "cpu_usage": f"{psutil.cpu_percent(interval=1)}%",
            "memory_usage": f"{memory.percent}%",
            "disk_usage": f"{disk.percent}%",
            "uptime": format_uptime(time.time() - psutil.boot_time())
        }
    except Exception as e:
        system_data = {
            "hostname": "Error",
            "platform": f"Error: {str(e)}",
            "cpu_cores": 0,
            "total_memory": 0,
            "cpu_usage": "0%",
            "memory_usage": "0%",
            "disk_usage": "0%",
            "uptime": "0m"
        }
    
    return render_template('system_info.html', system_data=system_data)

@app.route("/metrics-page")
def metrics_page():
    """Beautiful Metrics page"""
    try:
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        metrics_text = f"""# HELP python_info Python platform information
# TYPE python_info gauge
python_info{{version="{platform.python_version()}"}} 1

# HELP cpu_usage_total Total CPU usage percent
# TYPE cpu_usage_total gauge
cpu_usage_total {psutil.cpu_percent(interval=0.5)}

# HELP memory_usage_percent Memory usage percent
# TYPE memory_usage_percent gauge
memory_usage_percent {memory.percent}

# HELP memory_available_bytes Available memory in bytes
# TYPE memory_available_bytes gauge
memory_available_bytes {memory.available}

# HELP memory_total_bytes Total memory in bytes
# TYPE memory_total_bytes gauge
memory_total_bytes {memory.total}

# HELP disk_usage_percent Disk usage percent
# TYPE disk_usage_percent gauge
disk_usage_percent {disk.percent}

# HELP service_health Service health status
# TYPE service_health gauge
service_health 1

# HELP system_uptime_seconds System uptime in seconds  
# TYPE system_uptime_seconds gauge
system_uptime_seconds {time.time() - psutil.boot_time()}
"""
    except Exception as e:
        metrics_text = f"Error generating metrics: {str(e)}"
    
    return render_template('metrics.html', metrics_text=metrics_text)

# ========== API ENDPOINTS FOR DYNAMIC UPDATES ========== #

@app.route("/api/system-info")
def api_system_info():
    """API for system information (for dynamic updates)"""
    try:
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return jsonify({
            "hostname": platform.node(),
            "platform": f"{platform.system()} {platform.release()}",
            "cpu_cores": psutil.cpu_count(),
            "total_memory": round(memory.total / (1024**3), 2),
            "cpu_usage": f"{psutil.cpu_percent(interval=1)}%",
            "memory_usage": f"{memory.percent}%",
            "disk_usage": f"{disk.percent}%",
            "uptime": format_uptime(time.time() - psutil.boot_time()),
            "timestamp": format_timestamp(time.time())
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/metrics")
def api_metrics():
    """API for formatted metrics (for dynamic updates)"""
    try:
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        metrics_text = f"""# HELP python_info Python platform information
# TYPE python_info gauge
python_info{{version="{platform.python_version()}"}} 1

# HELP cpu_usage_total Total CPU usage percent
# TYPE cpu_usage_total gauge
cpu_usage_total {psutil.cpu_percent(interval=0.5)}

# HELP memory_usage_percent Memory usage percent
# TYPE memory_usage_percent gauge
memory_usage_percent {memory.percent}

# HELP memory_available_bytes Available memory in bytes
# TYPE memory_available_bytes gauge
memory_available_bytes {memory.available}

# HELP memory_total_bytes Total memory in bytes
# TYPE memory_total_bytes gauge
memory_total_bytes {memory.total}

# HELP disk_usage_percent Disk usage percent
# TYPE disk_usage_percent gauge
disk_usage_percent {disk.percent}

# HELP service_health Service health status
# TYPE service_health gauge
service_health 1

# HELP system_uptime_seconds System uptime in seconds  
# TYPE system_uptime_seconds gauge
system_uptime_seconds {time.time() - psutil.boot_time()}
"""
        return Response(metrics_text, mimetype='text/plain')
    except Exception as e:
        logger.error(f"Error in /api/metrics: {str(e)}")
        logger.error(traceback.format_exc())
        return Response(f"Error generating metrics: {str(e)}", mimetype='text/plain'), 500

# ========== ERROR HANDLERS ========== #

@app.errorhandler(404)
def not_found(error):
    """Handle 404 Not Found errors"""
    logger.warning(f"404 Not Found: {request.path}")
    return jsonify({
        "error": "Not found",
        "status_code": 404,
        "path": request.path,
        "message": "The requested resource was not found"
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 Internal Server errors"""
    logger.error(f"500 Internal Error: {request.path} - {str(error)}")
    logger.error(traceback.format_exc())
    return jsonify({
        "error": "Internal server error",
        "status_code": 500,
        "message": "An unexpected error occurred"
    }), 500

@app.errorhandler(Exception)
def handle_exception(e):
    """Handle all unhandled exceptions"""
    logger.error(f"Unhandled exception: {type(e).__name__} - {str(e)}")
    logger.error(traceback.format_exc())
    
    if request and request.path.startswith('/api'):
        return jsonify({
            "error": "An error occurred",
            "status_code": 500,
            "message": str(e) if app.debug else "Internal server error"
        }), 500
    
    return jsonify({
        "error": "Internal server error",
        "status_code": 500
    }), 500

if __name__ == "__main__":
    logger.info("Application started on 0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
