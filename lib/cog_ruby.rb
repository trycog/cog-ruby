# frozen_string_literal: true

require_relative "cog_ruby/scip"
require_relative "cog_ruby/protobuf"
require_relative "cog_ruby/symbol"
require_relative "cog_ruby/workspace"
require_relative "cog_ruby/scope"
require_relative "cog_ruby/cli"
require_relative "cog_ruby/analyzer"

module CogRuby
  VERSION = "0.1.0"

  def self.main(args)
    parsed = CLI.parse(args)

    unless parsed
      $stderr.puts "Usage: cog-ruby <file_path> --output <output_path>"
      exit 1
    end

    input_path = parsed[:file_path]
    output_path = parsed[:output_path]

    abs_input = File.expand_path(input_path)

    unless File.exist?(abs_input)
      $stderr.puts "Error: file not found: #{abs_input}"
      exit 1
    end

    workspace_root = Workspace.find_root(abs_input)
    project_name = Workspace.discover_project_name(workspace_root)
    relative_path = abs_input.sub("#{workspace_root}/", "")

    source = File.read(abs_input)

    analyzer = Analyzer.new(source, project_name, relative_path)
    document = analyzer.analyze

    index = Scip::Index.new(
      metadata: Scip::Metadata.new(
        version: 0,
        tool_info: Scip::ToolInfo.new(
          name: "cog-ruby",
          version: VERSION,
          arguments: args
        ),
        project_root: "file://#{workspace_root}",
        text_document_encoding: 1
      ),
      documents: [document],
      external_symbols: []
    )

    data = Protobuf.encode_index(index)
    File.binwrite(output_path, data)
  end
end
