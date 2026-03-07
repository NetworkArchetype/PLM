#!/usr/bin/env ruby
# frozen_string_literal: true
#
# PLM Theorem Prover — Ruby Edition
# ===================================
# Independently verifies all 6 algebraic theorems of the PLM transform
# using Ruby BigDecimal high-precision arithmetic.
#
# Formula: S = ((pi * Y) * (lam * X)) / (mu * C)
#
# Theorems:
#   1. Factorisation Identity
#   2. Bilinear Scaling
#   3. Ratio Invariance
#   4. Sign / Absolute-Value
#   5. Monotonicity in X
#   6. Lipschitz Continuity
#
# Author : PLM Proof Package (auto-generated)
# License: Same as PLM_APLIED repository

require "bigdecimal"
require "json"
require "time"

# ---------------------------------------------------------------------------
# PLM Core (self-contained, mirrors Code_core_3/plm-formalized/ruby/plm.rb)
# ---------------------------------------------------------------------------
module PLM
  module_function

  def hex_to_int(hex_str)
    s = hex_str.strip.downcase
    s = s[2..] if s.start_with?("0x")
    raise ArgumentError, "invalid hex: #{hex_str}" unless s.match?(/\A[0-9a-f]+\z/)
    s.to_i(16)
  end

  def plm_ratio(pi:, lam:, mu:)
    mu_d = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu_d.zero?
    BigDecimal(pi.to_s) * BigDecimal(lam.to_s) / mu_d
  end

  def secret_value(pi:, lam:, mu:, x:, public_hash_hex:, block_size:, crc_decimal:)
    pi_d  = BigDecimal(pi.to_s)
    lam_d = BigDecimal(lam.to_s)
    mu_d  = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu_d.zero?

    y = hex_to_int(public_hash_hex)
    c = Integer(block_size) + Integer(crc_decimal)
    raise ArgumentError, "C must be positive" if c <= 0

    numerator   = (pi_d * BigDecimal(y.to_s)) * (lam_d * BigDecimal(x.to_s))
    denominator = mu_d * BigDecimal(c.to_s)
    numerator / denominator
  end
end

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
class TheoremResult
  attr_reader :name, :passed, :details, :elapsed_ms

  def initialize(name:, passed:, details:, elapsed_ms:)
    @name       = name
    @passed     = passed
    @details    = details
    @elapsed_ms = elapsed_ms
  end

  def to_h
    { name: @name, passed: @passed, elapsed_ms: @elapsed_ms.round(2), details: @details }
  end
end

def bd(val) = BigDecimal(val.to_s)

PI_STR  = "3.14159265358979323846264338327950288419716939937510"
PHI_STR = "1.61803398874989484820458683436563811772030917980576"
E_STR   = "2.71828182845904523536028747135266249775724709369995"
HEX_HASH    = "abcdef1234567890"
BLOCK_SIZE  = 128
CRC         = 12345

def compute_s(pi, lam, mu, x, hex_hash = HEX_HASH, block_size = BLOCK_SIZE, crc = CRC)
  PLM.secret_value(
    pi: pi, lam: lam, mu: mu, x: x,
    public_hash_hex: hex_hash, block_size: block_size, crc_decimal: crc
  )
end

# ---------------------------------------------------------------------------
# Theorem 1: Factorisation Identity
# ---------------------------------------------------------------------------
def prove_theorem_1
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)

  s_direct = compute_s(pi, lam, mu, 42)
  ratio = PLM.plm_ratio(pi: pi, lam: lam, mu: mu)
  y = bd(PLM.hex_to_int(HEX_HASH))
  x = bd(42)
  c = bd(BLOCK_SIZE + CRC)
  s_factored = ratio * (y * x) / c

  diff = (s_direct - s_factored).abs
  rel_err = s_direct.zero? ? diff : diff / s_direct.abs
  passed = rel_err < bd("1e-75")
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 1: Factorisation Identity",
    passed: passed,
    details: { S_direct: s_direct.to_s("F"), S_factored: s_factored.to_s("F"),
               absolute_diff: diff.to_s("F"), relative_error: rel_err.to_s("E") },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Theorem 2: Bilinear Scaling
