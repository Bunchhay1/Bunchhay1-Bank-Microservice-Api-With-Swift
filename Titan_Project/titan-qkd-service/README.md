# Titan QKD Service

> **Quantum Key Distribution - Post-quantum cryptography for future-proof secure communication**

Part of the **Titan Banking Platform** - Protecting against quantum computer attacks with CRYSTALS-Kyber.

## 🎯 Overview

Titan QKD Service simulates **post-quantum cryptography** using CRYSTALS-Kyber (NIST PQC finalist) for quantum-resistant key exchange. This protects inter-service communication from future quantum computer attacks that will break RSA and elliptic curve cryptography.

### Key Features

- ✅ **Quantum-Resistant**: Immune to Shor's algorithm
- ✅ **CRYSTALS-Kyber**: NIST post-quantum standard
- ✅ **Lattice-Based Crypto**: Hard problems for quantum computers
- ✅ **AES-256-GCM**: Symmetric encryption with authentication
- ✅ **Future-Proof**: Ready for quantum computing era

## ⚛️ The Quantum Threat

### Classical Cryptography (Vulnerable)

```
RSA-2048 / ECDH P-256
         ↓
Shor's Algorithm (Quantum Computer)
         ↓
❌ Broken in polynomial time
```

**Timeline**: Practical quantum computers by 2030-2035

### Post-Quantum Cryptography (Safe)

```
CRYSTALS-Kyber (Lattice-Based)
         ↓
Shor's Algorithm (Quantum Computer)
         ↓
✅ Still exponentially hard
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              QKD Service (Port 8097)                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │  CRYSTALS-Kyber Key Encapsulation                 │  │
│  │  • Generate quantum-resistant keypairs            │  │
│  │  │  Establish secure tunnels                      │  │
│  │  • Encrypt with AES-256-GCM                       │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │                            │
    ┌────▼────┐                  ┌───▼────┐
    │ Gateway │ ←─ Quantum ───→  │ Banking│
    │ Service │    Tunnel        │ Service│
    └─────────┘                  └────────┘
```

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- cryptography library

### Installation

```bash
# Install dependencies
pip install cryptography flask

# Test the engine
python qkd_engine.py
```

**Output:**
```
🔐 Generating Quantum-Resistant Keypair - titan-gateway
🧬 Algorithm: CRYSTALS-Kyber-512 (Simulated)
🛡️  Security Level: AES-128 equivalent
⚛️  Quantum Attack Resistance: YES

✅ Keypair generated in 0.05ms
📏 Public Key Size: 800 bytes
📏 Private Key Size: 1632 bytes

🌐 Establishing Quantum Tunnel: titan-gateway ↔ titan-core-banking
🔒 Encapsulating shared secret with Kyber KEM...
✅ Tunnel established (Quantum-Safe)

📤 Sending encrypted message...
🔓 Received and decrypted successfully
✅ Message Integrity: VERIFIED
```

### Start Service

```bash
python qkd_service.py
```

Service runs on `http://localhost:8097`

### Docker Deployment

```bash
# Build image
docker build -t titan-qkd-service .

# Run container
docker run -p 8097:8097 titan-qkd-service
```

## 📡 API Endpoints

### Generate Quantum-Resistant Keypair

```bash
POST /api/v1/qkd/generate-keypair
Content-Type: application/json

{
  "serviceName": "titan-gateway"
}
```

**Response:**
```json
{
  "serviceName": "titan-gateway",
  "publicKey": "8ad92d83f210ad15b5af863e5e29b7db...",
  "algorithm": "CRYSTALS-Kyber-512",
  "quantumResistant": true,
  "publicKeySize": 800,
  "privateKeySize": 1632
}
```

### Establish Quantum Tunnel

```bash
POST /api/v1/qkd/establish-tunnel
Content-Type: application/json

{
  "serviceName": "titan-gateway",
  "peerName": "titan-core-banking",
  "peerPublicKey": "f4cc49127b02195295251021b2922d40..."
}
```

**Response:**
```json
{
  "status": "ESTABLISHED",
  "tunnel": "titan-gateway ↔ titan-core-banking",
  "sharedSecret": "a1b2c3d4e5f6...",
  "ciphertextSize": 768,
  "quantumSafe": true
}
```

### Send Encrypted Message

```bash
POST /api/v1/qkd/send-message
Content-Type: application/json

{
  "serviceName": "titan-gateway",
  "peerName": "titan-core-banking",
  "message": {
    "from": "ACC001",
    "to": "ACC002",
    "amount": 50000,
    "currency": "USD"
  }
}
```

**Response:**
```json
{
  "status": "SENT",
  "encrypted": true,
  "ciphertext": "1259f45baef175650e80b05c4354ac9c...",
  "algorithm": "AES-256-GCM",
  "integrityVerified": true
}
```

