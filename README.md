# EventStream Consensus

A decentralized protocol for logging, timestamping, and verifying AI community events with cryptographic proof-of-attendance.

## Features

- Event creation and management on-chain
- Cryptographic check-in system
- Automatic proof-of-attendance badge issuance
- Immutable event attendance records
- Badge collection tracking

## Smart Contract Functions

### Public Functions

- `create-event` - Create new community event with duration
- `check-in` - Cryptographically check in to active events
- `end-event` - Close event and finalize attendance

### Read-Only Functions

- `get-event` - Retrieve event details and statistics
- `get-attendance` - Verify individual attendance records
- `get-badge-count` - View attendee's total badge collection
- `get-event-nonce` - Get current event counter

## Usage

Organizers create events and attendees check in to receive verifiable proof-of-attendance badges.