# frozen_string_literal: true

require_relative "j_r_r_token/version"

begin
  ruby_version = RUBY_VERSION.split('.')[0..1].join('.')
  require "j_r_r_token/#{ruby_version}/j_r_r_token"
rescue LoadError
  begin
    require "j_r_r_token/j_r_r_token"
  rescue LoadError
    warn "Failed to load j_r_r_token native extension."
  end
end

module JRRToken
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
      JRRToken.count_tokens(model, text.to_s)
    end
  end
end
