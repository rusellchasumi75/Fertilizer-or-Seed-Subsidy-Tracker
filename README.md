# 🌱 Fertilizer or Seed Subsidy Tracker

A transparent blockchain-based system for tracking agricultural subsidy distributions to prevent corruption and ensure fair access to farming resources.

## 🎯 Overview

This smart contract provides a decentralized solution for recording and verifying fertilizer and seed subsidy distributions. By leveraging blockchain technology, it creates an immutable record of all transactions, making corruption and double-spending virtually impossible.

## ✨ Features

- 🔐 **Authorized Distributors**: Only approved distributors can register beneficiaries and distribute subsidies
- 👥 **Beneficiary Management**: Register farmers with their names and locations
- 📋 **Subsidy Tracking**: Track fertilizer and seed distributions by season
- 🚫 **Double-Spending Prevention**: Ensures beneficiaries can't receive the same subsidy twice in one season
- 📊 **Transparent Records**: All distributions are recorded on-chain with timestamps and block heights
- 🔍 **Verification System**: Anyone can verify distribution records
- 📈 **Batch Processing**: Support for multiple distributions in a single transaction

## 🚀 Quick Start

### Deploy the Contract

```bash
clarinet deploy
```

### Core Functions

#### 👨‍💼 Admin Functions

**Authorize Distributor**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker authorize-distributor 'SP1DISTRIBUTOR...)
```

**Register Beneficiary**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker register-beneficiary 'SP1FARMER... "John Doe" "Village A")
```

#### 🚚 Distribution Functions

**Distribute Single Subsidy**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker distribute-subsidy 
    'SP1FARMER... 
    "fertilizer" 
    u1000 
    u2024)
```

**Batch Distribution**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker batch-distribute 
    (list 
        {beneficiary: 'SP1FARMER1..., subsidy-type: "fertilizer", amount: u500, season: u2024}
        {beneficiary: 'SP1FARMER2..., subsidy-type: "seed", amount: u300, season: u2024}
    ))
```

#### 🔍 Query Functions

**Check Beneficiary Info**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker get-beneficiary 'SP1FARMER...)
```

**Verify Distribution**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker verify-distribution 'SP1FARMER... "fertilizer" u2024)
```

**Get Beneficiary History**
```clarity
(contract-call? .fertilizer-or-seed-subsidy-tracker get-beneficiary-history 'SP1FARMER...)
```

## 📖 Contract Structure

### 🗺️ Data Maps

- **beneficiaries**: Stores farmer registration details
- **subsidy-records**: Records individual distributions
- **beneficiary-totals**: Tracks cumulative amounts per subsidy type
- **authorized-distributors**: Manages distributor permissions

### 🔧 Key Functions

| Function | Purpose | Access |
|----------|---------|---------|
| `authorize-distributor` | Add authorized distributor | Owner only |
| `register-beneficiary` | Register new farmer | Distributors |
| `distribute-subsidy` | Record single distribution | Distributors |
| `batch-distribute` | Process multiple distributions | Distributors |
| `verify-distribution` | Verify a distribution record | Public |
| `get-beneficiary-history` | Get farmer's total received | Public |

## 🛡️ Security Features

- ✅ **Owner-only admin functions**: Critical operations restricted to contract owner
- ✅ **Distributor authorization**: Only approved entities can distribute subsidies  
- ✅ **Double-spending prevention**: Each beneficiary can only receive one subsidy per type per season
- ✅ **Input validation**: All amounts must be positive, beneficiaries must be registered
- ✅ **Immutable records**: All distributions permanently recorded on blockchain

## 📊 Usage Examples

### Typical Workflow

1. **Setup** 🏗️
   - Deploy contract
   - Authorize government distributors

2. **Registration** 📝
   - Distributors register eligible farmers
   - Store farmer details (name, location)

3. **Distribution** 🚛
   - Distribute fertilizer/seeds to registered farmers
   - Record amounts, types, and seasons
   - Generate immutable distribution records

4. **Verification** ✔️
   - Citizens verify distributions
   - Audit distribution history
   - Ensure transparency and accountability

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📄 License

MIT License - feel free to use and modify for your agricultural tracking needs! 🌾

## 🤝 Contributing

Contributions welcome! Please ensure all tests pass and follow the existing code style.

---

*Building transparent agricultural systems, one block at a time* 🔗🌱
