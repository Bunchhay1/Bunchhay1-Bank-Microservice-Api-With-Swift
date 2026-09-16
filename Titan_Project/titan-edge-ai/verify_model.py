#!/usr/bin/env python3
import json
import pickle
import numpy as np

print("=" * 80)
print("TITAN EDGE AI - Model Verification")
print("=" * 80)

# Load model
with open('fraud_model.pkl', 'rb') as f:
    model = pickle.load(f)

# Load scaler
with open('scaler_params.json', 'r') as f:
    scaler_params = json.load(f)

# Load weights
with open('model_weights.json', 'r') as f:
    weights = json.load(f)

print(f"\n📊 Model Information:")
print(f"   Architecture: 3 -> 8 -> 4 -> 1")
print(f"   Input features: 3 (amount, typing_speed, trust_score)")
print(f"   Hidden layers: 2 (8 neurons, 4 neurons)")
print(f"   Output: 1 (fraud probability)")
print(f"   Activation: ReLU (hidden), Sigmoid (output)")

print(f"\n🔢 Model Parameters:")
layer1_params = len(weights['layer1_weights']) * len(weights['layer1_weights'][0]) + len(weights['layer1_bias'])
layer2_params = len(weights['layer2_weights']) * len(weights['layer2_weights'][0]) + len(weights['layer2_bias'])
layer3_params = len(weights['layer3_weights']) * len(weights['layer3_weights'][0]) + len(weights['layer3_bias'])
total_params = layer1_params + layer2_params + layer3_params
print(f"   Layer 1: {layer1_params} parameters (3x8 + 8 bias)")
print(f"   Layer 2: {layer2_params} parameters (8x4 + 4 bias)")
print(f"   Layer 3: {layer3_params} parameters (4x1 + 1 bias)")
print(f"   Total: {total_params} parameters")

print(f"\n📦 File Sizes:")
import os
print(f"   model_weights.json: {os.path.getsize('model_weights.json')} bytes")
print(f"   scaler_params.json: {os.path.getsize('scaler_params.json')} bytes")
print(f"   index.html: {os.path.getsize('index.html')} bytes")
print(f"   Total: {os.path.getsize('model_weights.json') + os.path.getsize('scaler_params.json') + os.path.getsize('index.html')} bytes")

print(f"\n🧪 Test Cases:")
test_cases = [
    ([100, 200, 0.9], "Legitimate transaction"),
    ([25000, 50, 0.2], "Fraudulent transaction"),
    ([500, 150, 0.8], "Normal transaction"),
    ([10000, 30, 0.3], "Suspicious transaction")
]

mean = np.array(scaler_params['mean'])
std = np.array(scaler_params['std'])

for features, description in test_cases:
    normalized = (np.array(features) - mean) / std
    risk = model.predict_proba([normalized])[0][1]
    status = "🚨 FRAUD" if risk > 0.5 else "✅ LEGIT"
    print(f"   {description}: {risk*100:.1f}% risk {status}")

print("\n" + "=" * 80)
print("✅ Model ready for edge deployment!")
print("=" * 80)
print(f"\n💡 Next steps:")
print(f"   1. Run: python3 serve.py")
print(f"   2. Open: http://localhost:8096/index.html")
print(f"   3. Test fraud detection in browser")
print("=" * 80)
