# coding: utf-8

module Stoplight
  class Light
    # @return [Array<Exception>]
    attr_reader :allowed_errors

    # @return [Proc]
    attr_reader :code

    # @return [String]
    attr_reader :name

    # @param name [String]
    # @yield []
    def initialize(name, &code)
      @allowed_errors = []
      @code = code.to_proc
      @name = name.to_s
    end

    # @return [Object]
    # @raise [Error::NoFallback]
    # @see #fallback
    # @see #green?
    def run
      sync_settings

      if green?
        run_code
      else
        run_fallback
      end
    end

    # Fluent builders

    # @param allowed_errors [Array<Exception>]
    # @return [self]
    def with_allowed_errors(allowed_errors)
      @allowed_errors = allowed_errors.to_a
      self
    end

    # @yield []
    # @return [self]
    def with_fallback(&fallback)
      @fallback = fallback.to_proc
      self
    end

    # @param threshold [Integer]
    # @return [self]
    def with_threshold(threshold)
      Stoplight.data_store.set_threshold(name, threshold.to_i)
      self
    end

    # Attribute readers

    # @return [Object]
    # @raise [Error::NoFallback]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::NoFallback
    end

    # @return (see Stoplight.green?)
    def green?
      Stoplight.green?(name)
    end

    # @return (see Stoplight.red?)
    def red?
      !green?
    end

    # @return (see Stoplight.threshold)
    def threshold
      Stoplight.threshold(name)
    end

    private

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def run_code
      result = code.call
      Stoplight.data_store.clear_failures(name)
      result
    rescue => error
      if error_allowed?(error)
        Stoplight.data_store.clear_failures(name)
      else
        Stoplight.data_store.record_failure(name, error)
      end

      raise
    end

    def run_fallback
      Stoplight.data_store.record_attempt(name)
      fallback.call
    end

    def sync_settings
      Stoplight.data_store.set_threshold(name, threshold)
    end
  end
end
