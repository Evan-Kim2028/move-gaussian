#!/usr/bin/env python3
"""
Gas Benchmarking Script for Gaussian Package

Measures compute costs for all core functions via sui client --dev-inspect.
Outputs results to docs/GAS_BENCHMARKS.md
"""

import subprocess
import json
import sys
from dataclasses import dataclass
from typing import Optional

# Package ID from testnet deployment
PACKAGE_ID = "0x70c5040e7e2119275d8f93df8242e882a20ac6ae5a317673995323d75a93b36b"

SCALE = 10**18


@dataclass
class BenchmarkResult:
    function: str
    module: str
    args: list
    computation_cost: int
    storage_cost: int
    total_gas: int
    success: bool
    notes: str = ""


def run_dev_inspect(module: str, function: str, args: list) -> Optional[dict]:
    """Run sui client call --dev-inspect and return parsed JSON."""
    cmd = [
        "sui", "client", "call",
        "--package", PACKAGE_ID,
        "--module", module,
        "--function", function,
        "--gas-budget", "100000000",
        "--dev-inspect",
        "--json"
    ]
    
    for arg in args:
        if isinstance(arg, bool):
            cmd.extend(["--args", "true" if arg else "false"])
        else:
            cmd.extend(["--args", str(arg)])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            print(f"  ❌ Error: {result.stderr[:200]}")
            return None
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        print(f"  ❌ Timeout")
        return None
    except json.JSONDecodeError as e:
        print(f"  ❌ JSON error: {e}")
        return None


def extract_gas(result: dict) -> tuple:
    """Extract gas costs from dev-inspect result."""
    try:
        gas = result["effects"]["gasUsed"]
        comp = int(gas["computationCost"])
        stor = int(gas["storageCost"])
        return comp, stor, comp + stor
    except (KeyError, TypeError):
        return 0, 0, 0


def benchmark_function(module: str, function: str, args: list, notes: str = "") -> BenchmarkResult:
    """Benchmark a single function call."""
    print(f"  Benchmarking {module}::{function}({args})...", end=" ")
    
    result = run_dev_inspect(module, function, args)
    
    if result is None:
        print("FAILED")
        return BenchmarkResult(
            function=function,
            module=module,
            args=args,
            computation_cost=0,
            storage_cost=0,
            total_gas=0,
            success=False,
            notes=notes
        )
    
    comp, stor, total = extract_gas(result)
    print(f"{comp:,} compute, {total:,} total")
    
    return BenchmarkResult(
        function=function,
        module=module,
        args=args,
        computation_cost=comp,
        storage_cost=stor,
        total_gas=total,
        success=True,
        notes=notes
    )


def run_benchmarks() -> list:
    """Run all benchmarks and return results."""
    results = []
    
    print("\n" + "="*60)
    print("GAUSSIAN PACKAGE GAS BENCHMARKS")
    print("="*60)
    
    # =========================================
    # sample_z_from_seed - Standard normal sampling
    # =========================================
    print("\n📊 sample_z_from_seed (PPF-based sampling)")
    
    # Test various seeds to get range of gas costs
    test_seeds = [
        (12345, "small seed (tail region)"),
        (9223372036854775808, "midpoint (central region)"),
        (1000000000000000000, "lower quartile"),
        (14000000000000000000, "upper quartile"),
    ]
    
    for seed, note in test_seeds:
        r = benchmark_function("harness", "sample_z_from_seed", [seed], note)
        results.append(r)
    
    # =========================================
    # cdf_from_signed - Forward CDF Φ(z)
    # =========================================
    print("\n📊 cdf_from_signed (forward CDF)")
    cdf_cases = [
        (0, False, "z = 0.0"),
        (SCALE, False, "z = 1.0"),
        (2 * SCALE, False, "z = 2.0"),
        (6 * SCALE, True, "|z| = 6.0 tail (negative)"),
    ]
    for mag, neg, note in cdf_cases:
        r = benchmark_function("harness", "cdf_from_signed", [mag, neg], note)
        results.append(r)

    # =========================================
    # ppf_from_prob - Inverse CDF Φ⁻¹(p)
    # =========================================
    print("\n📊 ppf_from_prob (inverse CDF)")
    ppf_cases = [
        (100_000_000, "p = 1e-10 (lower tail)"),
        (500_000_000_000_000_000, "p = 0.5 (center)"),
        (980_000_000_000_000_000, "p = 0.98 (central/upper)"),
        (999_000_000_000_000_000, "p = 0.999 (upper tail)"),
    ]
    for p, note in ppf_cases:
        r = benchmark_function("harness", "ppf_from_prob", [p], note)
        results.append(r)

    # =========================================
    # sample_normal_from_seed - Custom normal N(μ, σ²)
    # =========================================
    print("\n📊 sample_normal_from_seed (custom distribution)")
    
    # mean=1.0, std=0.1 (values that fit in CLI args)
    r = benchmark_function(
        "harness", "sample_normal_from_seed", 
        [9223372036854775808, 1000000000000000000, 100000000000000000],
        "N(1.0, 0.1²)"
    )
    results.append(r)
    
    return results


