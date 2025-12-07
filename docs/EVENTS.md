# Gaussian Events Reference

## Overview

All sampling functions in the Gaussian library emit on-chain events automatically. These events enable:

- **Off-chain indexing**: Track all Gaussian samples across all protocols
- **Analytics**: Analyze distribution of samples, usage patterns
- **Debugging**: Trace sampling operations in complex transactions
- **Monitoring**: Alert on unusual sampling behavior

## Event Types

### GaussianSampleEvent

Emitted for every standard normal N(0,1) sample.

**Event Size**: ~65 bytes

| Field | Type | Size | Description |
|-------|------|------|-------------|
| `z_magnitude` | `u256` | 32 bytes | Absolute value of z-score (WAD-scaled, 10^18) |
| `z_negative` | `bool` | 1 byte | Sign of z-score (`true` = negative) |
| `caller` | `address` | 32 bytes | Address that initiated the sample |

**Decoding the z-score**:
```
z = (z_negative ? -1 : 1) * z_magnitude / 10^18
```

**Emitted by**:
- `sample_z()`
- `sample_z_once()`
- `sample_standard_normal()`
- `sample_standard_normal_clt()`

---

### NormalSampleEvent

Emitted for every custom normal N(μ, σ²) sample.

**Event Size**: ~162 bytes

| Field | Type | Size | Description |
|-------|------|------|-------------|
| `z_magnitude` | `u256` | 32 bytes | z-score magnitude (WAD-scaled) |
| `z_negative` | `bool` | 1 byte | z-score sign |
| `mean` | `u256` | 32 bytes | Distribution mean μ (WAD-scaled) |
| `std_dev` | `u256` | 32 bytes | Standard deviation σ (WAD-scaled) |
| `value_magnitude` | `u256` | 32 bytes | Final sample |μ + σ·z| (WAD-scaled) |
| `value_negative` | `bool` | 1 byte | Final sample sign |
| `caller` | `address` | 32 bytes | Address that initiated the sample |

**Decoding the final value**:
```
value = (value_negative ? -1 : 1) * value_magnitude / 10^18
```

**Emitted by**:
- `sample_normal()`
- `sample_normal_once()`
- `sample_normal_clt()`

---

## Subscribing to Events

### Sui TypeScript SDK

```typescript
import { SuiClient } from '@mysten/sui/client';

const PACKAGE_ID = '0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b';

const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io' });

// Subscribe to GaussianSampleEvent
const unsubscribe = await client.subscribeEvent({
    filter: {
        MoveEventType: `${PACKAGE_ID}::events::GaussianSampleEvent`
    },
    onMessage: (event) => {
        const { z_magnitude, z_negative, caller } = event.parsedJson;
        const z = (z_negative ? -1 : 1) * Number(z_magnitude) / 1e18;
        console.log(`Sample: z=${z.toFixed(4)} by ${caller}`);
    }
});

// Later: unsubscribe();
```

### Query Historical Events

```typescript
const events = await client.queryEvents({
    query: {
        MoveEventType: `${PACKAGE_ID}::events::GaussianSampleEvent`
    },
    limit: 100,
    order: 'descending'
});

for (const event of events.data) {
    console.log(event.parsedJson);
}
```

### GraphQL

```graphql
subscription {
  events(
    filter: {
      eventType: "0x70c5...::events::GaussianSampleEvent"
    }
  ) {
    sendingModule {
      name
    }
    type {
      repr
    }
    json
    timestamp
  }
}
```

---

## Event Architecture

### Design Principles

1. **Single Event Module**: All event definitions in `events.move`
2. **Package-Internal Emit**: `public(package)` functions prevent external spoofing
3. **Comprehensive Coverage**: All 7 public sampling functions emit events
4. **Caller Attribution**: Every event includes the originating address

### Security

Events cannot be spoofed because:
- `emit_gaussian_sample()` and `emit_normal_sample()` are `public(package)`
- Only internal `sampling.move` can call them
- External packages cannot emit fake Gaussian events

### Gas Impact

Events add ~10-20% to sampling transaction gas costs:

| Function | Without Events | With Events | Delta |
|----------|----------------|-------------|-------|
| `sample_z` | ~1.6M MIST | ~2.0M MIST | +25% |
| `sample_normal` | ~1.6M MIST | ~2.0M MIST | +25% |

---

## Event Coverage Matrix

| Function | Event Type | Coverage |
|----------|------------|----------|
| `sample_z` | `GaussianSampleEvent` | ✅ |
| `sample_z_once` | `GaussianSampleEvent` | ✅ |
| `sample_standard_normal` | `GaussianSampleEvent` | ✅ |
| `sample_standard_normal_clt` | `GaussianSampleEvent` | ✅ |
| `sample_normal` | `NormalSampleEvent` | ✅ |
| `sample_normal_once` | `NormalSampleEvent` | ✅ |
| `sample_normal_clt` | `NormalSampleEvent` | ✅ |
| `cdf_standard` | None | ❌ (pure function) |
| `pdf_standard` | None | ❌ (pure function) |
| `ppf` | None | ❌ (pure function) |

**Note**: CDF/PDF/PPF don't emit events because they're deterministic pure functions with no randomness involved.

---

## Future Considerations

### Potential New Events (v1.2+)

- `BatchGaussianSampleEvent` - For multiple samples in one transaction
- `MultivariateGaussianEvent` - If multivariate sampling is added
- `ProfileUpdateEvent` - If profile becomes upgradeable

### Silent Sampling

If gas is a concern, consider adding `_silent` variants:

```move
// Hypothetical future API
public fun sample_z_silent(r: &Random, ctx: &mut TxContext): SignedWad
```

---

## See Also

- [API Reference](API_REFERENCE.md) - Full function documentation
- [sources/events.move](../sources/events.move) - Event source code
- [sources/sampling.move](../sources/sampling.move) - Sampling implementation
