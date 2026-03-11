# frozen_string_literal: true

module Foo
  module Bar
    class Baz
      def deep_method
        depth = 3
        depth
      end
    end
  end
end

# Path-style constant declaration
class Foo::Bar::Qux
  def path_method
    label = "qux"
    label
  end
end
