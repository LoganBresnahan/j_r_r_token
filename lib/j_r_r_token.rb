# frozen_string_literal: true

require_relative "j_r_r_token/version"

begin
  ruby_version = RUBY_VERSION.split('.')[0..1].join('.')
  require "j_r_r_token/#{ruby_version}/j_r_r_token"
rescue LoadError
  begin
    require "j_r_r_token/j_r_r_token"
  rescue LoadError => e
    raise LoadError, "j_r_r_token native extension failed to load: #{e.message}"
  end
end

module JRRToken
  class Error < StandardError; end

  # A tokenizer for one encoding (e.g. o200k_base). The class itself is defined by the
  # native extension; this file adds the public Ruby interface.
  #
  #   tok = JRRToken::Tokenizer.for_model("gpt-4o")
  #   tok.encoding               # => "o200k_base"
  #   tok.count("hello world")   # => 2
  #   tok.encode("hello world")  # => [24912, 2375]
  #
  # Every instance method also has a class-level shortcut that takes `model:`:
  #
  #   JRRToken::Tokenizer.count("hello world", model: "gpt-4o")  # => 2
  class Tokenizer
    ENCODINGS = %w[o200k_harmony o200k_base cl100k_base p50k_base p50k_edit r50k_base].freeze

    # One shared, frozen instance per encoding. Instances only hold the encoding; the
    # tokenizer data itself is built lazily on first use and cached process-wide.
    INSTANCES = ENCODINGS.to_h do |name|
      instance = _build(name)
      instance.instance_variable_set(:@encoding, name)
      [name, instance.freeze]
    end.freeze
    private_constant :INSTANCES

    private_class_method :_build, :_encoding_for, :new, :allocate

    class << self
      # Returns the tokenizer for a model name (e.g. "gpt-4o", "ft:gpt-4o:org:name:id")
      # or a bare encoding name (e.g. "o200k_base"). Models that share an encoding return
      # the same frozen instance.
      #
      # @param model [String]
      # @return [JRRToken::Tokenizer]
      # @raise [ArgumentError] if the model is not supported
      def for_model(model)
        INSTANCES.fetch(_encoding_for(model))
      end

      # @return [Integer] the number of tokens in `text`
      def count(text, model:)
        for_model(model).count(text)
      end

      # @return [Array<Integer>] the token ids for `text`
      def encode(text, model:)
        for_model(model).encode(text)
      end

      # @return [String] the text for the token ids
      def decode(tokens, model:)
        for_model(model).decode(tokens)
      end

      # @return [String] the exact bytes for the token ids, as a binary String
      def decode_bytes(tokens, model:)
        for_model(model).decode_bytes(tokens)
      end
    end

    # @return [String] the encoding name, e.g. "o200k_base" (frozen)
    attr_reader :encoding

    # Counts the tokens in `text` (converted with #to_s).
    #
    # @return [Integer]
    def count(text)
      _count(text.to_s)
    end

    # Encodes `text` (converted with #to_s) into token ids.
    #
    # @return [Array<Integer>]
    def encode(text)
      _encode(text.to_s)
    end

    # Decodes token ids back into text. Bytes that don't form valid UTF-8 (for example,
    # a slice of tokens that cuts a multi-byte character in half) become U+FFFD.
    #
    # @param tokens [Array<Integer>]
    # @return [String]
    # @raise [ArgumentError] if a token id is not part of this encoding
    def decode(tokens)
      _decode(token_ids(tokens))
    end

    # Decodes token ids into their exact bytes, returned as a binary (ASCII-8BIT) String.
    # Unlike #decode, nothing is replaced, so partial characters are preserved (useful
    # when joining the output of several token slices before converting to UTF-8).
    #
    # @param tokens [Array<Integer>]
    # @return [String]
    # @raise [ArgumentError] if a token id is not part of this encoding
    def decode_bytes(tokens)
      _decode_bytes(token_ids(tokens))
    end

    # Instances are immutable and shared (one per encoding), so like Integer and Symbol,
    # copying returns the receiver itself.
    def dup
      self
    end

    def clone(freeze: nil)
      unless [nil, true, false].include?(freeze)
        raise ArgumentError, "unexpected value for freeze: #{freeze.class}"
      end
      raise ArgumentError, "can't unfreeze #{self.class.name}" if freeze == false

      self
    end

    def inspect
      "#<#{self.class.name} #{encoding}>"
    end
    alias to_s inspect

    private

    def token_ids(tokens)
      array = Array.try_convert(tokens)
      raise TypeError, "no implicit conversion of #{tokens.class} into Array" unless array
      unless array.all?(Integer)
        bad = array.find { |id| !id.is_a?(Integer) }
        raise TypeError, "token ids must be Integers, got #{bad.class}"
      end

      array
    end
  end
end
