# frozen_string_literal: true

# Divides two numbers with rescue/ensure flow.
# Debug target: trigger ZeroDivisionError, inspect exception in rescue block.
def safe_divide(a, b)
  result = nil
  begin
    result = a / b
  rescue ZeroDivisionError => e
    puts "Error: #{e.message}"
    result = 0
  ensure
    puts "Division attempted: #{a} / #{b}"
  end
  result
end

puts safe_divide(10, 2)
puts safe_divide(10, 0)
