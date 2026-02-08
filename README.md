# Panoplia

A non-custodial MPC wallet with built-in privacy routing and DeFi access. Panoplia pairs a 2-of-2 threshold signature server (Vultisig SDK) with privacy-preserving on-ramp flows and curated yield strategies — so users go from fiat to earning in as few transactions as possible.

## Why

Most wallet setups leak orderflow data, force users onto a single RPC, and leave funds idle after bridging. Panoplia is built with optionality and privacy in mind:

- **MPC by default** — neither the server nor the device can sign alone (Vultisig 2-of-2 + optional social recovery via Shamir)
- **Run your own RPC** or use ours — user choice, not platform lock-in
- **Privacy routing** — deposits flow through LiFi to a fresh address on the same MPC setup, clean wallet hygiene from the start
- **DeFi on arrival** — toggle a yield strategy *at deposit time* so funds never sit idle

## Core Flow

```
On-ramp (fiat)
  -> LiFi privacy deposit to fresh MPC-controlled address
    -> Optional: direct deposit into DeFi earning position
      -> Off-ramp with accrued yield
```

The UX goal is minimal transaction confirmations: the user picks a strategy at deposit time, and routing + DeFi entry happen in as few steps as the chain allows.

## Features

### MPC Wallet
- 2-of-2 MPC key generation ceremony via Vultisig SDK (WASM) — no single point of failure
- Non-custodial co-signing: server + user device must both approve every transaction
- Multi-chain address derivation (Ethereum, Bitcoin, Solana)
- Vault export/import (Base64 backup)

