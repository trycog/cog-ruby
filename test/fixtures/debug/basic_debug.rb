# frozen_string_literal: true

# Accumulates a sum from an array of numbers.
# Debug target: set breakpoint inside the loop, inspect `total` and `n`.
def accumulate(numbers)
  total = 0
  numbers.each do |n|
    total += n
  end
  total
end

result = accumulate([1, 2, 3, 4, 5])
puts "Result: #{result}"
