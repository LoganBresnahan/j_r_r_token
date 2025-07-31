# frozen_string_literal: true

require_relative "ru_token/version"

begin
  ruby_version = RUBY_VERSION.split('.')[0..1].join('.')
  require "ru_token/#{ruby_version}/ru_token"
rescue LoadError
  begin
    require "ru_token/ru_token"
  rescue LoadError
    warn "Failed to load ru_token native extension."
  end
end

module RuToken
  class Error < StandardError; end

  # This is the main public interface for the gem.
  class Tokenizer
    # Counts tokens for a given text using a specified model name.
    # The underlying Rust extension will handle mapping the model name
    # to the correct tokenizer.
    #
    # @param text [String] The text to tokenize.
    # @param model [String] The name of the model (e.g., "gpt-4o", "gpt-3.5-turbo").
    # @return [Integer] The number of tokens.
    def self.count(text, model:)
      # This calls the `count_tokens` function from our Rust code,
      # passing both the model and the text.
      RuToken.count_tokens(model, text.to_s)
    end
  end
end
