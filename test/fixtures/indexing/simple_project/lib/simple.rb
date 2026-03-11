# frozen_string_literal: true

# Greeter module for simple project testing
module Greeter
  DEFAULT_GREETING = "Hello"

  # A person with a name and age
  class Person
    SPECIES = "Homo sapiens"

    def initialize(name, age = 0)
      @name = name
      @age = age
    end

    def greet
      message = "#{DEFAULT_GREETING}, #{@name}"
      message
    end

    def info
      result = "#{@name}, age #{@age}"
      result
    end
  end
end