def generate_markdown_report(results: list) -> str:
    """Generate markdown report from benchmark results."""
    
    # Calculate statistics
    successful = [r for r in results if r.success]
    if not successful:
        return "# Gas Benchmarks\n\nNo successful benchmarks."
    
    avg_compute = sum(r.computation_cost for r in successful) // len(successful)
    max_compute = max(r.computation_cost for r in successful)
    min_compute = min(r.computation_cost for r in successful)
    
    report = f"""# Gaussian Package Gas Benchmarks

**Date**: 2025-12-07  
**Network**: Sui Testnet  
**Package**: `{PACKAGE_ID}`

---

## Summary

| Metric | Value |
|--------|-------|
| Functions Tested | {len(results)} |
| Successful | {len(successful)} |
| Avg Computation Cost | {avg_compute:,} MIST |
| Max Computation Cost | {max_compute:,} MIST |
| Min Computation Cost | {min_compute:,} MIST |

---

## Detailed Results

### sample_z_from_seed (Standard Normal Sampling)

This is the primary function for sampling from N(0,1). Uses PPF (inverse CDF) method.

| Seed | Region | Computation | Storage | Total | Status |
|------|--------|-------------|---------|-------|--------|
"""
    
    for r in results:
        if r.function == "sample_z_from_seed":
            status = "✅" if r.success else "❌"
            report += f"| {r.args[0]} | {r.notes} | {r.computation_cost:,} | {r.storage_cost:,} | {r.total_gas:,} | {status} |\n"
    
    report += """
### sample_normal_from_seed (Custom Normal Distribution)

Samples from N(μ, σ²) by computing μ + σ·z where z ~ N(0,1).

| Parameters | Computation | Storage | Total | Status |
|------------|-------------|---------|-------|--------|
"""
    
    for r in results:
        if r.function == "sample_normal_from_seed":
            status = "✅" if r.success else "❌"
            report += f"| {r.notes} | {r.computation_cost:,} | {r.storage_cost:,} | {r.total_gas:,} | {status} |\n"
    
    report += """
### cdf_from_signed (Forward CDF)

| z_mag (WAD) | is_negative | Region | Computation | Storage | Total | Status |
|-------------|-------------|--------|-------------|---------|-------|--------|
"""
    for r in results:
        if r.function == "cdf_from_signed":
            status = "✅" if r.success else "❌"
            report += f"| {r.args[0]} | {r.args[1]} | {r.notes} | {r.computation_cost:,} | {r.storage_cost:,} | {r.total_gas:,} | {status} |\n"

    report += """
### ppf_from_prob (Inverse CDF)

| p (WAD) | Region | Computation | Storage | Total | Status |
|---------|--------|-------------|---------|-------|--------|
"""
    for r in results:
        if r.function == "ppf_from_prob":
            status = "✅" if r.success else "❌"
            report += f"| {r.args[0]} | {r.notes} | {r.computation_cost:,} | {r.storage_cost:,} | {r.total_gas:,} | {status} |\n"

    report += f"""
---

## Comparison with Solidity

| Function | Gaussian (Sui) | solgauss (EVM) | solstat (EVM) |
|----------|----------------|----------------|---------------|
| PPF/sample_z | ~{avg_compute:,} MIST | ~2,001 gas | N/A |
| CDF | TBD | 519-833 gas | 916-5,137 gas |
| erfc | TBD | 687-693 gas | 4,436-4,543 gas |

**Note**: Direct comparison is difficult due to different gas models (Sui MIST vs EVM gas).
Sui's computation cost of ~1M MIST ≈ 0.001 SUI is very affordable.

---

## Cost Analysis

At current testnet rates:
- **1 SUI** = 1,000,000,000 MIST (10^9)
- **Average sample_z cost**: ~{avg_compute:,} MIST = ~{avg_compute/1e9:.6f} SUI

**Per 1 SUI, you can perform approximately {int(1e9 / avg_compute):,} Gaussian samples.**

---

## Methodology

Benchmarks run via `sui client call --dev-inspect --json`:
- dev-inspect simulates execution without spending gas
- Captures computation and storage costs
- Run on Sui testnet against deployed package

To reproduce:
```bash
cd packages/gaussian
python3 scripts/benchmark.py
```
"""
    
    return report


def main():
    results = run_benchmarks()
    
    print("\n" + "="*60)
    print("GENERATING REPORT")
    print("="*60)
    
    report = generate_markdown_report(results)
    
    # Write to docs/GAS_BENCHMARKS.md
    output_path = "docs/GAS_BENCHMARKS.md"
    with open(output_path, "w") as f:
        f.write(report)
    
    print(f"\n✅ Report written to {output_path}")
    
    # Also print summary
    successful = [r for r in results if r.success]
    print(f"\nBenchmarks: {len(successful)}/{len(results)} successful")
    
    if successful:
        avg = sum(r.computation_cost for r in successful) // len(successful)
        print(f"Average computation cost: {avg:,} MIST")


if __name__ == "__main__":
    main()
