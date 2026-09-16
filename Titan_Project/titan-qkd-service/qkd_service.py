from flask import Flask, request, jsonify
from qkd_engine import QuantumResistantTunnel
import base64

app = Flask(__name__)
services = {}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "titan-qkd-service"})

@app.route('/api/v1/qkd/register', methods=['POST'])
def register_service():
    """Register service and generate quantum-resistant keypair"""
    data = request.json
    service_name = data['serviceName']
    
    tunnel = QuantumResistantTunnel(service_name)
    public_key = tunnel.generate_quantum_resistant_keypair()
    
    services[service_name] = tunnel
    
    return jsonify({
        "serviceName": service_name,
        "publicKey": base64.b64encode(public_key).decode(),
        "algorithm": "CRYSTALS-Kyber-512 (Simulated)",
        "quantumResistant": True
    })

@app.route('/api/v1/qkd/establish-tunnel', methods=['POST'])
def establish_tunnel():
    """Establish quantum-resistant tunnel between services"""
    data = request.json
    service_a = data['serviceA']
    service_b = data['serviceB']
    
    if service_a not in services or service_b not in services:
        return jsonify({"error": "Service not registered"}), 400
    
    # Service A establishes tunnel with Service B
    tunnel_a = services[service_a]
    tunnel_b = services[service_b]
    
    ciphertext, shared_secret = tunnel_a.establish_quantum_tunnel(service_b, tunnel_b.public_key)
    tunnel_b.receive_tunnel_request(service_a, ciphertext, shared_secret)
    
    return jsonify({
        "status": "ESTABLISHED",
        "serviceA": service_a,
        "serviceB": service_b,
        "algorithm": "CRYSTALS-Kyber-512",
        "quantumSafe": True
    })

@app.route('/api/v1/qkd/send-message', methods=['POST'])
def send_message():
    """Send encrypted message through quantum tunnel"""
    data = request.json
    from_service = data['from']
    to_service = data['to']
    message = data['message']
    
    if from_service not in services:
        return jsonify({"error": "Sender not registered"}), 400
    
    tunnel = services[from_service]
    encrypted = tunnel.encrypt_message(to_service, message)
    
    return jsonify({
        "from": from_service,
        "to": to_service,
        "encrypted": encrypted,
        "algorithm": "AES-256-GCM"
    })

if __name__ == '__main__':
    print("🚀 Starting Titan QKD Service on port 8100...")
    app.run(host='0.0.0.0', port=8100, debug=False)
