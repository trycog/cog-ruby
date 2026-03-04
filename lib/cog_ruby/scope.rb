# frozen_string_literal: true

module CogRuby
  class Scope
    attr_reader :type, :name, :symbol, :locals

    # Scope types: :top_level, :module, :class, :singleton_class, :method, :block
    def initialize(type:, name:, symbol:)
      @type = type
      @name = name
      @symbol = symbol
      @locals = {}
    end

    def define_local(name, local_symbol)
      @locals[name] = local_symbol
    end

    def lookup_local(name)
      @locals[name]
    end
  end

  class ScopeStack
    attr_reader :stack

    def initialize
      @stack = []
    end

    def push(type:, name:, symbol:)
      @stack.push(Scope.new(type: type, name: name, symbol: symbol))
    end

    def pop
      @stack.pop
    end

    def current
      @stack.last
    end

    def current_symbol
      current&.symbol || ""
    end

    def current_module_name
      # Walk the stack from top to find the enclosing module/class name
      @stack.reverse_each do |scope|
        if scope.type == :module || scope.type == :class || scope.type == :singleton_class
          return scope.name
        end
      end
      ""
    end

    def enclosing_symbol
      current_symbol
    end

    def lookup_local(name)
      # Search from innermost scope outward
      @stack.reverse_each do |scope|
        if (sym = scope.lookup_local(name))
          return sym
        end
      end
      nil
    end

    def define_local(name, symbol)
      current&.define_local(name, symbol)
    end

    def empty?
      @stack.empty?
    end
  end
end
