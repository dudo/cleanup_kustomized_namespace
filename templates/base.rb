# frozen_string_literal: true

require 'yaml'

module Templates
  class Base
    attr_reader :namespace, :options

    def initialize(namespace:, **options)
      @namespace = namespace
      @options = options
    end

    def manifest
      {}
    end

    def file_name
      self.class::NAME
    end

    def directory
      []
    end

    def path
      "#{directory.push(file_name).join('/')}.yaml"
    end
  end
end
