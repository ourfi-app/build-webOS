# webOS Build Dashboard

A web-based dashboard for managing and monitoring webOS OSE (Open Source Edition) builds.

## Overview

The webOS Build Dashboard provides a user-friendly web interface to:
- Monitor system status and build progress
- View documentation
- Manage build configurations
- Control QEMU instances
- Access build information via REST API

## Features

### 📊 Dashboard
- Real-time system resource monitoring (CPU, Memory, Disk)
- Git repository status
- Build status and history
- Running QEMU processes
- Recent builds overview

### 📚 Documentation Viewer
- Browse and read project documentation
- Markdown rendering
- Quick navigation between docs

### 🔨 Build Management
- View supported machines and images
- Display built images
- List available build scripts
- Copy build commands

### 💻 QEMU Management
- Configure QEMU launch options
- Generate run commands
- Monitor running QEMU processes
- Support for different display backends

### 🔌 REST API
Complete REST API for programmatic access to all dashboard features.

## Quick Start

### Local Development

1. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Run the Application**
   ```bash
   python app.py
   ```

3. **Access the Dashboard**
   Open your browser to: http://localhost:5000

### Production Deployment on Render

1. **Configure Render**
   - The `render.yaml` file is already configured
   - Render will automatically detect and deploy

2. **Deploy**
   - Connect your GitHub repository to Render
   - Render will build and deploy automatically
   - Access via your Render URL

## API Endpoints

### Status Endpoints

#### `GET /api/status`
Get overall system status including git, system resources, build status, and QEMU processes.

**Response:**
```json
{
  "git": {
    "branch": "master",
    "commit": "abc1234",
    "dirty": false
  },
  "system": {
    "cpu": {"percent": 25.5, "count": 4},
    "memory": {"percent": 45.2, "total": 16000000000},
    "disk": {"percent": 60.1, "free": 50000000000}
  },
  "build": {
    "configured": true,
    "machine": "qemux86-64",
    "builds": [...]
  },
  "qemu": [...],
  "timestamp": "2025-11-07T22:00:00"
}
```

#### `GET /api/git`
Get git repository information.

#### `GET /api/system`
Get system resource information.

#### `GET /api/build/status`
Get build status and list of built images.

#### `GET /api/build/machines`
Get list of supported machines and images.

**Response:**
```json
{
  "machines": ["qemux86", "qemux86-64", "qemuarm", ...],
  "images": ["webos-image"]
}
```

#### `GET /api/qemu/list`
List running QEMU processes.

**Response:**
```json
{
  "processes": [
    {
      "pid": 12345,
      "name": "qemu-system-x86_64",
      "started": "2025-11-07T21:00:00"
    }
  ],
  "count": 1
}
```

#### `GET /api/docs/<filename>`
Get documentation content (rendered as HTML for markdown files).

**Example:** `/api/docs/RENDER_ENVIRONMENT.md`

#### `GET /api/scripts`
List available build scripts.

#### `GET /api/layers`
Get webOS layers information.

#### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-07T22:00:00",
  "version": "1.0.0"
}
```

## Project Structure

```
build-webOS/
├── app.py                    # Main Flask application
├── requirements.txt          # Python dependencies
├── render.yaml              # Render deployment configuration
├── templates/               # HTML templates
│   ├── base.html           # Base template
│   ├── index.html          # Dashboard page
│   ├── docs.html           # Documentation viewer
│   ├── build.html          # Build management
│   ├── qemu.html           # QEMU management
│   ├── 404.html            # 404 error page
│   └── 500.html            # 500 error page
├── static/                  # Static files
│   ├── css/
│   │   └── styles.css      # Dashboard styles
│   └── js/
│       └── main.js         # Dashboard JavaScript
└── docs/                    # Documentation
    └── RENDER_ENVIRONMENT.md
