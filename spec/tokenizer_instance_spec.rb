# frozen_string_literal: true

RSpec.describe "JRRToken::Tokenizer instances" do
  let(:tokenizer) { JRRToken::Tokenizer }

  describe ".for_model" do
    {
      "gpt-4o" => "o200k_base",
      "gpt-5.4" => "o200k_base",
      "ft:gpt-4o:org:name:id" => "o200k_base",
      "gpt-oss-20b" => "o200k_harmony",
      "gpt-4" => "cl100k_base",
      "text-embedding-3-small" => "cl100k_base",
      "text-davinci-003" => "p50k_base",
      "text-davinci-edit-001" => "p50k_edit",
      "davinci" => "r50k_base",
      "gpt2" => "r50k_base"
    }.each do |model, encoding|
      it "resolves '#{model}' to #{encoding}" do
        expect(tokenizer.for_model(model).encoding).to eq(encoding)
      end
    end

    JRRToken::Tokenizer::ENCODINGS.each do |encoding|
      it "accepts the bare encoding name '#{encoding}'" do
        expect(tokenizer.for_model(encoding).encoding).to eq(encoding)
      end
    end

    it "returns the same frozen instance for models that share an encoding" do
      instance = tokenizer.for_model("gpt-4o")
      expect(instance).to be_frozen
      expect(tokenizer.for_model("gpt-4.1")).to equal(instance)
      expect(tokenizer.for_model("o200k_base")).to equal(instance)
    end

    it "returns different instances for different encodings" do
      expect(tokenizer.for_model("gpt-4o")).not_to equal(tokenizer.for_model("gpt-4"))
    end

    it "raises ArgumentError for an unsupported model" do
      expect { tokenizer.for_model("my-favorite-model-99") }
        .to raise_error(ArgumentError, "Model 'my-favorite-model-99' not supported.")
    end

    it "raises TypeError for a non-String model" do
      expect { tokenizer.for_model(nil) }.to raise_error(TypeError)
      expect { tokenizer.for_model(:"gpt-4o") }.to raise_error(TypeError)
    end
  end

  describe "construction" do
    it "does not allow building instances directly" do
      expect { tokenizer.new }.to raise_error(NoMethodError)
      expect { tokenizer.allocate }.to raise_error(NoMethodError)
      expect { tokenizer._build("o200k_base") }.to raise_error(NoMethodError)
    end

    it "returns the receiver from dup and clone" do
      instance = tokenizer.for_model("gpt-4o")
      expect(instance.dup).to equal(instance)
      expect(instance.clone).to equal(instance)
      expect(instance.clone(freeze: true)).to equal(instance)
      expect { instance.clone(freeze: false) }.to raise_error(ArgumentError)
      expect { instance.clone(freeze: 1) }.to raise_error(ArgumentError)
    end

    it "returns the same frozen encoding name on every call" do
      instance = tokenizer.for_model("gpt-4o")
      expect(instance.encoding).to be_frozen
      expect(instance.encoding).to equal(instance.encoding)
    end

    it "has a readable inspect" do
      expect(tokenizer.for_model("gpt-4o").inspect).to eq("#<JRRToken::Tokenizer o200k_base>")
    end
  end

  describe "#count" do
    it "matches the class-level shortcut" do
      expect(tokenizer.for_model("gpt-4o").count("Hello world")).to eq(tokenizer.count("Hello world", model: "gpt-4o"))
    end

    it "converts non-String text with #to_s" do
      expect(tokenizer.for_model("gpt-4").count(123)).to eq(1)
    end
  end

  describe "#encode" do
    {
      "gpt-4o" => [24912, 2375],
      "gpt-oss-20b" => [24912, 2375],
      "gpt-4" => [15339, 1917],
      "text-davinci-003" => [31373, 995]
    }.each do |model, ids|
      it "encodes 'hello world' for #{model}" do
        expect(tokenizer.for_model(model).encode("hello world")).to eq(ids)
        expect(tokenizer.encode("hello world", model: model)).to eq(ids)
      end
    end

    it "returns as many ids as #count" do
      text = "The quick brown fox jumps over the lazy dog. 🚀 日本語のテキスト"
      JRRToken::Tokenizer::ENCODINGS.each do |encoding|
        instance = tokenizer.for_model(encoding)
        expect(instance.encode(text).length).to eq(instance.count(text)), encoding
      end
    end

    it "returns an empty array for empty text" do
      expect(tokenizer.for_model("gpt-4o").encode("")).to eq([])
    end
  end

  describe "#decode" do
    texts = [
      "hello world",
      "The quick brown fox jumps over the lazy dog. 🚀",
      "日本語のテキスト, العربية, हिन्दी, ไทย",
      "line one\r\nline two\ttabbed",
      ""
    ]

    JRRToken::Tokenizer::ENCODINGS.each do |encoding|
      it "round-trips text through encode and decode for #{encoding}" do
        instance = tokenizer.for_model(encoding)
        texts.each do |text|
          expect(instance.decode(instance.encode(text))).to eq(text)
        end
      end
    end

    it "matches the class-level shortcut" do
      expect(tokenizer.decode([24912, 2375], model: "gpt-4o")).to eq("hello world")
    end

    it "replaces bytes that don't form valid UTF-8 with U+FFFD" do
      instance = tokenizer.for_model("gpt-4o")
      rocket = instance.encode("🚀")
      expect(rocket.length).to be > 1
      expect(instance.decode(rocket.first(1))).to eq("�")
    end

    it "raises ArgumentError for a token id that is not in the encoding" do
      expect { tokenizer.for_model("gpt-4o").decode([999_999_999]) }
        .to raise_error(ArgumentError, "Invalid token 999999999 for o200k_base.")
    end

    it "raises for token ids that are not non-negative integers" do
      instance = tokenizer.for_model("gpt-4o")
      expect { instance.decode([-1]) }.to raise_error(RangeError)
      expect { instance.decode([2**32]) }.to raise_error(RangeError)
      expect { instance.decode(["a"]) }.to raise_error(TypeError)
    end

    it "rejects non-Integer numerics instead of truncating them" do
      instance = tokenizer.for_model("gpt-4o")
      expect { instance.decode([24912.7]) }.to raise_error(TypeError, /must be Integers, got Float/)
      expect { instance.decode([Rational(24912)]) }.to raise_error(TypeError, /got Rational/)
    end

    it "raises TypeError when not given an array" do
      instance = tokenizer.for_model("gpt-4o")
      expect { instance.decode("x") }.to raise_error(TypeError)
      expect { instance.decode(nil) }.to raise_error(TypeError)
    end
  end

  describe "#decode_bytes" do
    let(:instance) { tokenizer.for_model("gpt-4o") }

    it "returns the exact bytes as a binary String" do
      bytes = instance.decode_bytes(instance.encode("🚀"))
      expect(bytes.encoding).to eq(Encoding::BINARY)
      expect(bytes).to eq("🚀".b)
    end

    it "preserves partial characters so slices can be joined" do
      rocket = instance.encode("🚀")
      joined = instance.decode_bytes(rocket.first(1)) + instance.decode_bytes(rocket.drop(1))
      expect(joined.force_encoding(Encoding::UTF_8)).to eq("🚀")
    end

    it "matches the class-level shortcut" do
      expect(tokenizer.decode_bytes([24912, 2375], model: "gpt-4o")).to eq("hello world".b)
    end

    it "raises the same errors as #decode" do
      expect { instance.decode_bytes([999_999_999]) }.to raise_error(ArgumentError, /Invalid token/)
      expect { instance.decode_bytes("x") }.to raise_error(TypeError)
      expect { instance.decode_bytes([1.5]) }.to raise_error(TypeError)
    end
  end
end
