# frozen_string_literal: true

RSpec.describe "JRRToken::Tokenizer#split and JRRToken.context_size" do
  let(:tokenizer) { JRRToken::Tokenizer }
  let(:o200k) { tokenizer.for_model("gpt-4o") }

  describe "#split" do
    it "returns the text of each token" do
      expect(o200k.split("hello world")).to eq(["hello", " world"])
    end

    it "returns one piece per token, joining back to the text when no character is split" do
      text = "The quick brown fox. 日本語 ok"
      tokenizer::ENCODINGS.each do |encoding|
        instance = tokenizer.for_model(encoding)
        pieces = instance.split(text)
        expect(pieces.length).to eq(instance.count(text)), encoding
        next if pieces.any? { |piece| piece.include?("\uFFFD") } # a character was split across tokens

        expect(pieces.join).to eq(text), encoding
      end
    end

    it "shows tokens that hold part of a multi-byte character as U+FFFD" do
      expect(o200k.split("🚀 hi")).to eq(["�", "�", " hi"])
    end

    it "respects special_tokens:" do
      expect(o200k.split("<|endoftext|>")).to eq(["<", "|", "end", "of", "text", "|", ">"])
      expect(o200k.split("<|endoftext|>", special_tokens: :allow)).to eq(["<|endoftext|>"])
      expect { o200k.split("<|endoftext|>", special_tokens: :raise) }.to raise_error(JRRToken::SpecialTokenError)
    end

    it "returns an empty array for empty text and converts non-Strings with #to_s" do
      expect(o200k.split("")).to eq([])
      expect(o200k.split(12_345)).to eq(%w[123 45])
    end

    it "is supported by the class-level shortcut" do
      expect(tokenizer.split("hello world", model: "gpt-4")).to eq(["hello", " world"])
    end
  end

  describe "JRRToken.context_size" do
    {
      "gpt-4o" => 128_000,
      "gpt-4.1" => 1_047_576,
      "gpt-5" => 400_000,
      "gpt-5.4" => 1_050_000,
      "gpt-4" => 8_192,
      "gpt-4-32k" => 32_768,
      "gpt-3.5-turbo" => 16_385,
      "o3-mini" => 200_000,
      "gpt-oss-20b" => 131_072,
      "text-davinci-003" => 4_097
    }.each do |model, size|
      it "returns #{size} for #{model}" do
        expect(JRRToken.context_size(model)).to eq(size)
      end
    end

    it "resolves fine-tuned models to their base model" do
      expect(JRRToken.context_size("ft:gpt-4o:org:name:id")).to eq(128_000)
    end

    it "returns nil for models not in the table, including bare encoding names" do
      expect(JRRToken.context_size("my-favorite-model-99")).to be_nil
      expect(JRRToken.context_size("o200k_base")).to be_nil
    end

    it "raises TypeError for a non-String model" do
      expect { JRRToken.context_size(nil) }.to raise_error(TypeError)
    end
  end
end
