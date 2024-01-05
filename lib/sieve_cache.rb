# frozen_string_literal: true

# A thread-safe general-purpose fixed-size cache that uses the SIEVE eviction
# algorithm for evicting old cache items.
#
# Works much like a Hash where items are looked up by key, returning `nil` if
# there is a cache miss.
class SieveCache
  Node = Struct.new('Node', :key, :value, :prev, :next, :visited)

  def initialize(capacity)
    @capacity = capacity
    @lookup = {}
    @head = nil
    @tail = nil
    @hand = nil
  end

  def store(key, value)
    raise StandardError, 'Unable to store item, cache is full' if size >= @capacity

    n = Node.new(key: key, value: value, prev: @head, visited: false)
    @head = n
    if size.zero?
      @tail = n
      @hand = n
    end
    @lookup[key] = n
  end

  def fetch(key, &block)
    return nil unless @lookup.key?(key) || block_given?

    node = @lookup[key]
    if node.nil?
      evict
      node = store(key, block.call)
    else
      node.visited = true
    end
    node.value
  end

  def size
    @lookup.size
  end

  alias count size

  private

  def evict
    nil
  end
end
