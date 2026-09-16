import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import pandas as pd
import requests
import json
import time

FL_SERVER = "http://localhost:8098"

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

class FederatedBankClient:
    def __init__(self, bank_id):
        self.bank_id = bank_id
        self.model = FraudDetectionModel()
        self.private_data = None
        
    def register(self):
        """Register with consortium"""
        print(f"\n🏦 Registering {self.bank_id} with consortium...")
        response = requests.post(f"{FL_SERVER}/api/v1/fl/register", json={
            "bankId": self.bank_id
        })
        print(f"✅ {response.json()}")
    
    def load_private_data(self):
        """Load bank's private transaction data (NEVER shared)"""
        print(f"\n🔒 Loading private data for {self.bank_id}...")
        
        # Simulate private banking data (different for each bank)
        np.random.seed(hash(self.bank_id) % 2**32)
        
        # Each bank has different fraud patterns
        n_samples = np.random.randint(500, 1500)
        
        X = np.random.randn(n_samples, 5)
        y = (X[:, 0] + X[:, 1] > 1).astype(float)  # Simple fraud rule
        
        self.private_data = (
            torch.FloatTensor(X),
            torch.FloatTensor(y).reshape(-1, 1)
        )
        
        print(f"✅ Loaded {n_samples} private transactions (NEVER leaves {self.bank_id})")
    
    def download_global_model(self):
        """Download current global model from consortium"""
        print(f"\n⬇️  Downloading global model...")
        response = requests.get(f"{FL_SERVER}/api/v1/fl/get-model")
        data = response.json()
        
        # Load weights into local model
        state_dict = {}
        for key, value in data['modelWeights'].items():
            state_dict[key] = torch.tensor(value)
        
        self.model.load_state_dict(state_dict)
        print(f"✅ Global model downloaded (Round {data['round']})")
    
    def train_locally(self, epochs=5):
        """Train on private data (data NEVER leaves the bank)"""
        print(f"\n🏋️  Training locally on private data...")
        
        X, y = self.private_data
        optimizer = optim.Adam(self.model.parameters(), lr=0.01)
        criterion = nn.BCELoss()
        
        self.model.train()
        for epoch in range(epochs):
            optimizer.zero_grad()
            predictions = self.model(X)
            loss = criterion(predictions, y)
            loss.backward()
            optimizer.step()
            
            if (epoch + 1) % 2 == 0:
                accuracy = ((predictions > 0.5) == y).float().mean()
                print(f"   Epoch {epoch+1}/{epochs} | Loss: {loss.item():.4f} | Acc: {accuracy.item()*100:.1f}%")
        
        print(f"✅ Local training complete")
    
    def submit_weight_updates(self):
        """Submit ONLY weight updates (NOT raw data) to consortium"""
        print(f"\n⬆️  Submitting weight updates to consortium...")
        
        # Serialize model weights
        state_dict = self.model.state_dict()
        serialized = {}
        for key, tensor in state_dict.items():
            serialized[key] = tensor.cpu().numpy().tolist()
        
        response = requests.post(f"{FL_SERVER}/api/v1/fl/submit-update", json={
            "bankId": self.bank_id,
            "weightUpdates": serialized,
            "samplesTrained": len(self.private_data[0])
        })
        
        print(f"✅ {response.json()}")
    
    def federated_round(self):
        """Execute one round of federated learning"""
        print("=" * 80)
        print(f"🔄 FEDERATED LEARNING ROUND - {self.bank_id}")
        print("=" * 80)
        
        self.download_global_model()
        self.train_locally(epochs=5)
        self.submit_weight_updates()
        
        print("=" * 80)

# Demo: Simulate 3 banks
if __name__ == "__main__":
    print("=" * 80)
    print("🌐 FEDERATED LEARNING DEMO - Multi-Bank Simulation")
    print("=" * 80)
    
    # Wait for server to be ready
    print("\n⏳ Waiting for FL server to be ready...")
    time.sleep(2)
    
    # Create 3 banks
    banks = [
        FederatedBankClient("TITAN_BANK_CAMBODIA"),
        FederatedBankClient("ACLEDA_BANK"),
        FederatedBankClient("ABA_BANK")
    ]
    
    # Register all banks
    for bank in banks:
        bank.register()
        bank.load_private_data()
    
    # Run 3 federated learning rounds
    for round_num in range(1, 4):
        print(f"\n{'='*80}")
        print(f"🔄 GLOBAL ROUND {round_num}/3")
        print(f"{'='*80}")
        
        # Each bank trains locally and submits updates
        for bank in banks:
            bank.federated_round()
        
        # Server aggregates updates
        print(f"\n🌐 Consortium aggregating updates...")
        response = requests.post(f"{FL_SERVER}/api/v1/fl/aggregate")
        print(f"✅ {response.json()}")
    
    # Final stats
    print(f"\n{'='*80}")
    print("📊 FEDERATED LEARNING COMPLETE")
    print(f"{'='*80}")
    response = requests.get(f"{FL_SERVER}/api/v1/fl/stats")
    print(json.dumps(response.json(), indent=2))
    print(f"{'='*80}")
    print("🎯 All banks improved fraud detection WITHOUT sharing customer data!")
    print(f"{'='*80}")
