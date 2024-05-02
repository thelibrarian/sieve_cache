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

    attr_reader :default_proc

    # The +capacity+ is the maximum number of items that
    # will be stored in the cache.
    def initialize(capacity, &block)
      @mutex = Thread::Mutex.new
      @capacity = capacity
      @lookup = {}
      @head = nil
      @tail = nil
      @hand = nil
      @default_proc = block if block_given?
    end

    # Sets the default `proc` called when querying the cache with a key that does not (yet)
    # exist. The proc should expect a single argument, which is the key that was passed
    # in to the original request.
    def default_proc=(newproc)
      raise TypeError, "wrong default_proce type #{newproc.class} (expected Proc)" unless newproc.instance_of?(Proc)

      @default_proc = newproc
    end

    # Store +value+ in the cache using +key+ as the lookup key. If the cache is
    # full, carries out the cache eviction process to free up a slot.
    def store(key, value)
      @mutex.synchronize do
        evict if size == @capacity
        n = Node.new(key: key, value: value, visited: false, next: @head)
        @head.prev = n unless @head.nil?
        @head = n
        @hand = @tail = n if @tail.nil?
        @lookup[key] = n
      end
    end

    alias []= store

    # Returns the value associated with the given +key+, if found.
    #
    # If +key+ is not found, and `default_proc` is not nil, then default_proc
    # will be called with +key+ as its argument. The result is stored in the
    # cache and returned.
    #
    # Otherwise, returns `nil`
    def [](key)
      if default_proc
        fetch(key, &default_proc)
      else
        fetch(key)
      end
    rescue KeyError
      nil
    end

    # Fetch a cached value from the cache, if it exists.
    #
    # If +key+ is not found, and block is provied, then the block will be called
    # with +key+ as its argument. The result is stored in the cache and returned.
    #
    # If +key+ is not found, and no block is provided, a `KeyError` is raised.
    def fetch(key, &block)
      node = @lookup[key]
      raise KeyError, "key not found: #{key}" unless node || block_given?

      if node.nil?
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