```

## Configuration

### Environment Variables

- `PORT` - Server port (default: 5000)
- `FLASK_ENV` - Flask environment (development/production)
- `FLASK_DEBUG` - Enable Flask debug mode (True/False)

### Development Mode

```bash
export FLASK_DEBUG=True
python app.py
```

### Production Mode

```bash
gunicorn --bind 0.0.0.0:8000 app:app
```

## Technologies Used

- **Backend:** Flask (Python)
- **Frontend:** HTML5, CSS3, JavaScript
- **API:** RESTful JSON API
- **Markdown:** markdown2 for documentation rendering
- **System Info:** psutil for system monitoring
- **WSGI Server:** Gunicorn (production)

## Features in Detail

### Real-Time Monitoring

The dashboard automatically refreshes system information every 10 seconds:
- CPU usage percentage
- Memory usage and availability
- Disk space usage
- Git repository status
- Running QEMU processes

### Build Information

View detailed information about:
- Configured machine and build settings
- List of built images with sizes and dates
- Build history
- Available build scripts

### QEMU Configuration

Interactive QEMU configuration with:
- Machine selection
- Display backend options (SDL, GTK, VNC)
- VirtIO GPU toggle
- KVM acceleration toggle
- Command generation and copy

### Documentation Browser

Read project documentation directly in the web interface:
- Markdown rendering with syntax highlighting
- Code blocks with proper formatting
- Tables and lists
- Internal navigation

## API Usage Examples

### Python

```python
import requests

# Get system status
response = requests.get('http://localhost:5000/api/status')
data = response.json()
print(f"CPU Usage: {data['system']['cpu']['percent']}%")

# Get build status
response = requests.get('http://localhost:5000/api/build/status')
builds = response.json()
print(f"Last build: {builds['last_build']}")
```

### cURL

```bash
# Get system status
curl http://localhost:5000/api/status | jq

# Get QEMU processes
curl http://localhost:5000/api/qemu/list | jq

# Get documentation
curl http://localhost:5000/api/docs/RENDER_ENVIRONMENT.md | jq -r '.content'
```

### JavaScript

```javascript
// Fetch system status
fetch('/api/status')
  .then(response => response.json())
  .then(data => {
    console.log('CPU:', data.system.cpu.percent + '%');
    console.log('Memory:', data.system.memory.percent + '%');
  });

// Get build status
fetch('/api/build/status')
  .then(response => response.json())
  .then(data => {
    console.log('Builds:', data.builds);
  });
```

## Security Considerations

- This dashboard is intended for development and internal use
- Do not expose to public internet without proper authentication
- Consider adding authentication middleware for production use
- CORS is enabled - restrict origins in production

## Troubleshooting

### Port Already in Use

If port 5000 is already in use:
```bash
PORT=8080 python app.py
```

### Permission Errors

If you get permission errors accessing system info:
```bash
# On Linux, add user to necessary groups
sudo usermod -aG kvm $USER
```

### Module Not Found

If you get import errors:
```bash
pip install -r requirements.txt
```

## Development

### Adding New Features

1. Add routes in `app.py`
2. Create templates in `templates/`
3. Add styles in `static/css/styles.css`
4. Add JavaScript in `static/js/main.js`

### Testing

```bash
# Run the application
python app.py

# Test API endpoints
curl http://localhost:5000/health
curl http://localhost:5000/api/status
```

## Contributing

This dashboard is part of the webOS OSE build system. For contributions:
1. Follow the existing code style
2. Test all changes locally
3. Update documentation as needed
4. Submit pull requests

## Support

For issues and questions:
- Check the [webOS OSE Documentation](https://www.webosose.org/docs/)
- Visit the [webOS OSE Forums](https://forum.webosose.org/)
- Review the build system README

## License

This project follows the webOS OSE licensing. See the main repository for details.

## Version History

- **1.0.0** (2025-11-07)
  - Initial release
  - Dashboard with system monitoring
  - Build management interface
  - QEMU configuration and monitoring
  - Documentation viewer
  - Complete REST API
