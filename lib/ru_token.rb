# frozen_string_literal: true

require_relative "ru_token/version"

begin
  require "ru_token/ru_token"
rescue LoadError
  warn "Failed to load ru_token native extension."
end

module RuToken
  class Error < StandardError; end

  # A list of models supported by the underlying Rust implementation.
  SUPPORTED_MODELS = %w[o200k_base cl100k_base p50k_base p50k_edit r50k_base].freeze
  DEFAULT_MODEL = "o200k_base".freeze

  # This is the main public interface for the gem.
  class Tokenizer
    # Counts tokens for a given text using a specified model.
    #
    # @param text [String] The text to tokenize.
    # @param model [String] The name of the model to use for tokenization.
    #   Defaults to 'o200k_base'.
    # @return [Integer] The number of tokens.
    def self.count(text, model: DEFAULT_MODEL)
      # This calls the `count_tokens` function from our Rust code,
      # passing both the model and the text.
      RuToken.count_tokens(model, text.to_s)
    end
  end
end
