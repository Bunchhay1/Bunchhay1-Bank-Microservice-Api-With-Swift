SELECT 'CREATE DATABASE promotiondb OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promotiondb')\gexec

\c promotiondb
CREATE EXTENSION IF NOT EXISTS postgis;
