# frozen_string_literal: true

module CogRuby
  module Scip
    # SCIP symbol roles (bitfield)
    ROLE_DEFINITION  = 0x1
    ROLE_IMPORT      = 0x2
    ROLE_WRITE_ACCESS = 0x4
    ROLE_READ_ACCESS = 0x8

    # SCIP symbol kinds
    KIND_CONSTANT  = 8
    KIND_FIELD     = 15
    KIND_FUNCTION  = 17
    KIND_INTERFACE = 21
    KIND_MACRO     = 25
    KIND_MODULE    = 29
    KIND_PARAMETER = 37
    KIND_TYPE      = 54
    KIND_VARIABLE  = 55
    KIND_CLASS     = 5

    Index = Struct.new(:metadata, :documents, :external_symbols, keyword_init: true) do
      def initialize(metadata: nil, documents: [], external_symbols: [])
        super
      end
    end

    Metadata = Struct.new(:version, :tool_info, :project_root, :text_document_encoding, keyword_init: true) do
      def initialize(version: 0, tool_info: nil, project_root: '', text_document_encoding: 1)
        super
      end
    end

    ToolInfo = Struct.new(:name, :version, :arguments, keyword_init: true) do
      def initialize(name: '', version: '', arguments: [])
        super
      end
    end

    Document = Struct.new(:language, :relative_path, :occurrences, :symbols, keyword_init: true) do
      def initialize(language: 'ruby', relative_path: '', occurrences: [], symbols: [])
        super
      end
    end

    Occurrence = Struct.new(:range, :symbol, :symbol_roles, :syntax_kind, :enclosing_range, keyword_init: true) do
      def initialize(range: [], symbol: '', symbol_roles: 0, syntax_kind: 0, enclosing_range: [])
        super
      end
    end

    SymbolInformation = Struct.new(:symbol, :documentation, :relationships, :kind, :display_name, :enclosing_symbol,
                                   keyword_init: true) do
      def initialize(symbol: '', documentation: [], relationships: [], kind: 0, display_name: '', enclosing_symbol: '')
        super
      end
    end

    Relationship = Struct.new(:symbol, :is_reference, :is_implementation, :is_type_definition, :is_definition, :kind,
                              keyword_init: true) do
      def initialize(symbol: '', is_reference: false, is_implementation: false, is_type_definition: false,
                     is_definition: false, kind: '')
        super
      end
    end
  end
end
