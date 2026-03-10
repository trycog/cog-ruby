# frozen_string_literal: true

require 'json'

require_relative 'cog_ruby/scip'
require_relative 'cog_ruby/protobuf'
require_relative 'cog_ruby/symbol'
require_relative 'cog_ruby/workspace'
require_relative 'cog_ruby/scope'
require_relative 'cog_ruby/cli'
require_relative 'cog_ruby/analyzer'

module CogRuby
  VERSION = '0.1.0'
  WATCHDOG_INTERVAL = 5

  def self.main(args)
    parsed = CLI.parse(args)

    unless parsed
      warn 'Usage: cog-ruby --output <output_path> <file_path> [file_path ...]'
      exit 1
    end

    file_paths = parsed[:file_paths]
    output_path = parsed[:output_path]

    debug_log('index_start', files: file_paths.length, output_path: output_path, memory: memory_snapshot)

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
    debug_log('index_done', files: results.length, documents: documents.length, memory: memory_snapshot)
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
    started_at = monotonic_time
    abs_input = File.expand_path(file_path)
    workspace_root = Workspace.find_root(abs_input)
    project_name = Workspace.discover_project_name(workspace_root)
    relative_path = abs_input.sub("#{workspace_root}/", '')
    debug_log('file_start', path: relative_path, abs_path: abs_input, size_bytes: file_size(abs_input),
                            memory: memory_snapshot)
    watchdog = start_watchdog(relative_path, abs_input, started_at)

    unless File.exist?(abs_input)
      log_warning("skipping missing file: #{abs_input}")
      stop_watchdog(watchdog, relative_path, :error)
      return build_result(workspace_root, empty_document(relative_path), :error)
    end

    read_started_at = monotonic_time
    source = File.read(abs_input)
    debug_log('stage_finish', path: relative_path, stage: 'read_file', elapsed_ms: elapsed_ms(read_started_at),
                              bytes: source.bytesize, memory: memory_snapshot)

    analyze_started_at = monotonic_time
    analyzer = Analyzer.new(source, project_name, relative_path)
    document = analyzer.analyze
    debug_log('stage_finish', path: relative_path, stage: 'analyze', elapsed_ms: elapsed_ms(analyze_started_at),
                              symbols: document.symbols.length, occurrences: document.occurrences.length, memory: memory_snapshot)
    stop_watchdog(watchdog, relative_path, :ok)
    debug_log('file_done', path: relative_path, elapsed_ms: elapsed_ms(started_at), memory: memory_snapshot)
    build_result(workspace_root, document, :ok)
  rescue StandardError => e
    log_warning("failed to index #{relative_path || file_path}: #{e.message}")
    stop_watchdog(watchdog, relative_path || file_path, :error) if defined?(watchdog)
    if defined?(started_at)
      debug_log('file_error', path: relative_path || file_path, error: e.message, elapsed_ms: elapsed_ms(started_at),
                              memory: memory_snapshot)
    end
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

  def self.debug_enabled?
    %w[1 true TRUE yes YES].include?(ENV['COG_RUBY_DEBUG'])
  end

  def self.debug_log(event, payload = {})
    return unless debug_enabled?

    warn(JSON.generate(payload.merge(type: 'debug', event: event, pid: Process.pid)))
  end

  def self.start_watchdog(path, abs_path, started_at)
    return unless debug_enabled?

    Thread.new do
      loop do
        sleep WATCHDOG_INTERVAL
        break if Thread.current[:stop]

        debug_log('file_still_running', path: path, abs_path: abs_path, elapsed_ms: elapsed_ms(started_at),
                                        memory: memory_snapshot)
      end
    end
  end

  def self.stop_watchdog(thread, path, status)
    return unless thread

    thread[:stop] = true
    debug_log('file_finish', path: path, status: status, memory: memory_snapshot)
  end

  def self.monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end

  def self.elapsed_ms(started_at)
    monotonic_time - started_at
  end

  def self.file_size(path)
    File.exist?(path) ? File.size(path) : nil
  rescue StandardError
    nil
  end

  def self.memory_snapshot
    gc = GC.stat
    {
      rss_kb: current_rss_kb,
      heap_live_slots: gc[:heap_live_slots],
      heap_free_slots: gc[:heap_free_slots],
      total_allocated_objects: gc[:total_allocated_objects],
      total_freed_objects: gc[:total_freed_objects],
      malloc_increase_bytes: gc[:malloc_increase_bytes],
      old_objects: gc[:old_objects]
    }
  end

  def self.current_rss_kb
    status_path = '/proc/self/status'
    return nil unless File.exist?(status_path)

    line = File.readlines(status_path, chomp: true).find { |entry| entry.start_with?('VmRSS:') }
    line&.split&.[](1)&.to_i
  rescue StandardError
    nil
  end

  def self.default_project_root
    Dir.pwd
  end
end
