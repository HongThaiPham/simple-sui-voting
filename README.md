# Simple On-chain Voting on Sui

A simple, scalable on-chain voting application built with **Sui Move**, leveraging Sui’s **Shared Object** model and on-chain time via `Clock`.

---

## Features

- Two voting options: **YES (1)** and **NO (0)**
- Each wallet address can vote **only once**
- Voting results are stored and readable **fully on-chain**
- Voting is restricted by a predefined **expiration time**
- Designed to be **gas-efficient and scalable** for a large number of voters

---

## Problem Explanation

This project implements a minimal on-chain voting system on the Sui blockchain.

The system must satisfy the following requirements:

1. Exactly two voting options are supported.
2. Each address is allowed to vote only once.
3. Voting results must be stored and queried directly from on-chain state.
4. Voting must automatically stop after a predefined expiration time.

The main challenge is enforcing the one-vote-per-address rule in a way that remains efficient and safe as the number of voters grows.

---

## Design Choice and Rationale

### Shared Object Model

The voting state is represented as a **Shared Object**, allowing multiple users to interact with and update the same on-chain state concurrently. This model is a natural fit for global voting logic where no single account owns the state.

### Why `Table` Instead of `vector`

To track whether an address has already voted, this implementation uses:

```
Table<address, u8>
```

instead of a `vector`.

**Rationale:**

- A `vector` requires linear scans to check if an address has voted, leading to **O(n)** operations.
- Resetting or modifying a vector-based voter list would also require O(n) operations, which do not scale and may exceed gas limits.
- `Table` provides **O(1)** lookup using the address as a unique key, enabling efficient enforcement of one-vote-per-address.

This design avoids expensive on-chain iteration and ensures the contract remains usable even with a large voter set.

---

## Design & Object Flow

### Objects

#### Voting (Shared Object)

The central object of the system:

- `yes_votes: u64` — number of YES votes
- `no_votes: u64` — number of NO votes
- `voted: Table<address, u8>` — records which option each address voted for
- `expired_at: u64` — expiration timestamp (milliseconds)

#### Clock (System Object)

- Provided by the Sui runtime
- Used to retrieve on-chain time via `timestamp_ms()`
- Ensures voting expiration is enforced deterministically on-chain

---

### Ownership and Mutation Rules

- The `Voting` object is a **shared object**, not owned by any single address.
- Any address may call `vote()` if:
  - The voting has not expired
  - The option is valid (`0` or `1`)
  - The address has not voted before

There is no admin role and no reset functionality.

---

## Core On-chain Logic

### Voting Structure

```move
public struct Voting has key {
    id: UID,
    yes_votes: u64,
    no_votes: u64,
    voted: Table<address, u8>,
    expired_at: u64,
}
```

### Entry Functions

#### `create(expired_at, ctx)`

- Creates a new `Voting` shared object
- Initializes vote counts to zero
- Sets the voting expiration time
- Shares the object for public interaction

#### `vote(v, option, clock, ctx)`

- Verifies the voting has not expired using `Clock`
- Validates the voting option
- Checks that the sender has not voted before
- Updates vote counters
- Records the voter’s choice in the table

---

### Read-only Functions

- `get_results(&Voting) -> (u64, u64)`
- `has_voted(&Voting, address) -> bool`
- `is_expired(&Voting, &Clock) -> bool`
- `get_voter_option(&Voting, address) -> Option<u8>`

---

## Live Demo

### Build and Publish

```bash
sui move build
sui client publish --gas-budget 100000000
```

### Create a Voting Object

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module sui_voting \
  --function create \
  --args <EXPIRED_AT_TIMESTAMP_MS> \
  --gas-budget 10000000
```

After creation, obtain the `VOTING_OBJECT_ID` from the transaction effects.

---

tx: https://suiscan.xyz/testnet/tx/ENK1YGJmSFnqr8izS2sUjcwsVRE38gD8kgPUc9KN3wWa

### Successful Vote

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module sui_voting \
  --function vote \
  --args <VOTING_OBJECT_ID> 1 0x6 \
  --gas-budget 10000000
```

Expected result:

- `yes_votes` increases by 1
- `no_votes` remains unchanged

---

tx: https://suiscan.xyz/testnet/tx/3fxJUoHGdvfknRHQgKUTgcAiqFFS96Sh5JzcuiqP8CSv

### Failing Transactions

#### Vote Twice with the Same Address

Result: transaction aborts with `E_ALREADY_VOTED`.

tx: https://suiscan.xyz/testnet/tx/BwTo8d2edTPkpGAr24AbrnpdqUJJ9DcsJsqNJvBiQiG6

#### Vote After Expiration

Result: transaction aborts with `E_VOTING_EXPIRED`.

tx: https://suiscan.xyz/testnet/tx/9neHhcY1oEUXqK3hqnhZRd1XZVqxuh5pSiZn9ZsF7UeU

---

## Reflection

### What Was Challenging?

- Enforcing one-vote-per-address without introducing O(n) on-chain operations.
- Avoiding reset-based designs that do not scale with large voter sets.
- Correctly integrating on-chain time using Sui’s `Clock`.

---

### What Would Be Improved with More Time?

- Emitting on-chain events for each vote to support efficient off-chain indexing, analytics, and UI updates.
- Adding metadata such as a voting title or description to make the contract more reusable in real-world scenarios.
- Making the post-expiration lifecycle more explicit, for example by introducing a finalized state to prevent unnecessary interactions.
- Exploring storage optimizations to further reduce long-term on-chain storage costs when the number of voters becomes very large.

---

## Summary

This project demonstrates:

- Proper use of **Shared Objects** on Sui
- Scalable on-chain state design using `Table` instead of `vector`
- Safe enforcement of one-vote-per-address
- Deterministic time-based logic using Sui’s `Clock`

It serves as a clean, production-oriented example of an on-chain voting system on the Sui blockchain.
