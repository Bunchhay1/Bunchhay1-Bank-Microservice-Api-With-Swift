# Titan Banking - Kafka SSL/TLS Certificates

**Generated:** Fri Feb 13 03:28:51 +07 2026
**Validity:** 3650 days (~10 years)
**Password:** titan123

## Files Generated

### Certificate Authority (CA)
- `titan-ca.jks` - CA keystore (contains private key)
- `titan-ca.crt` - CA public certificate

### Kafka Broker
- `kafka.server.keystore.jks` - Broker private key and certificate
- `kafka.server.truststore.jks` - Broker truststore (contains CA cert)

### Clients
- `core-banking.keystore.jks` - Core Banking service keystore
- `promotions.keystore.jks` - Promotions service keystore
- `notifications.keystore.jks` - Notifications service keystore
- `kafka.client.truststore.jks` - Client truststore (shared)

### Credentials
- `kafka_keystore_credentials` - Keystore password
- `kafka_key_credentials` - Key password
- `kafka_truststore_credentials` - Truststore password

## Security Configuration

- **Protocol:** TLS v1.3
- **Key Algorithm:** RSA
- **Key Size:** 4096 bits
- **Cipher Strength:** High (Bank Grade)
- **Authentication:** Mutual TLS (mTLS)

## Usage

### Kafka Broker Configuration
```yaml
KAFKA_SSL_KEYSTORE_FILENAME: kafka.server.keystore.jks
KAFKA_SSL_KEYSTORE_CREDENTIALS: kafka_keystore_credentials
KAFKA_SSL_KEY_CREDENTIALS: kafka_key_credentials
KAFKA_SSL_TRUSTSTORE_FILENAME: kafka.server.truststore.jks
KAFKA_SSL_TRUSTSTORE_CREDENTIALS: kafka_truststore_credentials
KAFKA_SSL_CLIENT_AUTH: required
```

### Spring Boot Client Configuration
```properties
spring.kafka.security.protocol=SSL
spring.kafka.ssl.trust-store-location=file:/path/to/kafka.client.truststore.jks
spring.kafka.ssl.trust-store-password=titan123
spring.kafka.ssl.key-store-location=file:/path/to/core-banking.keystore.jks
spring.kafka.ssl.key-store-password=titan123
spring.kafka.ssl.key-password=titan123
```

## Verification

Test SSL connection:
```bash
openssl s_client -connect localhost:9093 -CAfile titan-ca.crt
```

## Certificate Expiry

Certificates expire on: 2036-02-11

Renew certificates before expiry by running `generate-ssl.sh` again.

## Security Notes

⚠️ **IMPORTANT:**
- Keep `titan-ca.jks` secure (contains CA private key)
- Keep all `.jks` files secure (contain private keys)
- In production, use a proper secrets management system
- Change the default password in production
- Add `secrets/` to `.gitignore`
