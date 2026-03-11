# frozen_string_literal: true

$app_name = "registry"

class Registry
  @@instances = []

  class << self
    def register(item)
      @@instances << item
      @@instances
    end

    def all
      @@instances
    end
  end

  def initialize(name)
    @name = name
  end
end
