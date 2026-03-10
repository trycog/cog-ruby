# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/cog_ruby'

class CogRubyAnalyzerTest < Minitest::Test
  def analyze(source)
    CogRuby::Analyzer.new(source, 'test_app', 'lib/test.rb').analyze
  end

  def find_symbol(doc, display_name)
    doc.symbols.find { |sym| sym.display_name == display_name }
  end

  def test_attaches_import_relationships
    doc = analyze(<<~RUBY)
      require_relative "other"

      class Greeter
        def call
          greet
        end

        def greet
          :ok
        end
      end
    RUBY

    greeter = find_symbol(doc, 'Greeter')
    refute_nil greeter
    assert(greeter.relationships.any? { |rel| rel.kind == 'imports' })
  end

  def test_attaches_call_relationships
    doc = analyze(<<~RUBY)
      class Greeter
        def call
          greet
        end

        def greet
          :ok
        end
      end
    RUBY

    call_method = find_symbol(doc, 'call/0')
    refute_nil call_method
    assert(call_method.relationships.any? { |rel| rel.kind == 'calls' })
  end
end
