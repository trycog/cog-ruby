# frozen_string_literal: true

module CogRuby
  module CLI
    module_function

    def parse(args)
      file_paths = []
      output_path = nil
      i = 0

      while i < args.length
        if args[i] == '--output' && i + 1 < args.length
          output_path = args[i + 1]
          i += 2
        else
          file_paths << args[i]
          i += 1
        end
      end

      return unless !file_paths.empty? && output_path

      { file_paths: file_paths, output_path: output_path }
    end
  end
end
