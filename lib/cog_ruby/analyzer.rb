# frozen_string_literal: true

require "prism"

module CogRuby
  class Analyzer
    attr_reader :occurrences, :symbols

    def initialize(source, package_name, relative_path)
      @source = source
      @package_name = package_name
      @relative_path = relative_path
      @occurrences = []
      @symbols = []
      @scope_stack = ScopeStack.new
      @local_counter = 0
      @pending_comment = nil
      @seen_methods = {}
      @comment_map = {}
    end

    def analyze
      result = Prism.parse(@source)
      build_comment_map(result.comments)
      visit(result.value)

      Scip::Document.new(
        language: "ruby",
        relative_path: @relative_path,
        occurrences: @occurrences,
        symbols: @symbols
      )
    end

    private

    # --- Comment handling ---

    def build_comment_map(comments)
      comments.each do |comment|
        line = comment.location.start_line
        text = comment.slice
        # Strip leading # and space
        text = text.sub(/\A#\s?/, "")
        @comment_map[line] = text
      end
    end

    def extract_doc_comment(node_line)
      # Look for contiguous comment block immediately preceding the node
      lines = []
      line = node_line - 1
      while @comment_map.key?(line)
        lines.unshift(@comment_map[line])
        line -= 1
      end
      lines.empty? ? [] : [lines.join("\n")]
    end

    # --- Visitor dispatch ---

    def visit(node)
      return unless node.is_a?(Prism::Node)

      case node
      when Prism::ProgramNode
        visit(node.statements)
      when Prism::StatementsNode
        node.body.each { |child| visit(child) }
      when Prism::ModuleNode
        visit_module(node)
      when Prism::ClassNode
        visit_class(node)
      when Prism::SingletonClassNode
        visit_singleton_class(node)
      when Prism::DefNode
        visit_def(node)
      when Prism::ConstantWriteNode
        visit_constant_write(node)
      when Prism::InstanceVariableWriteNode
        visit_ivar_write(node)
      when Prism::ClassVariableWriteNode
        visit_cvar_write(node)
      when Prism::GlobalVariableWriteNode
        visit_gvar_write(node)
      when Prism::LocalVariableWriteNode
        visit_local_var_write(node)
      when Prism::LocalVariableReadNode
        visit_local_var_read(node)
      when Prism::InstanceVariableReadNode
        visit_ivar_read(node)
      when Prism::ClassVariableReadNode
        visit_cvar_read(node)
      when Prism::GlobalVariableReadNode
        visit_gvar_read(node)
      when Prism::ConstantReadNode
        visit_constant_read(node)
      when Prism::ConstantPathNode
        visit_constant_path(node)
      when Prism::CallNode
        visit_call(node)
      when Prism::BlockNode
        visit_block(node)
      when Prism::LambdaNode
        visit_lambda(node)
      when Prism::MultiWriteNode
        visit_multi_write(node)
      else
        visit_children(node)
      end
    end

    def visit_children(node)
      node.child_nodes.compact.each { |child| visit(child) }
    end

    # --- Module ---

    def visit_module(node)
      name = extract_constant_name(node.constant_path)
      full_name = build_qualified_name(name)
      symbol = Symbol.module_symbol(@package_name, full_name)
      range = node_range(node.constant_path)
      doc = extract_doc_comment(node.location.start_line)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
      add_symbol_info(symbol, Scip::KIND_MODULE, full_name, doc)

      @scope_stack.push(type: :module, name: full_name, symbol: symbol)
      visit(node.body) if node.body
      @scope_stack.pop
    end

    # --- Class ---

    def visit_class(node)
      name = extract_constant_name(node.constant_path)
      full_name = build_qualified_name(name)
      symbol = Symbol.class_symbol(@package_name, full_name)
      range = node_range(node.constant_path)
      doc = extract_doc_comment(node.location.start_line)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
      add_symbol_info(symbol, Scip::KIND_CLASS, full_name, doc)

      # Record superclass reference if present
      if node.superclass
        visit(node.superclass)
      end

      @scope_stack.push(type: :class, name: full_name, symbol: symbol)
      visit(node.body) if node.body
      @scope_stack.pop
    end

    # --- Singleton class (class << self) ---

    def visit_singleton_class(node)
      owner = @scope_stack.current_module_name
      full_name = owner.empty? ? "<singleton>" : "#{owner}.<singleton>"
      symbol = Symbol.module_symbol(@package_name, full_name)

      @scope_stack.push(type: :singleton_class, name: owner, symbol: symbol)
      visit(node.body) if node.body
      @scope_stack.pop
    end

    # --- Method definition ---

    def visit_def(node)
      method_name = node.name.to_s
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?

      params = node.parameters
      arity = compute_arity(params)
      symbol = Symbol.method_symbol(@package_name, owner_name, method_name, arity)

      name_loc = node.name_loc
      range = loc_range(name_loc)
      doc = extract_doc_comment(node.location.start_line)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION)

      method_key = "#{owner_name}##{method_name}/#{arity}"
      unless @seen_methods[method_key]
        add_symbol_info(symbol, Scip::KIND_FUNCTION, "#{method_name}/#{arity}", doc)
        @seen_methods[method_key] = true
      end

      @scope_stack.push(type: :method, name: method_name, symbol: symbol)
      visit_parameters(params) if params
      visit(node.body) if node.body
      @scope_stack.pop
    end

    # --- Parameters ---

    def visit_parameters(params)
      params.requireds.each { |p| visit_parameter(p) }
      params.optionals.each { |p| visit_parameter(p) }
      visit_parameter(params.rest) if params.rest
      params.keywords.each { |p| visit_parameter(p) }
      visit_parameter(params.keyword_rest) if params.keyword_rest
      visit_parameter(params.block) if params.block
    end

    def visit_parameter(param)
      case param
      when Prism::RequiredParameterNode
        define_param(param.name.to_s, param.location)
      when Prism::OptionalParameterNode
        define_param(param.name.to_s, param.name_loc)
        visit(param.value)
      when Prism::RestParameterNode
        define_param(param.name.to_s, param.name_loc) if param.name
      when Prism::RequiredKeywordParameterNode
        define_param(param.name.to_s, param.name_loc)
      when Prism::OptionalKeywordParameterNode
        define_param(param.name.to_s, param.name_loc)
        visit(param.value)
      when Prism::KeywordRestParameterNode
        define_param(param.name.to_s, param.name_loc) if param.name
      when Prism::BlockParameterNode
        define_param(param.name.to_s, param.name_loc) if param.name
      when Prism::MultiTargetNode
        # Destructured params — just walk children
        param.lefts.each { |p| visit_parameter(p) }
        visit_parameter(param.rest) if param.rest
        param.rights.each { |p| visit_parameter(p) }
      end
    end

    def define_param(name, loc)
      return if name.empty? || name == "_"
      symbol = Symbol.local_symbol(@local_counter)
      @local_counter += 1
      range = loc_range(loc)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
      add_symbol_info(symbol, Scip::KIND_PARAMETER, name)
      @scope_stack.define_local(name, symbol)
    end

    # --- Constants ---

    def visit_constant_write(node)
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      const_name = node.name.to_s
      symbol = Symbol.constant_symbol(@package_name, owner_name, const_name)
      range = loc_range(node.name_loc)
      doc = extract_doc_comment(node.location.start_line)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
      add_symbol_info(symbol, Scip::KIND_CONSTANT, const_name, doc)

      visit(node.value)
    end

    def visit_constant_read(node)
      const_name = node.name.to_s
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      symbol = Symbol.constant_symbol(@package_name, owner_name, const_name)
      range = node_range(node)

      add_occurrence(range, symbol, 0)
    end

    def visit_constant_path(node)
      begin
        full_name = node.full_name
      rescue
        full_name = node.slice
      end
      symbol = Symbol.module_symbol(@package_name, full_name)
      range = node_range(node)

      add_occurrence(range, symbol, 0)
    end

    # --- Instance variables ---

    def visit_ivar_write(node)
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      ivar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, owner_name, ivar_name)
      range = loc_range(node.name_loc)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION | Scip::ROLE_WRITE_ACCESS)
      add_symbol_info(symbol, Scip::KIND_FIELD, ivar_name)

      visit(node.value)
    end

    def visit_ivar_read(node)
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      ivar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, owner_name, ivar_name)
      range = node_range(node)

      add_occurrence(range, symbol, Scip::ROLE_READ_ACCESS)
    end

    # --- Class variables ---

    def visit_cvar_write(node)
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      cvar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, owner_name, cvar_name)
      range = loc_range(node.name_loc)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION | Scip::ROLE_WRITE_ACCESS)
      add_symbol_info(symbol, Scip::KIND_FIELD, cvar_name)

      visit(node.value)
    end

    def visit_cvar_read(node)
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?
      cvar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, owner_name, cvar_name)
      range = node_range(node)

      add_occurrence(range, symbol, Scip::ROLE_READ_ACCESS)
    end

    # --- Global variables ---

    def visit_gvar_write(node)
      gvar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, "", gvar_name)
      range = loc_range(node.name_loc)

      add_occurrence(range, symbol, Scip::ROLE_DEFINITION | Scip::ROLE_WRITE_ACCESS)
      add_symbol_info(symbol, Scip::KIND_VARIABLE, gvar_name)

      visit(node.value)
    end

    def visit_gvar_read(node)
      gvar_name = node.name.to_s
      symbol = Symbol.field_symbol(@package_name, "", gvar_name)
      range = node_range(node)

      add_occurrence(range, symbol, Scip::ROLE_READ_ACCESS)
    end

    # --- Local variables ---

    def visit_local_var_write(node)
      name = node.name.to_s
      existing = @scope_stack.lookup_local(name)
      if existing
        symbol = existing
        role = Scip::ROLE_WRITE_ACCESS
      else
        symbol = Symbol.local_symbol(@local_counter)
        @local_counter += 1
        @scope_stack.define_local(name, symbol)
        role = Scip::ROLE_DEFINITION
      end

      range = loc_range(node.name_loc)
      add_occurrence(range, symbol, role)
      add_symbol_info(symbol, Scip::KIND_VARIABLE, name) unless existing

      visit(node.value)
    end

    def visit_local_var_read(node)
      name = node.name.to_s
      symbol = @scope_stack.lookup_local(name)
      return unless symbol

      range = node_range(node)
      add_occurrence(range, symbol, Scip::ROLE_READ_ACCESS)
    end

    # --- Call nodes ---

    def visit_call(node)
      method_name = node.name.to_s

      case method_name
      when "attr_reader", "attr_writer", "attr_accessor"
        visit_attr_call(node, method_name)
      when "include", "extend", "prepend"
        visit_mixin_call(node, method_name)
      when "require", "require_relative"
        visit_require_call(node)
      else
        # Visit receiver and arguments normally
        visit(node.receiver) if node.receiver
        visit_arguments(node.arguments) if node.arguments
        visit(node.block) if node.block
      end
    end

    def visit_attr_call(node, method_name)
      return unless node.arguments
      owner_name = @scope_stack.current_module_name
      owner_name = "Object" if owner_name.empty?

      node.arguments.arguments.each do |arg|
        next unless arg.is_a?(Prism::SymbolNode)
        attr_name = arg.value
        ivar_name = "@#{attr_name}"

        # Define the accessor method
        symbol = Symbol.method_symbol(@package_name, owner_name, attr_name, 0)
        range = node_range(arg)
        add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
        add_symbol_info(symbol, Scip::KIND_FUNCTION, "#{attr_name}/0")

        # Also define the ivar
        field_sym = Symbol.field_symbol(@package_name, owner_name, ivar_name)
        add_symbol_info(field_sym, Scip::KIND_FIELD, ivar_name)

        # For writer/accessor, also define the setter
        if method_name == "attr_writer" || method_name == "attr_accessor"
          setter_symbol = Symbol.method_symbol(@package_name, owner_name, "#{attr_name}=", 1)
          add_symbol_info(setter_symbol, Scip::KIND_FUNCTION, "#{attr_name}=/1")
        end
      end
    end

    def visit_mixin_call(node, method_name)
      return unless node.arguments
      node.arguments.arguments.each do |arg|
        case arg
        when Prism::ConstantReadNode, Prism::ConstantPathNode
          mod_name = extract_constant_name(arg)
          symbol = Symbol.module_symbol(@package_name, mod_name)
          range = node_range(arg)
          add_occurrence(range, symbol, Scip::ROLE_IMPORT)
        end
      end
    end

    def visit_require_call(node)
      # Just walk arguments normally — we don't do cross-file resolution
      visit_arguments(node.arguments) if node.arguments
    end

    def visit_arguments(args)
      args.arguments.each { |arg| visit(arg) }
    end

    # --- Blocks ---

    def visit_block(node)
      enclosing = @scope_stack.enclosing_symbol
      block_symbol = "#{enclosing}<block>."
      @scope_stack.push(type: :block, name: "<block>", symbol: block_symbol)

      if node.parameters
        visit_block_parameters(node.parameters)
      end
      visit(node.body) if node.body
      @scope_stack.pop
    end

    def visit_lambda(node)
      enclosing = @scope_stack.enclosing_symbol
      lambda_symbol = "#{enclosing}<lambda>."
      @scope_stack.push(type: :block, name: "<lambda>", symbol: lambda_symbol)

      if node.parameters
        visit_block_parameters(node.parameters)
      end
      visit(node.body) if node.body
      @scope_stack.pop
    end

    def visit_block_parameters(block_params)
      return unless block_params.is_a?(Prism::BlockParametersNode)
      params = block_params.parameters
      return unless params
      visit_parameters(params)
    end

    # --- Multi-write (a, b = 1, 2) ---

    def visit_multi_write(node)
      node.lefts.each do |target|
        case target
        when Prism::LocalVariableTargetNode
          name = target.name.to_s
          symbol = Symbol.local_symbol(@local_counter)
          @local_counter += 1
          @scope_stack.define_local(name, symbol)
          range = node_range(target)
          add_occurrence(range, symbol, Scip::ROLE_DEFINITION)
          add_symbol_info(symbol, Scip::KIND_VARIABLE, name)
        when Prism::InstanceVariableTargetNode
          owner_name = @scope_stack.current_module_name
          owner_name = "Object" if owner_name.empty?
          ivar_name = target.name.to_s
          symbol = Symbol.field_symbol(@package_name, owner_name, ivar_name)
          range = node_range(target)
          add_occurrence(range, symbol, Scip::ROLE_DEFINITION | Scip::ROLE_WRITE_ACCESS)
          add_symbol_info(symbol, Scip::KIND_FIELD, ivar_name)
        end
      end
      visit(node.value) if node.value
    end

    # --- Helpers ---

    def extract_constant_name(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        begin
          node.full_name
        rescue
          node.slice
        end
      else
        node.slice rescue "Unknown"
      end
    end

    def build_qualified_name(name)
      parent = @scope_stack.current_module_name
      if parent.empty?
        name
      elsif name.include?("::")
        # Already qualified
        name
      else
        "#{parent}::#{name}"
      end
    end

    def compute_arity(params)
      return 0 unless params
      count = 0
      count += params.requireds.size
      count += params.optionals.size
      count += 1 if params.rest
      count += params.keywords.size
      count += 1 if params.keyword_rest
      count
    end

    def node_range(node)
      loc = node.location
      start_line = loc.start_line - 1  # 0-indexed
      start_col = loc.start_column
      end_line = loc.end_line - 1
      end_col = loc.end_column

      if start_line == end_line
        [start_line, start_col, end_col]
      else
        [start_line, start_col, end_line, end_col]
      end
    end

    def loc_range(loc)
      return [0, 0, 0] unless loc
      start_line = loc.start_line - 1
      start_col = loc.start_column
      end_line = loc.end_line - 1
      end_col = loc.end_column

      if start_line == end_line
        [start_line, start_col, end_col]
      else
        [start_line, start_col, end_line, end_col]
      end
    end

    def add_occurrence(range, symbol, symbol_roles, syntax_kind: 0, enclosing_range: [])
      @occurrences << Scip::Occurrence.new(
        range: range,
        symbol: symbol,
        symbol_roles: symbol_roles,
        syntax_kind: syntax_kind,
        enclosing_range: enclosing_range
      )
    end

    def add_symbol_info(symbol, kind, display_name, documentation = [], enclosing_symbol: nil)
      enc = enclosing_symbol || @scope_stack.enclosing_symbol
      @symbols << Scip::SymbolInformation.new(
        symbol: symbol,
        kind: kind,
        display_name: display_name,
        documentation: documentation,
        enclosing_symbol: enc
      )
    end
  end
end
