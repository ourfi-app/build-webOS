#!/usr/bin/env python3
"""
webOS Build Dashboard - Web interface for managing webOS OSE builds
"""

import os
import subprocess
import json
from pathlib import Path
from datetime import datetime
from flask import Flask, render_template, jsonify, request, send_from_directory
from flask_cors import CORS
import markdown2
import psutil

app = Flask(__name__)
CORS(app)

# Configuration
BASE_DIR = Path(__file__).parent
BUILD_DIR = BASE_DIR / "BUILD"
DOCS_DIR = BASE_DIR / "docs"
SCRIPTS_DIR = BASE_DIR / "scripts"

# Supported machines
MACHINES = ['qemux86', 'qemux86-64', 'qemuarm',
            'raspberrypi3', 'raspberrypi3-64',
            'raspberrypi4', 'raspberrypi4-64']

IMAGES = ['webos-image']


def run_command(cmd, cwd=None):
    """Execute a shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd or BASE_DIR,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Command timed out',
            'returncode': -1
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }


def get_git_info():
    """Get current git branch and commit info"""
    branch_result = run_command('git rev-parse --abbrev-ref HEAD')
    commit_result = run_command('git rev-parse --short HEAD')
    status_result = run_command('git status --short')

    return {
        'branch': branch_result['stdout'].strip() if branch_result['success'] else 'unknown',
        'commit': commit_result['stdout'].strip() if commit_result['success'] else 'unknown',
        'dirty': bool(status_result['stdout'].strip()) if status_result['success'] else False,
        'status': status_result['stdout'].strip() if status_result['success'] else ''
    }


def get_system_info():
    """Get system resource information"""
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    return {
        'cpu': {
            'percent': cpu_percent,
            'count': psutil.cpu_count(),
            'count_logical': psutil.cpu_count(logical=True)
        },
        'memory': {
            'total': memory.total,
            'available': memory.available,
            'percent': memory.percent,
            'used': memory.used,
            'free': memory.free
        },
        'disk': {
            'total': disk.total,
            'used': disk.used,
            'free': disk.free,
            'percent': disk.percent
        }
    }


def get_build_status():
    """Get build status and information"""
    status = {
        'configured': False,
        'machine': None,
        'builds': [],
        'last_build': None
    }

    # Check if build environment is configured
    oe_init = BASE_DIR / "oe-init-build-env"
    if oe_init.exists():
        status['configured'] = True

        # Try to read machine from local.conf
        local_conf = BASE_DIR / "conf" / "local.conf"
        if local_conf.exists():
            try:
                with open(local_conf, 'r') as f:
                    for line in f:
                        if line.strip().startswith('MACHINE'):
                            # Extract machine name
                            parts = line.split('=')
                            if len(parts) > 1:
                                machine = parts[1].strip().strip('"').strip("'")
                                status['machine'] = machine
                                break
            except Exception:
                pass

    # Check for built images
    if BUILD_DIR.exists():
        deploy_dir = BUILD_DIR / "deploy" / "images"
        if deploy_dir.exists():
            for machine_dir in deploy_dir.iterdir():
                if machine_dir.is_dir():
                    images = list(machine_dir.glob("*.wic"))
                    for img in images:
                        stat = img.stat()
                        status['builds'].append({
                            'machine': machine_dir.name,
                            'image': img.name,
                            'size': stat.st_size,
                            'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
                        })

            # Sort by modification time and get most recent
            if status['builds']:
                status['builds'].sort(key=lambda x: x['modified'], reverse=True)
                status['last_build'] = status['builds'][0]

    return status


def get_qemu_processes():
    """Get running QEMU processes"""
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'create_time']):
        try:
            if 'qemu' in proc.info['name'].lower():
                processes.append({
                    'pid': proc.info['pid'],
                    'name': proc.info['name'],
                    'cmdline': ' '.join(proc.info['cmdline']) if proc.info['cmdline'] else '',
                    'started': datetime.fromtimestamp(proc.info['create_time']).isoformat()
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return processes


# ============================================================================
# Web Routes
# ============================================================================

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')


@app.route('/docs')
def docs():
    """Documentation viewer"""
    doc_file = request.args.get('file', 'RENDER_ENVIRONMENT.md')
    return render_template('docs.html', doc_file=doc_file)


@app.route('/build')
def build_page():
    """Build management page"""
    return render_template('build.html', machines=MACHINES, images=IMAGES)


@app.route('/qemu')
def qemu_page():
    """QEMU management page"""
    return render_template('qemu.html', machines=MACHINES)


# ============================================================================
# API Endpoints
# ============================================================================

@app.route('/api/status')
def api_status():
    """Get overall system status"""
    return jsonify({
        'git': get_git_info(),
        'system': get_system_info(),
        'build': get_build_status(),
        'qemu': get_qemu_processes(),
        'timestamp': datetime.now().isoformat()
    })


@app.route('/api/git')
def api_git():
    """Get git repository information"""
    return jsonify(get_git_info())


@app.route('/api/system')
def api_system():
    """Get system resource information"""
    return jsonify(get_system_info())


@app.route('/api/build/status')
def api_build_status():
    """Get build status"""
    return jsonify(get_build_status())


@app.route('/api/build/machines')
def api_machines():
    """Get supported machines"""
    return jsonify({
        'machines': MACHINES,
        'images': IMAGES
    })


@app.route('/api/qemu/list')
def api_qemu_list():
    """List running QEMU processes"""
    return jsonify({
        'processes': get_qemu_processes(),
        'count': len(get_qemu_processes())
    })


@app.route('/api/docs/<path:filename>')
def api_docs(filename):
    """Get documentation content (rendered as HTML)"""
    doc_path = DOCS_DIR / filename
    if not doc_path.exists():
        return jsonify({'error': 'Documentation file not found'}), 404

    try:
        with open(doc_path, 'r') as f:
            content = f.read()

        # Convert markdown to HTML
        if filename.endswith('.md'):
            html_content = markdown2.markdown(
                content,
                extras=['fenced-code-blocks', 'tables', 'header-ids']
            )
            return jsonify({
                'filename': filename,
                'content': html_content,
                'format': 'html'
            })
        else:
            return jsonify({
                'filename': filename,
                'content': content,
                'format': 'text'
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/scripts')
def api_scripts():
    """List available scripts"""
    scripts = []
    if SCRIPTS_DIR.exists():
        for script in SCRIPTS_DIR.glob('*.sh'):
            stat = script.stat()
            scripts.append({
                'name': script.name,
                'path': str(script.relative_to(BASE_DIR)),
                'executable': os.access(script, os.X_OK),
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
    return jsonify({'scripts': scripts})


@app.route('/api/layers')
def api_layers():
    """Get webOS layers information"""
    layers = []
    weboslayers_file = BASE_DIR / "weboslayers.py"

    if weboslayers_file.exists():
        try:
            # Read and parse the weboslayers.py file
            with open(weboslayers_file, 'r') as f:
                content = f.read()
                # This is a simple parser - in production you'd want something more robust
                if 'Layers = [' in content:
                    return jsonify({
                        'file': 'weboslayers.py',
                        'available': True,
                        'message': 'Layer information available in weboslayers.py'
                    })
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    return jsonify({
        'file': 'weboslayers.py',
        'available': weboslayers_file.exists(),
        'layers': layers
    })


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })


# ============================================================================
# Static Files
# ============================================================================

@app.route('/favicon.ico')
def favicon():
    """Serve favicon"""
    return '', 204


# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    if request.path.startswith('/api/'):
        return jsonify({'error': 'Not found'}), 404
    return render_template('404.html'), 404


@app.errorhandler(500)
def server_error(e):
    """Handle 500 errors"""
    if request.path.startswith('/api/'):
        return jsonify({'error': 'Internal server error'}), 500
    return render_template('500.html'), 500


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

    print(f"""
    ╔═══════════════════════════════════════════╗
    ║   webOS Build Dashboard                   ║
    ║   http://localhost:{port}                    ║
    ╚═══════════════════════════════════════════╝
    """)

    app.run(host='0.0.0.0', port=port, debug=debug)
