import torch
import torch.nn as nn
from flask import Flask, request, jsonify
import numpy as np
import json

app = Flask(__name__)

# Global model (shared across all banks)
class FraudDetectionModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.model = nn.Sequential(
            nn.Linear(5, 16),
            nn.ReLU(),
            nn.Linear(16, 8),
            nn.ReLU(),
            nn.Linear(8, 1),
            nn.Sigmoid()
        )
    
    def forward(self, x):
        return self.model(x)

# Initialize global model
global_model = FraudDetectionModel()
participating_banks = []
round_number = 0
weight_updates = []

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "federated-learning-server"})

@app.route('/api/v1/fl/register', methods=['POST'])
def register_bank():
    """Register a bank to participate in federated learning"""
    data = request.json
    bank_id = data['bankId']
    
    if bank_id not in participating_banks:
        participating_banks.append(bank_id)
    
    return jsonify({
        "bankId": bank_id,
        "status": "REGISTERED",
        "totalBanks": len(participating_banks)
    })

@app.route('/api/v1/fl/get-model', methods=['GET'])
def get_global_model():
    """Download current global model"""
    state_dict = global_model.state_dict()
    
    # Convert tensors to lists for JSON serialization
    serialized = {}
    for key, tensor in state_dict.items():
        serialized[key] = tensor.cpu().numpy().tolist()
    
    return jsonify({
        "round": round_number,
        "modelWeights": serialized,
        "participatingBanks": len(participating_banks)
    })

@app.route('/api/v1/fl/submit-update', methods=['POST'])
def submit_update():
    """Bank submits trained weight updates (NOT raw data)"""
    data = request.json
    bank_id = data['bankId']
    updates = data['weightUpdates']
    samples_trained = data['samplesTrained']
    
    weight_updates.append({
        "bankId": bank_id,
        "updates": updates,
        "samples": samples_trained
    })
    
    print(f"✅ Received update from {bank_id} ({samples_trained} samples)")
    
    return jsonify({
        "status": "ACCEPTED",
        "updatesReceived": len(weight_updates),
        "waitingFor": len(participating_banks) - len(weight_updates)
    })

@app.route('/api/v1/fl/aggregate', methods=['POST'])
def aggregate_updates():
    """Aggregate weight updates from all banks (Federated Averaging)"""
    global global_model, round_number, weight_updates
    
    if len(weight_updates) == 0:
        return jsonify({"error": "No updates to aggregate"}), 400
    
    print(f"\n🔄 Aggregating updates from {len(weight_updates)} banks...")
    
    # Federated Averaging (FedAvg)
    aggregated_weights = {}
    total_samples = sum(u['samples'] for u in weight_updates)
    
    # Get model structure
    state_dict = global_model.state_dict()
    
    for key in state_dict.keys():
        # Weighted average based on number of samples
        weighted_sum = None
        for update in weight_updates:
            weight = update['samples'] / total_samples
            update_tensor = torch.tensor(update['updates'][key])
            
            if weighted_sum is None:
                weighted_sum = weight * update_tensor
            else:
                weighted_sum += weight * update_tensor
        
        aggregated_weights[key] = weighted_sum
    
    # Update global model
    global_model.load_state_dict(aggregated_weights)
    round_number += 1
    
    print(f"✅ Global model updated (Round {round_number})")
    
    # Clear updates for next round
    weight_updates = []
    
    return jsonify({
        "round": round_number,
        "banksAggregated": len(participating_banks),
        "totalSamples": total_samples,
        "status": "AGGREGATED"
    })

@app.route('/api/v1/fl/stats', methods=['GET'])
def get_stats():
    """Get federated learning statistics"""
    return jsonify({
        "round": round_number,
        "participatingBanks": len(participating_banks),
        "pendingUpdates": len(weight_updates),
        "banks": participating_banks
    })

if __name__ == '__main__':
    print("=" * 80)
    print("🌐 FEDERATED LEARNING CONSORTIUM SERVER")
    print("=" * 80)
    print("📡 Starting on port 8098...")
    print("🏦 Waiting for banks to register...")
    print("=" * 80)
    app.run(host='0.0.0.0', port=8098, debug=False)
