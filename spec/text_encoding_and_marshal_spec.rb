# frozen_string_literal: true

RSpec.describe "JRRToken::Tokenizer text encodings and Marshal" do
  let(:o200k) { JRRToken::Tokenizer.for_model("gpt-4o") }

  describe "binary (ASCII-8BIT) text" do
    it "is read as UTF-8 when its bytes are valid UTF-8" do
      text = "héllo 🚀"
      expect(o200k.count(text.b)).to eq(o200k.count(text))
      expect(o200k.encode(text.b)).to eq(o200k.encode(text))
      expect(o200k.split(text.b)).to eq(o200k.split(text))
      expect(o200k.truncate(text.b, max_tokens: 2)).to eq(o200k.truncate(text, max_tokens: 2))
    end

    it "does not change the caller's string" do
      text = "héllo".b
      o200k.count(text)
      expect(text.encoding).to eq(Encoding::BINARY)
    end

    it "raises ArgumentError when its bytes are not valid UTF-8" do
      expect { o200k.count("\xff\xfe".b) }.to raise_error(ArgumentError, /invalid byte sequence in UTF-8/)
    end

    it "works in count_messages" do
      binary = [{ role: "user", content: "héllo".b }]
      utf8 = [{ role: "user", content: "héllo" }]
      expect(JRRToken.count_messages(binary, model: "gpt-4o")).to eq(JRRToken.count_messages(utf8, model: "gpt-4o"))
    end
  end

  describe "US-ASCII text with non-ASCII bytes (File.read with no locale)" do
    it "is read as UTF-8 when its bytes are valid UTF-8" do
      mislabeled = "héllo 🚀".dup.force_encoding(Encoding::US_ASCII)
      expect(mislabeled).not_to be_valid_encoding
      expect(o200k.count(mislabeled)).to eq(o200k.count("héllo 🚀"))
      expect(mislabeled.encoding).to eq(Encoding::US_ASCII)
    end

    it "raises ArgumentError when its bytes are not valid UTF-8" do
      expect { o200k.count("\xff".dup.force_encoding(Encoding::US_ASCII)) }
        .to raise_error(ArgumentError, /invalid byte sequence in UTF-8 \(US-ASCII text/)
    end

    it "leaves plain ASCII text alone" do
      expect(o200k.count("hello".encode(Encoding::US_ASCII))).to eq(1)
    end
  end

  it "raises ArgumentError for invalid UTF-8 text" do
    expect { o200k.count("ab\xffcd".dup.force_encoding(Encoding::UTF_8)) }
      .to raise_error(ArgumentError, "invalid byte sequence in UTF-8")
  end

  it "raises ArgumentError for invalid text in other encodings" do
    expect { o200k.count("\x82".dup.force_encoding(Encoding::Shift_JIS)) }
      .to raise_error(ArgumentError, /invalid byte sequence in Shift_JIS/)
  end

  it "transcodes other encodings and returns UTF-8" do
    latin1 = "héllo".encode(Encoding::ISO_8859_1)
    expect(o200k.count(latin1)).to eq(o200k.count("héllo"))
    result = o200k.truncate(latin1, max_tokens: 10)
    expect(result.encoding).to eq(Encoding::UTF_8)
    expect(result).to eq("héllo")
  end

  describe "Marshal" do
    it "round-trips to the shared instance" do
      expect(Marshal.load(Marshal.dump(o200k))).to equal(o200k)
    end

    it "works for tokenizers nested in other objects" do
      loaded = Marshal.load(Marshal.dump({ tokenizer: JRRToken::Tokenizer.for_model("gpt-4") }))
      expect(loaded[:tokenizer]).to equal(JRRToken::Tokenizer.for_model("gpt-4"))
    end
  end
end
