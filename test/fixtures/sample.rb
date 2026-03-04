# Sample Ruby file for testing
module Foo
  class Bar
    CONST = 42

    attr_reader :name

    # Creates a new Bar
    def initialize(name, age = 0)
      @name = name
      @age = age
    end

    def greet
      message = "Hello, #{@name}"
      message
    end

    class << self
      def create(name)
        new(name)
      end
    end
  end

  module Baz
    include Enumerable

    def each(&block)
      [1, 2, 3].each { |x| block.call(x) }
    end
  end
end
