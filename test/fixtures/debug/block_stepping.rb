# frozen_string_literal: true

# Transforms items using a block, capturing intermediate values.
# Debug target: step through .map block, inspect `item` and `doubled` per iteration.
def transform(items)
  results = items.map do |item|
    doubled = item * 2
    doubled
  end
  results
end

output = transform([10, 20, 30])
puts "Output: #{output.inspect}"
