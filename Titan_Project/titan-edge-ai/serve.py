#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        return super().end_headers()

if __name__ == '__main__':
    # Use /app when running in Docker (Render), fall back to script directory locally
    base_dir = '/app' if os.path.exists('/app/index.html') else os.path.dirname(os.path.abspath(__file__))
    os.chdir(base_dir)
    port = int(os.environ.get('PORT', 8001))
    server = HTTPServer(('0.0.0.0', port), CORSRequestHandler)
    print('=' * 80)
    print('🚀 Titan Edge AI Server Running')
    print('=' * 80)
    print(f'\n📡 Server: http://localhost:8096')
    print(f'🌐 Open in browser: http://localhost:8096/index.html')
    print(f'\n✅ Model files loaded:')
    print(f'   - model_weights.json')
    print(f'   - scaler_params.json')
    print(f'   - index.html')
    print(f'\nPress Ctrl+C to stop\n')
    server.serve_forever()
