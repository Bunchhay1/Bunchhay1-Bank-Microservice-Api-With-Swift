import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';

// Custom metrics to monitor Java processing performance
const transactionLatency = new Trend('transaction_processing_latency');
const loanLatency = new Trend('loan_processing_latency');
const gatewayLatency = new Trend('gateway_roundtrip_latency');
const successRate = new Rate('request_success_rate');

// k6 Options: Simulates 10 virtual users performing continuous operations for 30s
export const options = {
  stages: [
    { duration: '5s', target: 5 },  // Ramp-up to 5 users
    { duration: '20s', target: 10 }, // Ramp-up to 10 users and sustain
    { duration: '5s', target: 0 },  // Ramp-down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'], // 95% of requests must complete under 200ms
    request_success_rate: ['rate>0.99'], // Success rate must be greater than 99%
  },
};

const BASE_URL = 'http://localhost:8088'; // Go Gateway (proxies to Core Banking & Loans)

// Setup: Executed once. Registers test users and creates their primary banking accounts.
export function setup() {
  const headers = { 'Content-Type': 'application/json' };
  const randomSuffix = Math.floor(Math.random() * 1000000);

  // 1. Register User A
  const usernameA = `testuser_a_${randomSuffix}`;
  const regResA = http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({
      firstName: 'Alice',
      lastName: 'Smith',
      username: usernameA,
      email: `${usernameA}@titan.com`,
      password: 'password123',
      pin: '1234'
    }),
    { headers }
  );
  
  // 2. Register User B
  const usernameB = `testuser_b_${randomSuffix}`;
  const regResB = http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({
      firstName: 'Bob',
      lastName: 'Jones',
      username: usernameB,
      email: `${usernameB}@titan.com`,
      password: 'password123',
      pin: '1234'
    }),
    { headers }
  );

  if (regResA.status !== 200 || regResB.status !== 200) {
    console.error('Setup failed: Registration failed.');
    return null;
  }

  // 3. Login to get JWT Tokens
  const loginResA = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ username: usernameA, password: 'password123' }),
    { headers }
  );
  const tokenA = JSON.parse(loginResA.body).token;

  const loginResB = http.post(
    `${BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ username: usernameB, password: 'password123' }),
    { headers }
  );
  const tokenB = JSON.parse(loginResB.body).token;

  const authHeadersA = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenA}` };
  const authHeadersB = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${tokenB}` };

  // 4. Create Account for User A (Savings, USD 5000 initial balance)
  const accResA = http.post(
    `${BASE_URL}/api/v1/accounts`,
    JSON.stringify({
      accountType: 'SAVINGS',
      currency: 'USD',
      initialDeposit: 5000.00,
      description: 'Primary savings account'
    }),
    { headers: authHeadersA }
  );
  const accA = JSON.parse(accResA.body);

  // 5. Create Account for User B (Checking, USD 1000 initial balance)
  const accResB = http.post(
    `${BASE_URL}/api/v1/accounts`,
    JSON.stringify({
      accountType: 'CHECKING',
      currency: 'USD',
      initialDeposit: 1000.00,
      description: 'Primary checking account'
    }),
    { headers: authHeadersB }
  );
  const accB = JSON.parse(accResB.body);

  return {
    tokenA,
    tokenB,
    accountAId: accA.id,
    accountANumber: accA.accountNumber,
    accountBId: accB.id,
    accountBNumber: accB.accountNumber,
  };
}

// User Action Workflow
export default function (data) {
  if (!data) return;

  const headersA = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.tokenA}`
  };

  // --- Group 1: Query Balance (Reads/秒 Performance) ---
  group('Balance Checks', function () {
    const start = Date.now();
    const res = http.get(`${BASE_URL}/api/v1/accounts`, { headers: headersA });
    
    gatewayLatency.add(Date.now() - start);
    
    const isSuccess = check(res, {
      'get accounts status is 200': (r) => r.status === 200,
      'has account list': (r) => Array.isArray(JSON.parse(r.body)),
    });
    successRate.add(isSuccess);
  });

  sleep(0.5);

  // --- Group 2: Fund Transfer (Locks, Relational DB Write & gRPC Performance) ---
  group('Fund Transfer Transaction', function () {
    const start = Date.now();
    const res = http.post(
      `${BASE_URL}/api/v1/transactions/transfer`,
      JSON.stringify({
        fromAccountNumber: data.accountANumber,
        toAccountNumber: data.accountBNumber,
        amount: 10.00,
        pin: '1234',
        note: 'Load test transfer',
        otpCode: '000000',
        transactionType: 'TRANSFER'
      }),
      { headers: headersA }
    );
    
    const latency = Date.now() - start;
    transactionLatency.add(latency);
    gatewayLatency.add(latency);

    const isSuccess = check(res, {
      'transfer status is 200': (r) => r.status === 200,
      'transaction approved': (r) => JSON.parse(r.body).status === 'COMPLETED' || JSON.parse(r.body).status === 'SUCCESS',
    });
    successRate.add(isSuccess);
  });

  sleep(0.5);

  // --- Group 3: Apply for Loan (Microservice Integration & Outbox Performance) ---
  group('Loan Processing Workflow', function () {
    const start = Date.now();
    
    // Apply for loan ($50.00, well within eligibility limits of savings account)
    const applyRes = http.post(
      `${BASE_URL}/api/v1/loans/apply`,
      JSON.stringify({
        accountId: data.accountAId,
        accountNumber: data.accountANumber,
        amount: 50.00,
        termMonths: 6,
        note: 'Load testing loan processing'
      }),
      { headers: headersA }
    );

    const latency = Date.now() - start;
    loanLatency.add(latency);
    gatewayLatency.add(latency);

    const isSuccess = check(applyRes, {
      'loan apply status is 200': (r) => r.status === 200,
      'loan is created': (r) => JSON.parse(r.body).id !== undefined,
    });
    successRate.add(isSuccess);

    // If loan is created successfully, try to query user's loans
    if (isSuccess && applyRes.status === 200) {
      const myLoansRes = http.get(`${BASE_URL}/api/v1/loans/my`, { headers: headersA });
      check(myLoansRes, {
        'get my loans status is 200': (r) => r.status === 200,
      });
    }
  });

  sleep(1);
}
