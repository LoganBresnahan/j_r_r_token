# frozen_string_literal: true

RSpec.describe "JRRToken::Tokenizer special_tokens: and #truncate" do
  let(:tokenizer) { JRRToken::Tokenizer }
  let(:o200k) { tokenizer.for_model("gpt-4o") }
  let(:harmony) { tokenizer.for_model("gpt-oss-20b") }
  let(:eot) { "<|endoftext|>" }

  describe "special_tokens:" do
    it "defaults to :text, encoding special-token strings as ordinary text" do
      expect(o200k.encode(eot)).to eq(o200k.encode(eot, special_tokens: :text))
      expect(o200k.encode(eot)).to eq([27, 91, 419, 1440, 919, 91, 29])
      expect(o200k.count(eot)).to eq(7)
    end

    it "round-trips special-token strings through :text encoding" do
      text = "before #{eot} after"
      expect(o200k.decode(o200k.encode(text))).to eq(text)
    end

    it "encodes special-token strings as special tokens with :allow" do
      expect(o200k.encode(eot, special_tokens: :allow)).to eq([199_999])
      expect(o200k.count(eot, special_tokens: :allow)).to eq(1)
      expect(o200k.decode(o200k.encode(eot, special_tokens: :allow))).to eq(eot)
    end

    it "gives identical results in every mode for text without special tokens" do
      text = "The quick brown fox jumps over the lazy dog. 🚀"
      results = tokenizer::SPECIAL_TOKEN_MODES.map { |mode| o200k.encode(text, special_tokens: mode) }
      expect(results.uniq.size).to eq(1)
    end

    describe ":raise" do
      it "raises SpecialTokenError naming the token" do
        expect { o200k.count("hi #{eot}", special_tokens: :raise) }
          .to raise_error(JRRToken::SpecialTokenError, /"<\|endoftext\|>"/)
        expect { o200k.encode("hi #{eot}", special_tokens: :raise) }
          .to raise_error(JRRToken::SpecialTokenError)
      end

      it "detects any of the encoding's special tokens" do
        expect { harmony.count("x <|reserved_200500|> y", special_tokens: :raise) }
          .to raise_error(JRRToken::SpecialTokenError, /reserved_200500/)
      end

      it "only flags tokens that are special in that encoding" do
        expect { tokenizer.for_model("gpt-4").count("<|start|>", special_tokens: :raise) }.not_to raise_error
        expect { harmony.count("<|start|>", special_tokens: :raise) }.to raise_error(JRRToken::SpecialTokenError)
      end

      it "counts normally when no special token is present" do
        expect(o200k.count("hello world", special_tokens: :raise)).to eq(2)
      end

      it "is an ArgumentError" do
        expect(JRRToken::SpecialTokenError.ancestors).to include(ArgumentError)
      end
    end

    it "rejects unknown modes" do
      expect { o200k.count("hi", special_tokens: :bogus) }
        .to raise_error(ArgumentError, /must be one of :text, :allow or :raise, got :bogus/)
      expect { o200k.count("hi", special_tokens: "allow") }.to raise_error(ArgumentError)
    end

    it "is supported by the class-level shortcuts" do
      expect(tokenizer.count(eot, model: "gpt-4o", special_tokens: :allow)).to eq(1)
      expect(tokenizer.encode(eot, model: "gpt-4o", special_tokens: :allow)).to eq([199_999])
      expect { tokenizer.count(eot, model: "gpt-4o", special_tokens: :raise) }.to raise_error(JRRToken::SpecialTokenError)
    end
  end

  describe "#truncate" do
    let(:text) { "The quick brown fox jumps over the lazy dog. 🚀🚀🚀 日本語のテキスト" }

    it "returns a valid-UTF-8 prefix within the budget for every budget" do
      # Note: not necessarily the *longest* fitting prefix; it cuts at a token boundary of
      # the full text's encoding (tiktoken's decode(encode(text)[:n]) idiom).
      tokenizer::ENCODINGS.each do |encoding|
        instance = tokenizer.for_model(encoding)
        (0..instance.count(text) + 1).each do |max|
          result = instance.truncate(text, max_tokens: max)
          expect(result).to be_valid_encoding
          expect(text).to start_with(result)
          expect(instance.count(result)).to be <= max
        end
      end
    end

    it "returns the full text when it already fits" do
      expect(o200k.truncate(text, max_tokens: o200k.count(text))).to eq(text)
      expect(o200k.truncate(text, max_tokens: 10_000)).to eq(text)
    end

    it "drops a character that the cut would split" do
      rocket = o200k.encode("🚀")
      expect(rocket.length).to be > 1
      expect(o200k.truncate("🚀", max_tokens: rocket.length - 1)).to eq("")
    end

    it "returns an empty string for max_tokens: 0" do
      expect(o200k.truncate(text, max_tokens: 0)).to eq("")
    end

    it "keeps as many tokens as fit" do
      expect(o200k.truncate("hello world", max_tokens: 1)).to eq("hello")
    end

    it "respects special_tokens:" do
      special = "#{eot}#{eot}hello"
      expect(o200k.truncate(special, max_tokens: 2, special_tokens: :allow)).to eq("#{eot}#{eot}")
      expect(o200k.truncate(special, max_tokens: 2)).to eq("<|")
      expect { o200k.truncate(special, max_tokens: 2, special_tokens: :raise) }
        .to raise_error(JRRToken::SpecialTokenError)
    end

    it "validates max_tokens" do
      expect { o200k.truncate(text, max_tokens: -1) }.to raise_error(ArgumentError, /non-negative/)
      expect { o200k.truncate(text, max_tokens: 1.5) }.to raise_error(TypeError, /Integer/)
      expect { o200k.truncate(text, max_tokens: nil) }.to raise_error(TypeError)
    end

    it "converts non-String text with #to_s" do
      expect(o200k.truncate(1_234_567, max_tokens: 1)).to eq("123")
    end

    it "is supported by the class-level shortcut" do
      expect(tokenizer.truncate("hello world", max_tokens: 1, model: "gpt-4o")).to eq("hello")
    end

    it "raises RuntimeError (not fatal) when the tokenizer regex fails" do
      expect { o200k.truncate(" " * 1_000_000 + "x", max_tokens: 5) }
        .to raise_error(RuntimeError, /Could not encode string/)
    end
  end
end
