# frozen_string_literal: true

class Processor
  def transform(items)
    results = []
    items.each do |item|
      doubled = item * 2
      results << doubled
    end
    results
  end

  def with_lambda
    square = ->(x) { x * x }
    square
  end

  def multi_assign
    a, b = 1, 2
    sum = a + b
    sum
  end
end