### Social Recovery
- Shamir Secret Sharing (Privy's audited implementation) splits the recovery key into N shares with a K threshold
- Guardian approval flow with public URLs and a 72-hour recovery window

### Privacy Routing
- LiFi-powered deposits route funds to a fresh address still controlled by the same MPC setup
- Orderflow data protected when using the Panoplia server — not sold or shared
- RPC optionality: connect your own node or use provided endpoints

### Fiat On/Off-Ramp
- ZKP2P SDK integration for peer-to-peer fiat conversion (Venmo, Wise, etc.)
- Works in both web browsers and the Electron desktop app
- Off-ramp with accrued yield from DeFi positions

### DeFi Access
- Token swaps and cross-chain bridges via LiFi SDK v3
- Multi-token portfolio tracking with USD valuation
- Deposit directly into yield strategies at on-ramp time

### P2P Transfers
- Chat-style ETH transfer interface with contact management
- All transfers go through MPC co-signing

## DeFi Strategies

### Mainnet

| Strategy | Protocol | Notes |
|----------|----------|-------|
| ZCHF savings | [Frankencoin](https://app.frankencoin.com/savings) | ~4% on ZCHF swap + stability deposit |
| Lending | Aave, Fluid, PoolTogether | Blue-chip stablecoin pools, high TVL |
| LST + stability | stETH/rETH into [Liquity V2](https://liquity.app/earn) | Stability pool yield on top of staking |

### L2 — Arbitrum (primary)

| Strategy | Protocol | Notes |
|----------|----------|-------|
| USDN stability pools | [Nerite](https://app.nerite.org/) | Privacy Pool-integrated stablecoin ([context](https://x.com/0xprivacypools/status/2001047640042054119)) |
| LP USDN | PoolTogether or Balancer | Liquidity provision |
| ZKP2P LP | USDC/fiat pair | Earn on the on/off-ramp liquidity itself |

### Roadmap

| Strategy | Protocol | Notes |
|----------|----------|-------|
| Commodity exposure | Ostium | 1x long uranium, S&P 500 baskets via LiFi routing — higher fees, power-user territory |
| Solana DeFi | Fluid (if LiFi supports) | Cross-chain interop showcase |
| Airdrop farming | [Upshift](https://app.upshift.finance/pools/1/0xb2FdA773822E5a04c8A70348d66257DD5Cf442DB) + Liquity V2 forks | Vault strategies across fork ecosystem |
| ZKP2P escrow on-ramp | ZKP2P (Base) | More private on-ramp with potential yield — Base-only today, doesn't fit the permissionless multichain narrative yet |

## Architecture

Five git submodules, each independently developed and tested:

```
panoplia/
  panoplia.mpc/       MPC co-signing server
  panoplia.app/       Electron desktop wallet
  panoplia.demo/      Web demo + E2E tests
  panoplia.peer/      Fiat on/off-ramp SDK
  panoplia.lifi/      Swap, bridge & DeFi SDK
```

### System overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Client (Electron / Web)                 │
│                                                             │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────────┐    │
│  │ Auth     │   │ Wallet       │   │ Views            │    │
│  │ Store    │   │ Store        │   │  Dashboard       │    │
│  │ (Zustand)│   │ (Zustand)    │   │  Transfer        │    │
│  └────┬─────┘   └──────┬───────┘   │  DeFi / Security │    │
│       │                │           └────────┬─────────┘    │
│       └────────┬───────┘                    │              │
│                ▼                            │              │
│        ┌──────────────┐                     │              │
│        │  API Client  │◄────────────────────┘              │
│        │  (fetch+JWT) │                                    │
│        └──────┬───────┘                                    │
│               │            ┌──────────────┐                │
│               │            │ panoplia.peer│ ZKP2P hooks    │
│               │            │ (on/off-ramp)│                │
│               │            └──────────────┘                │
│               │            ┌──────────────┐                │
│               │            │ panoplia.lifi│ LiFi hooks     │
│               │            │ (swap/bridge)│                │
│               │            └──────────────┘                │
└───────────────┼─────────────────────────────────────────────┘
                │ REST /api
                ▼
┌─────────────────────────────────────────────────────────────┐
│                    panoplia.mpc (server)                     │
│                                                             │
│  Express ─► Routes ─► Services ─► SQLite (WAL)             │
│  (helmet, rate-limit, CORS)                                 │
│                                                             │
│  ┌──────────────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │ VaultCoordinator │  │ AuthService   │  │ RecoveryServ│  │
│  │                  │  │ bcrypt + JWT  │  │ Shamir SSS  │  │
│  │  Vultisig SDK    │  └───────────────┘  └─────────────┘  │
│  │  (WASM, cached)  │                                      │
│  │  ┌────────────┐  │  ┌───────────────────────────────┐   │
│  │  │ServerVault │  │  │ SQLite tables (9)             │   │
│  │  │Storage     │──┼─►│ kv_store, users, vaults,      │   │
│  │  │(kv_store)  │  │  │ vault_addresses, transactions, │   │
│  │  └────────────┘  │  │ recovery_configs, guardians,   │   │
│  └──────────────────┘  │ recovery_attempts, shares      │   │
│                        └───────────────────────────────┘   │
│                                                             │
│              ▼ Vultisig relay (MPC ceremony)                │
└─────────────────────────────────────────────────────────────┘
```

### MPC ceremony flow

Vault creation and transaction signing follow the same async pattern:

1. Client calls the server (`POST /api/vaults` or `POST /api/vaults/:id/transactions/sign`)
2. Server starts a Vultisig SDK ceremony in the background — the SDK communicates with the Vultisig relay
3. The SDK fires an `onQRCodeReady` callback with session info; the server resolves this immediately and returns it to the client
4. Client joins the same ceremony via its own SDK instance using the session payload
5. Both parties complete the MPC protocol through the relay — the HTTP request has already returned
6. On completion, the server updates the DB (vault status → `active`, or transaction status → `broadcast`)

This means vault creation and signing are **non-blocking**: the API responds fast with session info, and the actual cryptographic ceremony runs as a background promise.

### Encryption at rest

Vault shares stored in the `kv_store` table are encrypted with **AES-256-GCM**. Each encrypt call uses a random 32-byte salt and 16-byte IV, with the key derived via scrypt from the `SERVER_MASTER_KEY`. Output format: `salt(32) || iv(16) || authTag(16) || ciphertext`. Guardian recovery shares use the same encryption.

### SDK architecture (peer + lifi)

Both `panoplia.peer` and `panoplia.lifi` are React hook libraries designed to be consumed by any frontend — they have no dependency on the MPC server.

**panoplia.peer** wraps `@zkp2p/sdk` with React context providers and hooks. On-ramp uses a **strategy pattern** (extension vs. redirect) to handle web and Electron environments. Off-ramp hooks (`useCreateDeposit`, `useAddFunds`, `useDeposits`, etc.) wrap the `OfframpClient` which is created lazily once a wallet connects. Supports Venmo, Wise, and other payment platforms.

**panoplia.lifi** wraps LiFi SDK v3 with React Query-backed hooks. Token hooks (`useTokens`, `useTokenSearch`, `useTokenBalances`) handle discovery. Swap hooks (`useQuote`, `useRoutes`, `useSwapExecution`) manage the full lifecycle from quote to on-chain execution with real-time status via `executeRoute` callbacks. Zap hooks (`useContractCallQuote`, `useZapExecution`) enable single-tx entry into DeFi positions through LiFi's contract call routing. Also ships a pre-built `<PanopliaWidget>` with swap/bridge/compact presets.

## How It Was Built

**MPC Server (`panoplia.mpc`)** — Express 4 backend, SQLite via better-sqlite3 in WAL mode. The `VaultCoordinator` is the core service: it manages a cache of up to 50 Vultisig SDK instances (one per user, lazily initialized from WASM), orchestrates keygen/signing/reshare ceremonies, and persists results to 9 normalized tables. `AuthService` handles registration and login (bcrypt + JWT). `RecoveryService` implements Shamir Secret Sharing using Privy's audited `shamir-secret-sharing` package — splits the vault export into N shares with a K threshold, encrypts each with AES-256-GCM, and manages the 72-hour guardian recovery window. All route inputs are validated with Zod. 107 tests across unit, integration, and API layers (Vitest + Supertest).

**Desktop App (`panoplia.app`)** — Electron 39 with React 19 renderer. Tailwind v4 + shadcn/ui + Radix primitives for the component system. Two Zustand stores: `auth-store` (JWT + localStorage persistence) and `wallet-store` (vault data from server). The API client is a thin fetch wrapper that prepends Bearer tokens and routes all requests through `localhost:3000/api`. Views: SplashScreen (health check) → Auth → WalletSelection → Dashboard → Transfer/DeFi/Security. Window sized at 480x860 for mobile wallet form factor. Motion library for animations.

**Web Demo (`panoplia.demo`)** — React 18 + Vite app with wagmi + viem for chain interactions. Mirrors all desktop wallet features in the browser. Uses `concurrently` to boot the MPC server + web app together. 12 Playwright E2E tests cover auth flows, wallet creation with MPC keygen, and navigation guards.

**On/Off-Ramp SDK (`panoplia.peer`)** — 22 source files exporting React context providers and hooks. On-ramp: `PeerOnrampProvider` → `useOnramp()` / `useOnrampConnection()` / `useOnrampProof()`. Off-ramp: `PeerOfframpProvider` → `useCreateDeposit()` / `useDeposits()` / `useIntents()`. Platform detection auto-selects the right on-ramp strategy. 125 tests.

**DeFi SDK (`panoplia.lifi`)** — 22 source files wrapping LiFi SDK v3. Token layer: `useTokens`, `useTokenSearch`, `useTokenBalances`, `useTrendingTokens`. Swap layer: `useQuote` → `useRoutes` → `useSwapExecution` (state machine: idle → pending → executing → completed/failed). Zap layer: `useContractCallQuote` → `useZapExecution` for single-tx DeFi deposits. Chain layer: `useChains`, `useTools`, `useConnections`. All queries cached via React Query with 30s stale time.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| MPC protocol | Vultisig SDK 0.1.0 (WASM), 2-of-2 threshold signatures |
| Social recovery | Shamir Secret Sharing (`shamir-secret-sharing` by Privy) |
| Encryption | AES-256-GCM, scrypt key derivation, random salt + IV |
| Backend | Express 4, SQLite (better-sqlite3, WAL mode), JWT, Zod, Pino |
| Desktop app | Electron 39, React 19, Tailwind v4, shadcn/ui, Zustand, Motion |
| Web demo | React 18, Vite, Tailwind CSS, wagmi, viem |
| On/off-ramp | ZKP2P SDK (Venmo, Wise, etc.) |
| DeFi routing | LiFi SDK v3, React Query |
| Testing | Vitest (107 server + 125 SDK), Playwright (12 E2E) |
