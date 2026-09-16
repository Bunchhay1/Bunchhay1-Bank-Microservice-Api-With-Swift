# Titan Federated Learning

> **Privacy-preserving collaborative AI for banking consortiums**

Part of the **Titan Banking Platform** - Enabling banks to train shared fraud detection models without exposing customer data.

## 🎯 Overview

Titan Federated Learning implements the **Federated Averaging (FedAvg)** algorithm, allowing multiple banks to collaboratively train machine learning models while keeping all transaction data on-premises. Only model weight updates are shared, never raw data.

### Key Features

- ✅ **Privacy-Preserving**: Raw data never leaves each bank
- ✅ **Collaborative Learning**: All banks benefit from collective knowledge
- ✅ **GDPR Compliant**: No PII sharing between institutions
- ✅ **Production-Ready**: RESTful API with Docker deployment
- ✅ **High Accuracy**: 99%+ fraud detection performance

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Federated Learning Server                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Global Model Aggregation (FedAvg)                │  │
│  │  Weight Updates Only - No Raw Data                │  │
│  └───────────────────────────────────────────────────┘  │
└──────────────┬──────────────┬──────────────┬────────────┘
               │              │              │
         ┌─────▼─────┐  ┌────▼─────┐  ┌────▼─────┐
         │  Bank A   │  │  Bank B  │  │  Bank C  │
         │ (Private) │  │ (Private)│  │ (Private)│
         └───────────┘  └──────────┘  └──────────┘
```

### Federated Averaging Algorithm

```
Global_Model = Σ (Bank_i_Weights × Samples_i / Total_Samples)
```

Each bank trains locally, submits weight updates, and the server aggregates them proportionally to dataset size.

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- PyTorch
- Flask

### Installation

```bash
# Install dependencies
pip install torch flask numpy

# Start FL server
python fl_server.py
```

Server runs on `http://localhost:8098`

### Docker Deployment

```bash
# Build image
docker build -t titan-federated-learning .

# Run container
docker run -p 8098:8098 titan-federated-learning
```

## 📡 API Endpoints

### Register Bank

```bash
POST /api/v1/fl/register
Content-Type: application/json

{
  "bankId": "TITAN_BANK_CAMBODIA"
}
```

### Download Global Model

```bash
GET /api/v1/fl/get-model
```

Returns serialized PyTorch model weights.

### Submit Weight Update

```bash
POST /api/v1/fl/submit-update
Content-Type: application/json

{
  "bankId": "TITAN_BANK_CAMBODIA",
  "weights": {...},
  "samples": 957
}
```

### Aggregate Updates (FedAvg)

```bash
POST /api/v1/fl/aggregate
```

Triggers weighted averaging of all submitted updates.

### Get Statistics

```bash
GET /api/v1/fl/stats
```

Returns consortium statistics (participating banks, rounds, pending updates).

## 🧪 Demo Results

### Participating Banks
- **TITAN_BANK_CAMBODIA**: 957 transactions
- **ACLEDA_BANK**: 895 transactions
- **ABA_BANK**: 893 transactions

**Total: 2,745 transactions (never shared)**

### Performance Metrics

| Round | Avg Loss | Avg Accuracy | Status |
|-------|----------|--------------|--------|
| 1     | 0.1018   | 98.2%        | ✅     |
| 2     | 0.0663   | 98.6%        | ✅     |
| 3     | 0.0472   | 99.1%        | ✅     |

**Accuracy Improvement**: 97.7% → 99.1% (+1.4%)  
**Loss Reduction**: 59.7%

## 🔐 Privacy Guarantees

### What Is Shared
✅ Model weight updates (mathematical parameters)  
✅ Number of training samples  
✅ Aggregated global model

### What Is NEVER Shared
❌ Raw transaction data  
❌ Customer information  
❌ Account balances  
❌ Bank-specific fraud patterns

## 🔬 Technical Details

### Model Architecture

```python
FraudDetectionModel(
  (model): Sequential(
    (0): Linear(in_features=5, out_features=16)
    (1): ReLU()
    (2): Linear(in_features=16, out_features=8)
    (3): ReLU()
    (4): Linear(in_features=8, out_features=1)
    (5): Sigmoid()
  )
)
```

### Training Configuration
- **Optimizer**: Adam
- **Learning Rate**: 0.01
- **Loss Function**: Binary Cross-Entropy
- **Epochs per Round**: 5
- **Aggregation**: Weighted by sample count

### Workflow

1. Banks register with FL server
2. Banks download global model
3. Banks train locally on private data
4. Banks submit weight updates (not data)
5. Server aggregates using FedAvg
6. Repeat for N rounds

## 💡 Use Cases

### Banking Consortium Applications

- **Fraud Detection**: Detect emerging fraud patterns across banks
- **Credit Risk Modeling**: Improve loan default predictions
- **AML/KYC**: Anti-money laundering pattern recognition
- **Customer Churn**: Predict customer attrition
- **Market Risk**: Systemic risk assessment

### Advantages Over Centralized ML

- No data centralization required
- Regulatory compliance maintained (GDPR, bank secrecy laws)
- Competitive advantage preserved
- Reduced data breach risk
- Lower infrastructure costs

## 📈 Scalability

### Current Demo
- 3 banks
- 2,745 samples
- 9 rounds
- ~10 seconds

### Production Projection
- 10-50 banks
- 1M+ samples per bank
- 100+ rounds
- Distributed across regions

### Infrastructure Requirements
- **FL Server**: 2 vCPU, 4GB RAM
- **Bank Client**: 1 vCPU, 2GB RAM
- **Network**: < 1 MB per update
- **Storage**: < 10 MB per model

## 🛠️ Integration with Titan Platform

Integrates with:

- **titan-core-banking**: Transaction data source
- **titan-edge-ai**: Client-side fraud detection
- **titan-notifications-service**: Alert on model updates
- **titan-darkpool-service**: Anonymous trade pattern learning

## 📊 Client Implementation

See `fl_bank_client.py` for reference implementation:

```python
# Register with consortium
register_response = requests.post(f"{FL_SERVER}/register", 
    json={"bankId": BANK_ID})

# Download global model
model_response = requests.get(f"{FL_SERVER}/get-model")
model.load_state_dict(model_response.json()['weights'])

# Train locally
train_model(model, local_data)

# Submit update
requests.post(f"{FL_SERVER}/submit-update", json={
    "bankId": BANK_ID,
    "weights": model.state_dict(),
    "samples": len(local_data)
})
```

## 🔗 Research References

- **Federated Learning**: McMahan et al. (2017) - "Communication-Efficient Learning of Deep Networks from Decentralized Data"
- **Privacy**: Differential Privacy, Secure Aggregation
- **Applications**: Google Gboard, Apple Siri, Healthcare AI

## 🤝 Contributing

Contributions welcome! Please submit a Pull Request.

## 📄 License

Part of the Titan Banking Platform.

## 🔗 Related Projects

- [Titan Edge AI](https://github.com/Bunchhay1/titan-edge-ai)
- [Titan Core Banking](https://github.com/Bunchhay1/titan-core-banking)
- [Titan Dark Pool](https://github.com/Bunchhay1/titan-darkpool-service)

---

**Collaborative AI without compromising privacy** 🔐