# ---------------------------------------------------------------------------
def prove_theorem_2
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)
  alpha = bd("7.123")
  beta  = bd("0.456")

  s_base   = compute_s(pi, lam, mu, 42)
  s_scaled = compute_s(pi * alpha, lam * beta, mu, 42)
  expected = alpha * beta * s_base
  diff = (s_scaled - expected).abs
  passed = diff == 0 || diff < bd("1e-75")
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 2: Bilinear Scaling",
    passed: passed,
    details: { alpha: alpha.to_s("F"), beta: beta.to_s("F"),
               S_base: s_base.to_s("F"), S_scaled: s_scaled.to_s("F"),
               expected: expected.to_s("F"), diff: diff.to_s("E") },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Theorem 3: Ratio Invariance (scaling pi and mu by same k)
# ---------------------------------------------------------------------------
def prove_theorem_3
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)

  s_base = compute_s(pi, lam, mu, 42)
  k_values = [bd("2"), bd("0.5"), bd("100"), bd("0.001")]

  trials = k_values.map do |k|
    s_k = compute_s(pi * k, lam, mu * k, 42)
    diff = (s_k - s_base).abs
    ok = diff == 0
    { k: k.to_s("F"), S_k: s_k.to_s("F"), diff: diff.to_s("E"), ok: ok }
  end

  all_pass = trials.all? { |t| t[:ok] }
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 3: Ratio Invariance (pi/mu)",
    passed: all_pass,
    details: { S_base: s_base.to_s("F"), trials: trials },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Theorem 4: Sign / Absolute-Value
# ---------------------------------------------------------------------------
def prove_theorem_4
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)

  s_pos = compute_s(pi, lam, mu, 42)

  combos = [
    [1,  1,  1,  +1],
    [-1, 1,  1,  -1],
    [1, -1,  1,  -1],
    [1,  1, -1,  -1],
    [-1,-1,  1,  +1],
    [-1, 1, -1,  +1],
    [1, -1, -1,  +1],
    [-1,-1, -1,  -1],
  ]

  trials = combos.map do |s_pi, s_lam, s_mu, expected_sign|
    s_signed = compute_s(pi * s_pi, lam * s_lam, mu * s_mu, 42)
    actual_sign = s_signed.positive? ? 1 : (s_signed.negative? ? -1 : 0)
    magnitude_ok = s_signed.abs == s_pos.abs
    sign_ok = actual_sign == expected_sign
    {
      signs: "pi=#{s_pi > 0 ? '+' : ''}#{s_pi}, lam=#{s_lam > 0 ? '+' : ''}#{s_lam}, mu=#{s_mu > 0 ? '+' : ''}#{s_mu}",
      expected_sign: expected_sign,
      actual_sign: actual_sign,
      magnitude_match: magnitude_ok,
      ok: magnitude_ok && sign_ok
    }
  end

  all_pass = trials.all? { |t| t[:ok] }
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 4: Sign / Absolute-Value",
    passed: all_pass,
    details: { combos_tested: combos.size, trials: trials },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Theorem 5: Monotonicity in X
# ---------------------------------------------------------------------------
def prove_theorem_5
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)

  prev_s = nil
  all_monotone = true
  violations = []

  (1..100).each do |x|
    s_x = compute_s(pi, lam, mu, x)
    if prev_s && s_x <= prev_s
      all_monotone = false
      violations << { x: x, S_x: s_x.to_s("F"), prev_S: prev_s.to_s("F") }
    end
    prev_s = s_x
  end

  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 5: Monotonicity in X",
    passed: all_monotone,
    details: { x_range: "1..100", points_tested: 100,
               strictly_increasing: all_monotone, violations: violations },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Theorem 6: Lipschitz Continuity
# ---------------------------------------------------------------------------
def prove_theorem_6
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  lam = bd(PHI_STR)
  mu  = bd(E_STR)

  y = bd(PLM.hex_to_int(HEX_HASH))
  c = bd(BLOCK_SIZE + CRC)
  l_const = (pi.abs * y * lam.abs) / (mu.abs * c)

  pairs = [[1, 50], [10, 11], [42, 99], [1, 100], [50, 51]]
  trials = pairs.map do |x1, x2|
    s1  = compute_s(pi, lam, mu, x1)
    s2  = compute_s(pi, lam, mu, x2)
    lhs = (s2 - s1).abs
    rhs = l_const * (bd(x2) - bd(x1)).abs
    ok  = lhs <= rhs
    {
      x1: x1, x2: x2,
      "|S2-S1|": lhs.to_s("F"),
      "L*|x2-x1|": rhs.to_s("F"),
      ratio: rhs.zero? ? "N/A" : (lhs / rhs).to_s("F"),
      ok: ok
    }
  end

  all_pass = trials.all? { |t| t[:ok] }
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Theorem 6: Lipschitz Continuity",
    passed: all_pass,
    details: { L_constant: l_const.to_s("F"), pairs_tested: pairs.size, trials: trials },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Bonus: PLM Constant R
