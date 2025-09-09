# 🧪 Reproducible Experiment NFT System

A Clarity smart contract that incentivizes scientific reproducibility by minting NFTs for successfully replicated experiments.

## 🎯 Overview

This system allows researchers to:
- 📝 Publish original experiments with detailed methodologies
- 🔄 Submit replication attempts with results and success ratings
- 🏆 Mint NFTs when experiments achieve sufficient successful replications
- 📊 Build reputation scores based on replication contributions

## 🚀 Features

### Core Functionality
- **Experiment Creation**: Submit original studies with methodology and expected results
- **Replication Submission**: Report replication attempts with success status and quality ratings
- **NFT Minting**: Mint reproducibility NFTs for well-replicated experiments
- **Reputation System**: Track user contributions and build scientific credibility
- **Verification**: Contract owner can verify replication submissions

### Smart Contract Functions

#### 📋 Public Functions

**`create-experiment`**
```clarity
(create-experiment title description methodology expected-results)
```
Creates a new experiment entry with detailed methodology.

**`submit-replication`**  
```clarity
(submit-replication experiment-id results success rating)
```
Submits a replication attempt with results and 1-10 quality rating.

**`mint-reproducibility-nft`**
```clarity
(mint-reproducibility-nft experiment-id)
```
Mints an NFT for experiments with sufficient successful replications (default: 3).

**`verify-replication`** (Owner only)
```clarity
(verify-replication replication-id)
```
Verifies a replication submission.

**`set-min-replications`** (Owner only)
```clarity
(set-min-replications new-min)
```
Updates minimum successful replications required for NFT minting.

#### 🔍 Read-Only Functions

- `get-experiment` - Retrieve experiment details
- `get-replication` - Get replication information  
- `get-user-reputation` - Check user's reputation score
- `get-nft-metadata` - View NFT metadata
- `get-user-replication` - Check if user replicated specific experiment
- `get-next-experiment-id` - Get next available experiment ID
- `get-min-replications` - Check minimum replication requirement

## 🛠️ Usage

### 1. Deploy Contract
```bash
clarinet deploy
```

### 2. Create an Experiment
```clarity
(contract-call? .reproducible-experiment-nft-system create-experiment 
  "COVID-19 Vaccine Efficacy Study" 
  "Randomized controlled trial measuring vaccine effectiveness"
  "Double-blind RCT with 1000 participants over 6 months..."
  "Expected 95% efficacy rate with 2.5% margin of error")
```

### 3. Submit Replication
```clarity
(contract-call? .reproducible-experiment-nft-system submit-replication 
  u1 
  "Achieved 94.2% efficacy rate, within expected margin" 
  true 
  u8)
```

### 4. Mint NFT
```clarity
(contract-call? .reproducible-experiment-nft-system mint-reproducibility-nft u1)
```

## 📊 Data Structures

### Experiment
- Creator, title, description, methodology
- Expected results and creation timestamp
- Replication counters and NFT minting status

### Replication  
- Experiment ID, replicator, results
- Success status, quality rating, verification
- Creation timestamp

### User Reputation
- Total and successful replication counts
- Cumulative reputation score

### NFT Metadata
- Linked experiment details
- Creator information and minting timestamp
- Successful replication count

## 🔒 Security Features

- Owner-only functions for verification and configuration
- Prevents duplicate replications from same user
- Validates rating ranges (1-10)
- Ensures minimum replication thresholds
- Tracks creation timestamps using `stacks-block-height`

## 🎮 Testing

Run tests with:
```bash
clarinet test
```

## 📈 Reputation System

Users earn reputation through:
- **Successful Replications**: Higher weight for confirmed successful attempts
- **Quality Ratings**: 1-10 scale for replication quality assessment  
- **Verification Status**: Verified replications carry more weight

## 🎨 NFT Benefits

Successfully replicated experiments earn:
- 🏅 Unique NFT representing reproducibility achievement
- 📈 Increased visibility and credibility
- 🔗 Immutable proof of scientific validation
- 💰 Potential marketplace value

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

*Built with ❤️ for the scientific community*
