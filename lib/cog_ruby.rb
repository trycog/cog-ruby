# frozen_string_literal: true

require_relative 'cog_ruby/scip'
require_relative 'cog_ruby/protobuf'
require_relative 'cog_ruby/symbol'
require_relative 'cog_ruby/workspace'
require_relative 'cog_ruby/scope'
require_relative 'cog_ruby/cli'
require_relative 'cog_ruby/analyzer'

module CogRuby
  VERSION = '0.1.0'

  def self.main(args)
    parsed = CLI.parse(args)

    unless parsed
      warn 'Usage: cog-ruby --output <output_path> <file_path> [file_path ...]'
      exit 1
    end

    file_paths = parsed[:file_paths]
    output_path = parsed[:output_path]

    results = analyze_files(file_paths)
    documents = results.map { |result| result[:document] }
    workspace_root = results.first&.fetch(:workspace_root, default_project_root) || default_project_root

    index = Scip::Index.new(
      metadata: Scip::Metadata.new(
        version: 0,
        tool_info: Scip::ToolInfo.new(
          name: 'cog-ruby',
          version: VERSION,
          arguments: args
        ),
        project_root: "file://#{workspace_root}",
        text_document_encoding: 1
      ),
      documents: documents,
      external_symbols: []
    )

    data = Protobuf.encode_index(index)
    File.binwrite(output_path, data)
  end

  def self.analyze_files(file_paths)
    queue = Queue.new

    threads = file_paths.map do |file_path|
      Thread.new do
        queue << analyze_file(file_path)
      rescue StandardError => e
        log_warning("task crashed while indexing #{file_path}: #{e.message}")
        queue << failed_result(file_path)
      end
    end

    results = file_paths.length.times.map do
      result = queue.pop
      emit_progress(result[:status], result[:document].relative_path)
      result
    end

    threads.each(&:join)
    results
  end

  def self.analyze_file(file_path)
    abs_input = File.expand_path(file_path)
    workspace_root = Workspace.find_root(abs_input)
    project_name = Workspace.discover_project_name(workspace_root)
    relative_path = abs_input.sub("#{workspace_root}/", '')

    unless File.exist?(abs_input)
      log_warning("skipping missing file: #{abs_input}")
      return build_result(workspace_root, empty_document(relative_path), :error)
    end

    source = File.read(abs_input)
    analyzer = Analyzer.new(source, project_name, relative_path)
    document = analyzer.analyze
    build_result(workspace_root, document, :ok)
  rescue StandardError => e
    log_warning("failed to index #{relative_path || file_path}: #{e.message}")
    build_result(workspace_root || default_project_root, empty_document(relative_path || file_path), :error)
  end

  def self.build_result(workspace_root, document, status)
    { workspace_root: workspace_root, document: document, status: status }
  end

  def self.failed_result(file_path)
    build_result(default_project_root, empty_document(file_path), :error)
  end

  def self.empty_document(relative_path)
    Scip::Document.new(language: 'ruby', relative_path: relative_path, occurrences: [], symbols: [])
  end

  def self.emit_progress(status, path)
    event = status == :ok ? 'file_done' : 'file_error'
    warn %({"type":"progress","event":"#{event}","path":"#{escape_json(path)}"})
  end

  def self.escape_json(value)
    value.to_s.gsub('\\', '\\\\').gsub('"', '\\"').gsub("\n", '\\n').gsub("\r", '\\r').gsub("\t", '\\t')
  end

  def self.log_warning(message)
    warn "Warning: #{message}"
  end

  def self.default_project_root
    Dir.pwd
  end
end
