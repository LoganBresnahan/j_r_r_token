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

  # @!method self.context_size(model)
  #   The model's context window in tokens (e.g. 128_000 for "gpt-4o"), or nil if the
  #   model isn't in tiktoken-rs's table. Fine-tuned names ("ft:gpt-4o:org:name:id")
  #   resolve to their base model. Defined by the native extension.
  #
  #   Values come from tiktoken-rs's prefix-matched table as-is, so they can be stale or
  #   loose (e.g. bare "gpt-4-turbo" reports 8,192, "davinci-002" 2,049), and a name can
  #   have a context size without having a tokenizer (e.g. "gpt-6", "o4").
  #
  #   @param model [String]
  #   @return [Integer, nil]
  #   @raise [TypeError] if model is not a String

  # Encodings that chat models use; count_messages only supports these.
  CHAT_ENCODINGS = %w[o200k_harmony o200k_base cl100k_base].freeze
  private_constant :CHAT_ENCODINGS

  # Estimates the prompt tokens for a list of chat messages, including the per-message
  # framing tokens chat models add, using OpenAI's cookbook formula. The constants and the
  # handling of OpenAI-shaped messages mirror tiktoken-rs 0.12.1's num_tokens_from_messages
  # and its async-openai adapter (re-verify on tiktoken-rs bumps). It's an estimate: tool
  # definitions and non-text content (images, audio, files) aren't counted, and providers
  # can change their framing.
  #
  # Each message is a Hash with String or Symbol keys:
  # - "role" (required).
  # - "content": a String, nil, or an Array of content parts. "text" parts are joined and
  #   counted; "refusal" parts are joined and counted as the refusal; "image_url",
  #   "input_audio" and "file" parts are skipped (not counted). Unknown part types raise.
  # - optional "name", "refusal", "function_call" ({name:, arguments:}) and "tool_calls":
  #   an Array of {function: {name:, arguments:}} or {type: "custom", custom: {name:, input:}}
  #   as in the OpenAI API, or flat {name:, arguments:}.
  # - for "tool" messages, "tool_call_id" is counted as the name, as tiktoken-rs does.
  # Other keys are ignored.
  #
  #   JRRToken.count_messages([{role: "user", content: "Hello!"}], model: "gpt-4o")  # => 9
  #
  # @param messages [Array<Hash>]
  # @param model [String] a chat model (o200k_base, o200k_harmony or cl100k_base encoding)
  # @param special_tokens [Symbol] :text (default), :allow or :raise; see Tokenizer
  # @return [Integer]
  # @raise [ArgumentError] for an unsupported model or a malformed message
  def self.count_messages(messages, model:, special_tokens: :text)
    tokenizer = Tokenizer.for_model(model)
    unless CHAT_ENCODINGS.include?(tokenizer.encoding)
      raise ArgumentError, "count_messages supports chat models (o200k_base, o200k_harmony or " \
                           "cl100k_base encodings); '#{model}' uses #{tokenizer.encoding}."
    end
    list = Array.try_convert(messages) or raise TypeError, "messages must be an Array, got #{messages.class}"

    # gpt-3.5-turbo-0301 used different framing (kept for parity with tiktoken-rs).
    per_message, per_name = model == "gpt-3.5-turbo-0301" ? [4, -1] : [3, 1]
    count = ->(text) { tokenizer.count(text, special_tokens: special_tokens) }

    total = 3 # every reply is primed with <|start|>assistant<|message|>
    list.each_with_index do |raw, index|
      message = MessageFields.new(raw, index)
      total += per_message
      total += count.(message.role)
      content, refusal = message.content_and_refusal
      total += count.(content) if content
      if (name = message.name)
        total += count.(name) + per_name
      end
      total += count.(refusal) if refusal
      message.function_calls.each do |function_name, arguments|
        total += count.(function_name) + count.(arguments) + 1
      end
    end
    total
  end

  # Reads a chat message Hash with String or Symbol keys. Internal to count_messages.
  class MessageFields
    NON_TEXT_PARTS = %w[image_url input_audio file].freeze

    def initialize(message, index)
      @index = index
      @message = Hash.try_convert(message) or
        raise TypeError, "message #{index} must be a Hash, got #{message.class}"
    end

    def role
      @role ||= string_field(@message, "role", required: true)
    end

    # The name, or for "tool" messages without one, the tool_call_id (as tiktoken-rs counts it).
    def name
      name = string_field(@message, "name")
      name ||= string_field(@message, "tool_call_id") if role == "tool"
      name
    end

    # [content_text_or_nil, refusal_or_nil]. Text parts are joined with ""; refusal parts are
    # joined and take precedence over a "refusal" field.
    def content_and_refusal
      content = value(@message, "content")
      refusal_field = string_field(@message, "refusal")
      case content
      when nil then [nil, refusal_field]
      when String then [content, refusal_field]
      when Array
        texts = []
        refusals = []
        content.each_with_index do |raw_part, i|
          part = Hash.try_convert(raw_part) or
            raise TypeError, "message #{@index} content part #{i} must be a Hash, got #{raw_part.class}"
          type = string_field(part, "type", required: true, label: "content[#{i}].type")
          case type
          when "text" then texts << string_field(part, "text", required: true, label: "content[#{i}].text")
          when "refusal" then refusals << string_field(part, "refusal", required: true, label: "content[#{i}].refusal")
          when *NON_TEXT_PARTS
            next # not countable as text; skipped, as tiktoken-rs does
          else
            raise ArgumentError, "message #{@index} content part #{i} has unknown type \"#{type}\""
          end
        end
        [join(texts), join(refusals) || refusal_field]
      else
        raise TypeError, "message #{@index} \"content\" must be a String, Array or nil, got #{content.class}"
      end
    end

    # [[name, arguments], ...] from function_call and tool_calls.
    def function_calls
      calls = []
      function_call = value(@message, "function_call")
      calls << function_pair(function_call, "function_call") if function_call
      raw_calls = value(@message, "tool_calls")
      return calls unless raw_calls

      tool_calls = Array.try_convert(raw_calls) or
        raise TypeError, "message #{@index} \"tool_calls\" must be an Array, got #{raw_calls.class}"
      tool_calls.each_with_index do |raw_call, i|
        label = "tool_calls[#{i}]"
        tool_call = Hash.try_convert(raw_call) or
          raise TypeError, "message #{@index} #{label} must be a Hash, got #{raw_call.class}"
        if (custom = value(tool_call, "custom"))
          calls << custom_pair(custom, "#{label}.custom")
        elsif (function = value(tool_call, "function"))
          calls << function_pair(function, "#{label}.function")
        else
          calls << function_pair(tool_call, label)
        end
      end
      calls
    end

    private

    def value(hash, key)
      hash.fetch(key) { hash.fetch(key.to_sym, nil) }
    end

    def string_field(hash, key, required: false, label: key)
      field = value(hash, key)
      if field.nil?
        raise ArgumentError, "message #{@index} is missing \"#{label}\"" if required

        return nil
      end
      raise TypeError, "message #{@index} \"#{label}\" must be a String, got #{field.class}" unless field.is_a?(String)

      field
    end

    def join(texts)
      texts.empty? ? nil : texts.join
    end

    def function_pair(raw_call, label)
      call = hash_for(raw_call, label)
      [string_field(call, "name", required: true, label: "#{label}.name"),
       string_field(call, "arguments", required: true, label: "#{label}.arguments")]
    end

    def custom_pair(raw_call, label)
      call = hash_for(raw_call, label)
      [string_field(call, "name", required: true, label: "#{label}.name"),
       string_field(call, "input", required: true, label: "#{label}.input")]
    end

    def hash_for(raw, label)
      Hash.try_convert(raw) or raise TypeError, "message #{@index} #{label} must be a Hash, got #{raw.class}"
    end
  end
  private_constant :MessageFields

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

      # @return [Array<String>] the text of each token in `text`
      def split(text, model:, special_tokens: :text)
        for_model(model).split(text, special_tokens: special_tokens)
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

    # Splits `text` (converted with #to_s) into the text of each of its tokens, e.g.
    # "hello world" -> ["hello", " world"]. Pieces stay 1:1 with #encode's ids. Bytes of a
    # multi-byte character split across tokens (common for emoji and CJK) are shown as
    # U+FFFD, so joining the pieces doesn't always reproduce `text`; for exact bytes, use
    # `encode(text).map { |id| decode_bytes([id]) }`.
    #
    # @param special_tokens [Symbol] :text (default), :allow or :raise; see the class docs
    # @return [Array<String>]
    # @raise [JRRToken::SpecialTokenError] with `special_tokens: :raise`
    def split(text, special_tokens: :text)
      text = text.to_s
      _split(text, allow_special?(text, special_tokens))
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
