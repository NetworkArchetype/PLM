# frozen_string_literal: true
require "bigdecimal"
require "bigdecimal/util"

module PLM
  module_function

  def hex_to_int(hex_str)
    s = hex_str.strip.downcase
    s = s[2..] if s.start_with?("0x")
    raise ArgumentError, "invalid hex" unless s.match?(/\A[0-9a-f]+\z/)
    s.to_i(16)
  end

  def plm_ratio(pi:, lam:, mu:)
    mu = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu.zero?
    BigDecimal(pi.to_s) * BigDecimal(lam.to_s) / mu
  end

  def secret_value(pi:, lam:, mu:, x:, public_hash_hex:, block_size:, crc_decimal:)
    pi = BigDecimal(pi.to_s)
    lam = BigDecimal(lam.to_s)
    mu = BigDecimal(mu.to_s)
    raise ZeroDivisionError, "mu cannot be 0" if mu.zero?

    y = hex_to_int(public_hash_hex)
    c = Integer(block_size) + Integer(crc_decimal)
    raise ArgumentError, "C must be positive" if c <= 0

    numerator = (pi * BigDecimal(y.to_s)) * (lam * BigDecimal(x.to_s))
    denominator = mu * BigDecimal(c.to_s)
    numerator / denominator
  end
end
