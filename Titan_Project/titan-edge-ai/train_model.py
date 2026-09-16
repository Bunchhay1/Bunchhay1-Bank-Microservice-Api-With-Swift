import numpy as np
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import pickle
import json

print("=" * 80)
print("TITAN EDGE AI - Fraud Detection Model Training")
print("=" * 80)

# Generate synthetic training data
# Features: [transaction_amount, typing_speed_ms, device_trust_score]
np.random.seed(42)

# Legitimate transactions
legit_data = np.column_stack([
    np.random.uniform(10, 5000, 5000),      # Normal amounts
    np.random.uniform(100, 300, 5000),      # Normal typing speed
    np.random.uniform(0.7, 1.0, 5000)       # High trust score
])
legit_labels = np.zeros(5000)

# Fraudulent transactions
fraud_data = np.column_stack([
    np.random.uniform(5000, 50000, 1000),   # Unusually high amounts
    np.random.uniform(10, 80, 1000),        # Very fast typing (bot)
    np.random.uniform(0.0, 0.4, 1000)       # Low trust score
])
fraud_labels = np.ones(1000)

# Combine datasets
X = np.vstack([legit_data, fraud_data])
y = np.hstack([legit_labels, fraud_labels])

# Normalize features
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Split data
X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

print(f"\n📊 Dataset:")
print(f"   Training samples: {len(X_train)}")
print(f"   Test samples: {len(X_test)}")
print(f"   Fraud rate: {y.mean()*100:.1f}%")

# Build lightweight neural network
print(f"\n🧠 Building neural network...")
model = MLPClassifier(
    hidden_layer_sizes=(8, 4),
    activation='relu',
    solver='adam',
    max_iter=100,
    random_state=42
)

print(f"\n🏋️ Training model...")
model.fit(X_train, y_train)

# Evaluate
print(f"\n📈 Evaluating model...")
train_acc = model.score(X_train, y_train)
test_acc = model.score(X_test, y_test)
print(f"   Training Accuracy: {train_acc*100:.2f}%")
print(f"   Test Accuracy: {test_acc*100:.2f}%")

# Save model
print(f"\n💾 Saving model...")
with open('fraud_model.pkl', 'wb') as f:
    pickle.dump(model, f)
print(f"   ✅ Saved to fraud_model.pkl")

# Save scaler parameters for JavaScript
scaler_params = {
    'mean': scaler.mean_.tolist(),
    'std': scaler.scale_.tolist()
}
with open('scaler_params.json', 'w') as f:
    json.dump(scaler_params, f)
print(f"   ✅ Saved scaler parameters")

# Export model weights for JavaScript
weights = {
    'layer1_weights': model.coefs_[0].tolist(),
    'layer1_bias': model.intercepts_[0].tolist(),
    'layer2_weights': model.coefs_[1].tolist(),
    'layer2_bias': model.intercepts_[1].tolist(),
    'layer3_weights': model.coefs_[2].tolist(),
    'layer3_bias': model.intercepts_[2].tolist()
}
with open('model_weights.json', 'w') as f:
    json.dump(weights, f)
print(f"   ✅ Exported weights to JSON")

# Test prediction
print(f"\n🧪 Testing predictions:")
test_cases = [
    [100, 200, 0.9],    # Legit: small amount, normal typing, high trust
    [25000, 50, 0.2]    # Fraud: large amount, fast typing, low trust
]

for i, case in enumerate(test_cases):
    normalized = scaler.transform([case])
    risk = model.predict_proba(normalized)[0][1]
    print(f"   Case {i+1}: Risk Score = {risk:.3f} ({'🚨 FRAUD' if risk > 0.5 else '✅ LEGIT'})")

print("\n" + "=" * 80)
print("✅ Model training complete!")
print("=" * 80)
