# frozen_string_literal: true

module CogRuby
  module Workspace
    module_function

    def find_root(path)
      abs_path = File.expand_path(path)
      dir = File.directory?(abs_path) ? abs_path : File.dirname(abs_path)
      walk_up(dir)
    end

    def walk_up(dir)
      # Check for Gemfile first, then gemspec, then .git
      if File.exist?(File.join(dir, "Gemfile"))
        dir
      elsif Dir.glob(File.join(dir, "*.gemspec")).any?
        dir
      elsif File.exist?(File.join(dir, ".git"))
        dir
      elsif dir == "/"
        dir
      else
        parent = File.dirname(dir)
        parent == dir ? dir : walk_up(parent)
      end
    end

    def discover_project_name(workspace_root)
      # Try gemspec first
      gemspecs = Dir.glob(File.join(workspace_root, "*.gemspec"))
      if gemspecs.any?
        content = File.read(gemspecs.first)
        if (match = content.match(/\.name\s*=\s*["']([^"']+)["']/))
          return match[1]
        end
      end

      # Try Gemfile for project name extraction (less reliable)
      gemfile = File.join(workspace_root, "Gemfile")
      if File.exist?(gemfile)
        return File.basename(workspace_root)
      end

      File.basename(workspace_root)
    end

    private_class_method :walk_up
  end
end