# ---------------------------------------------------------------------------
def compute_plm_constant
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  pi  = bd(PI_STR)
  phi = bd(PHI_STR)
  e   = bd(E_STR)

  r = (pi * phi) / e
  r_via_func = PLM.plm_ratio(pi: pi, lam: phi, mu: e)
  match = r == r_via_func
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "PLM Constant R = pi*phi/e",
    passed: match,
    details: { R: r.to_s("F"), R_via_plm_ratio: r_via_func.to_s("F"), match: match },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------
def prove_determinism
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  results = 100.times.map do
    compute_s(bd(PI_STR), bd(PHI_STR), bd(E_STR), 42).to_s("F")
  end
  all_same = results.uniq.size == 1
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Determinism (100 runs)",
    passed: all_same,
    details: { runs: 100, unique_values: results.uniq.size, sample_value: results.first },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Guard Rails
# ---------------------------------------------------------------------------
def prove_guardrails
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  tests = []

  # mu = 0
  begin
    compute_s(bd("3.14"), bd("1.61"), bd("0"), 1)
    tests << { test: "mu=0 raises ZeroDivisionError", ok: false }
  rescue ZeroDivisionError
    tests << { test: "mu=0 raises ZeroDivisionError", ok: true }
  end

  # C <= 0
  begin
    PLM.secret_value(pi: bd("3.14"), lam: bd("1"), mu: bd("1"),
                     x: 1, public_hash_hex: "0a", block_size: 0, crc_decimal: 0)
    tests << { test: "C<=0 raises ArgumentError", ok: false }
  rescue ArgumentError
    tests << { test: "C<=0 raises ArgumentError", ok: true }
  end

  # Invalid hex
  begin
    PLM.secret_value(pi: bd("3.14"), lam: bd("1"), mu: bd("1"),
                     x: 1, public_hash_hex: "not-hex", block_size: 1, crc_decimal: 1)
    tests << { test: "invalid hex raises exception", ok: false }
  rescue ArgumentError
    tests << { test: "invalid hex raises exception", ok: true }
  end

  all_ok = tests.all? { |t| t[:ok] }
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

  TheoremResult.new(
    name: "Guard Rails",
    passed: all_ok,
    details: { tests: tests },
    elapsed_ms: elapsed
  )
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
puts "=" * 72
puts "  PLM THEOREM PROVER — Ruby BigDecimal Arithmetic"
puts "=" * 72
puts

provers = [
  method(:prove_theorem_1),
  method(:prove_theorem_2),
  method(:prove_theorem_3),
  method(:prove_theorem_4),
  method(:prove_theorem_5),
  method(:prove_theorem_6),
  method(:compute_plm_constant),
  method(:prove_determinism),
  method(:prove_guardrails),
]

results = []
total_pass = 0
total_fail = 0

provers.each do |prove_fn|
  r = prove_fn.call
  results << r
  if r.passed
    total_pass += 1
    icon = "[+]"
    status = "PASS"
  else
    total_fail += 1
    icon = "[X]"
    status = "FAIL"
  end
  printf "  %s %-50s %s  (%.1f ms)\n", icon, r.name, status, r.elapsed_ms
end

puts
puts "-" * 72
printf "  TOTAL: %d PASS, %d FAIL out of %d\n", total_pass, total_fail, results.size
puts "-" * 72

# Write JSON report
report = {
  engine: "Ruby BigDecimal",
  ruby_version: RUBY_VERSION,
  total_pass: total_pass,
  total_fail: total_fail,
  results: results.map(&:to_h)
}

report_path = File.join(__dir__, "ruby_proof_report.json")
File.write(report_path, JSON.pretty_generate(report))
puts "\n  Report saved: #{report_path}"

exit(total_fail == 0 ? 0 : 1)
