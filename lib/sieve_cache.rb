# frozen_string_literal: true

require_relative 'sieve_cache/cache'

# Namespace Module for the SieveCache classes
module SieveCache
  # Creates a new SieveCache::Cache object.
  # The +capacity+ is the maximum number of items that
  # will be stored in the cache.
  def self.new(capacity)
    Cache.new(capacity)
  end
end
