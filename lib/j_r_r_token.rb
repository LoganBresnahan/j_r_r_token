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

  # Raised with `special_tokens: :raise` when the text contains a special-token string
  # such as "<|endoftext|>".
  class SpecialTokenError < ArgumentError; end

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
  #
  # == Special tokens
  #
  # `count`, `encode` and `truncate` take `special_tokens:`, which controls what happens
  # when the text contains a special-token string such as "<|endoftext|>":
  #
  # - `:text` (default): treat it as ordinary text. Right for user-supplied input.
  # - `:allow`: encode it as the single special token.
  # - `:raise`: raise JRRToken::SpecialTokenError.
  class Tokenizer
    ENCODINGS = %w[o200k_harmony o200k_base cl100k_base p50k_base p50k_edit r50k_base].freeze
    SPECIAL_TOKEN_MODES = %i[text allow raise].freeze

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
      def count(text, model:, special_tokens: :text)
        for_model(model).count(text, special_tokens: special_tokens)
      end

      # @return [Array<Integer>] the token ids for `text`
      def encode(text, model:, special_tokens: :text)
        for_model(model).encode(text, special_tokens: special_tokens)
      end

      # @return [String] `text` cut at a token boundary to fit `max_tokens` tokens
      def truncate(text, max_tokens:, model:, special_tokens: :text)
        for_model(model).truncate(text, max_tokens: max_tokens, special_tokens: special_tokens)
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
    # @param special_tokens [Symbol] :text (default), :allow or :raise; see the class docs
    # @return [Integer]
    # @raise [JRRToken::SpecialTokenError] with `special_tokens: :raise`
    def count(text, special_tokens: :text)
      text = text.to_s
      _count(text, allow_special?(text, special_tokens))
    end

    # Encodes `text` (converted with #to_s) into token ids.
    #
    # @param special_tokens [Symbol] :text (default), :allow or :raise; see the class docs
    # @return [Array<Integer>]
    # @raise [JRRToken::SpecialTokenError] with `special_tokens: :raise`
    def encode(text, special_tokens: :text)
      text = text.to_s
      _encode(text, allow_special?(text, special_tokens))
    end

    # Returns `text` (converted with #to_s) cut at a token boundary: the text of its first
    # `max_tokens` tokens (fewer if needed to stay within budget), dropping a trailing
    # character the cut would split. The result is always a prefix of the input, valid
    # UTF-8, and `count(result, special_tokens:)` is at most `max_tokens`. Text that
    # already fits is returned unchanged. It is not necessarily the longest prefix that
    # fits. Runs in time linear in the length of `text` (one full encode).
    #
    # @param max_tokens [Integer] a non-negative token budget
    # @param special_tokens [Symbol] :text (default), :allow or :raise; see the class docs
    # @return [String]
    # @raise [JRRToken::SpecialTokenError] with `special_tokens: :raise`
    def truncate(text, max_tokens:, special_tokens: :text)
      raise TypeError, "max_tokens must be an Integer, got #{max_tokens.class}" unless max_tokens.is_a?(Integer)
      raise ArgumentError, "max_tokens must be non-negative, got #{max_tokens}" if max_tokens.negative?

      text = text.to_s
      _truncate(text, max_tokens, allow_special?(text, special_tokens))
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

    # Validates the `special_tokens:` mode, enforces :raise, and returns whether special
    # tokens should be encoded as such.
    def allow_special?(text, mode)
      unless SPECIAL_TOKEN_MODES.include?(mode)
        raise ArgumentError, "special_tokens must be one of :text, :allow or :raise, got #{mode.inspect}"
      end

      if mode == :raise
        token = _find_special(text)
        if token
          raise SpecialTokenError,
                "Text contains the special token #{token.inspect}. Pass special_tokens: :text " \
                "to treat it as plain text, or special_tokens: :allow to encode it as a special token."
        end
      end

      mode == :allow
    end

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