## 🔬 Technical Details

### CRYSTALS-Kyber

**Algorithm**: Lattice-based key encapsulation mechanism (KEM)  
**Security**: Based on Module Learning With Errors (MLWE) problem  
**NIST Status**: Selected for standardization (2022)

**Key Sizes (Kyber-512):**
- Public Key: 800 bytes
- Private Key: 1632 bytes
- Ciphertext: 768 bytes
- Shared Secret: 32 bytes

**Performance:**
- Key Generation: ~0.05ms
- Encapsulation: ~0.03ms
- Decapsulation: ~0.04ms

### Why Lattice-Based Crypto?

**Hard Problem**: Finding short vectors in high-dimensional lattices  
**Quantum Resistance**: No known quantum algorithm solves this efficiently  
**Efficiency**: Faster than other post-quantum schemes (code-based, hash-based)

### Comparison: Classical vs Post-Quantum

| Feature | RSA-2048 | ECDH P-256 | Kyber-512 |
|---------|----------|------------|-----------|
| Public Key | 256 bytes | 32 bytes | 800 bytes |
| Quantum Safe | ❌ No | ❌ No | ✅ Yes |
| Key Gen Speed | Slow | Fast | Fast |
| Standardized | ✅ Yes | ✅ Yes | 🔄 In Progress |

## 🛡️ Security Analysis

### Quantum Attack Resistance

| Attack | Classical Crypto | Post-Quantum Crypto |
|--------|------------------|---------------------|
| **Shor's Algorithm** | ❌ Breaks RSA/ECC | ✅ Resistant |
| **Grover's Algorithm** | ⚠️ Weakens AES-128 | ✅ Resistant (AES-256) |
| **Man-in-the-Middle** | ✅ Protected | ✅ Protected |

### Timeline

- **2019**: Google claims quantum supremacy
- **2022**: NIST selects Kyber for standardization
- **2024**: Draft FIPS standards released
- **2030-2035**: Practical quantum computers expected
- **NOW**: Implement post-quantum crypto (harvest-now-decrypt-later attacks)

## 💡 Use Cases

### Banking & Finance

1. **Inter-Bank Communication**: Quantum-safe SWIFT messages
2. **Blockchain**: Post-quantum digital signatures
3. **Secure Channels**: API communication between microservices
4. **Long-Term Secrets**: Protect data with 30+ year secrecy requirements

### Government & Defense

- **Classified Communications**: Military-grade encryption
- **Critical Infrastructure**: Power grid, water systems
- **Diplomatic Cables**: Embassy communications
- **Nuclear Command**: Launch code transmission

## 📊 Performance Metrics

### Kyber-512 (Simulated)
- **Key Generation**: 0.05ms
- **Encapsulation**: 0.03ms
- **Decapsulation**: 0.04ms
- **Total Handshake**: ~0.12ms

### AES-256-GCM Encryption
- **Throughput**: ~500 MB/s
- **Latency**: < 1ms for typical messages
- **Overhead**: 16 bytes (authentication tag)

## 🛠️ Integration with Titan Platform

Integrates with:

- **titan-core-banking**: Quantum-safe inter-service communication
- **titan-transaction-service**: Secure transaction messaging
- **titan-mpc-service**: Quantum-resistant key distribution
- **titan-settlement-arbiter**: Blockchain with post-quantum signatures

## 📈 Roadmap

- [ ] Actual liboqs integration (real Kyber implementation)
- [ ] CRYSTALS-Dilithium (post-quantum signatures)
- [ ] Hybrid mode (classical + post-quantum)
- [ ] Hardware acceleration (AVX2/NEON)
- [ ] FIPS 203/204/205 compliance

## 🔗 Research References

- **CRYSTALS-Kyber**: Bos et al. (2018) - "CRYSTALS - Kyber: a CCA-secure module-lattice-based KEM"
- **NIST PQC**: NIST (2022) - "Post-Quantum Cryptography Standardization"
- **Quantum Threat**: Mosca (2018) - "Cybersecurity in an Era with Quantum Computers"
- **Libraries**: liboqs, PQClean, Bouncy Castle

## ⚠️ Important Note

This is a **simulation** demonstrating post-quantum concepts. Production systems should use:
- **liboqs** (Open Quantum Safe)
- **NIST PQC reference implementations**
- **Hardware security modules (HSM)** with PQC support

## 🤝 Contributing

Contributions welcome! Please submit a Pull Request.

## 📄 License

Part of the Titan Banking Platform.

## 🔗 Related Projects

- [Titan MPC Service](https://github.com/Bunchhay1/titan-mpc-service)
- [Titan FHE Service](https://github.com/Bunchhay1/titan-fhe-service)
- [Titan Core Banking](https://github.com/Bunchhay1/titan-core-banking)

---

**Future-proof cryptography for the quantum era** ⚛️
