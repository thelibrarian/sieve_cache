# frozen_string_literal: true

require 'forwardable'

module SieveCache
  # A thread-safe general-purpose fixed-size cache that uses the SIEVE eviction
  # algorithm for evicting old cache items.
  #
  # Works much like a Hash where items are looked up by key, returning `nil` if
  # there is a cache miss.
  class Cache
    extend Forwardable

    Node = Struct.new('Node', :key, :value, :visited, :prev, :next) # :nodoc:

    def_delegators :@lookup, :empty?, :size, :length, :include?, :key?, :has_key?, :member?, :keys

    # The +capacity+ is the maximum number of items that
    # will be stored in the cache.
    def initialize(capacity)
      @capacity = capacity
      @lookup = {}
      @head = nil
      @tail = nil
      @hand = nil
    end

    # Store an item in the cache.
    # Raises an error if the cache is at capacity. Does not carry out any
    # eviction process.
    # +key+ - the identifier used to find the value in the cache in future
    # +value+ - the data to be stored in the cache
    def store(key, value)
      raise StandardError, 'Unable to store item, cache is full' if size >= @capacity

      n = Node.new(key: key, value: value, visited: false, next: @head)
      @head.prev = n unless @head.nil?
      @head = n
      if @tail.nil?
        @tail = n
        @hand = n
      end
      @lookup[key] = n
    end

    # Fetch a cached value from the cache, if it exists.
    #
    # If the key does not exist in the cache, it will execute the provided
    # +block+ and store the return value against the +key+, carrying out the
    # eviction process if the cache is at capacity. Otherwise, +nil+ is returned.
    def fetch(key, &block)
      raise KeyError, "key not found: #{key}" unless @lookup.key?(key) || block_given?

      node = @lookup[key]
      if node.nil?
        evict if count == @capacity
        node = store(key, block.call(key))
      else
        node.visited = true
      end
      node.value
    end

    private

    def evict
      while @hand&.visited
        @hand.visited = false
        @hand = @hand.prev || @tail
      end
      delist_hand
      @lookup.delete(@hand.key) unless @hand.nil?
      @hand = @hand&.prev
    end

    def delist_hand
      if @hand&.prev
        @hand.prev.next = @hand.next
      else
        @head = @hand.next
      end
      if @hand&.next
        @hand.next.prev = @hand.prev
      else
        @tail = @hand.prev
      end
    end
  end
end
