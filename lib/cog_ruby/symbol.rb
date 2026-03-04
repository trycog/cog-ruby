# frozen_string_literal: true

module CogRuby
  module Symbol
    SCHEME  = "file"
    MANAGER = "."
    VERSION = "unversioned"

    SIMPLE_IDENTIFIER = /\A[a-zA-Z0-9_+\-$]+\z/

    module_function

    def module_symbol(package_name, module_name)
      "#{SCHEME} #{MANAGER} #{package_name} #{VERSION} #{escape_identifier(module_name)}#"
    end

    def class_symbol(package_name, class_name)
      module_symbol(package_name, class_name)
    end

    def method_symbol(package_name, owner_name, method_name, arity = 0)
      "#{SCHEME} #{MANAGER} #{package_name} #{VERSION} #{escape_identifier(owner_name)}##{escape_identifier(method_name)}(#{arity})."
    end

    def constant_symbol(package_name, owner_name, const_name)
      "#{SCHEME} #{MANAGER} #{package_name} #{VERSION} #{escape_identifier(owner_name)}##{escape_identifier(const_name)}."
    end

    def field_symbol(package_name, owner_name, field_name)
      "#{SCHEME} #{MANAGER} #{package_name} #{VERSION} #{escape_identifier(owner_name)}##{escape_identifier(field_name)}."
    end

    def local_symbol(index)
      "local #{index}"
    end

    def escape_identifier(name)
      if SIMPLE_IDENTIFIER.match?(name)
        name
      else
        escaped = name.gsub("`", "``")
        "`#{escaped}`"
      end
    end

    def unescape_identifier(name)
      if name.start_with?("`") && name.end_with?("`")
        name[1..-2].gsub("``", "`")
      else
        name
      end
    end
  end
end
