# frozen_string_literal: true

# Serializable mixin for converting objects to hashes
module Serializable
  def to_h
    {}
  end
end

class Model
  include Serializable

  attr_accessor :name
  attr_reader :id
  attr_writer :email

  def initialize(id, name, email)
    @id = id
    @name = name
    @email = email
  end

  def display
    label = "#{@name} (#{@id})"
    label
  end
end
