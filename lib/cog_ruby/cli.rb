# frozen_string_literal: true

module CogRuby
  module CLI
    module_function

    def parse(args)
      file_path = nil
      output_path = nil
      i = 0

      while i < args.length
        if args[i] == "--output" && i + 1 < args.length
          output_path = args[i + 1]
          i += 2
        elsif file_path.nil?
          file_path = args[i]
          i += 1
        else
          i += 1
        end
      end

      if file_path && output_path
        { file_path: file_path, output_path: output_path }
      else
        nil
      end
    end
  end
end
