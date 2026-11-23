# frozen_string_literal: true

RSpec.describe JRRToken do
  it "has a version number" do
    expect(JRRToken::VERSION).not_to be nil
  end

  describe JRRToken::Tokenizer do
    SIMPLE_TEXT = "Hello world"
    COMPLEX_TEXT = "The quick brown fox jumps over the lazy dog. 🚀"

    def self.it_verifies_token_count(models:, text:, expected_count:, description: nil)
      context_desc = description || "with text: '#{text}'"

      context context_desc do
        models.each do |model|
          it "counts #{expected_count} tokens for model '#{model}'" do
            expect(JRRToken::Tokenizer.count(text, model: model)).to eq(expected_count)
          end
        end
      end
    end

    context "when using o200k_base models" do
      models = [
        "o200k_base", "gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-5.4", "gpt-5.4-pro",
        "gpt-4o", "gpt-4.1", "gpt-4.5-preview", "chatgpt-4o-latest",
        "gpt-4o-2024-05-13",
        "ft:gpt-4o-abcdef",
        "ft:gpt-4o",
        "ft:gpt-4o:org:model:123",
        "ft:gpt-5:org:model",
        "o1", "o1-preview", "o3", "o3-mini", "o4-mini", "o4-mini-2025-04-16",
        "gpt-5.4-mini", "gpt-5.2-codex",
        "codex-mini", "codex-mini-latest"
      ]

      it_verifies_token_count(
        models: models,
        text: SIMPLE_TEXT,
        expected_count: 2,
        description: "with simple text"
      )

      it_verifies_token_count(
        models: models,
        text: COMPLEX_TEXT,
        expected_count: 12,
        description: "with complex text including emoji"
      )
    end

    context "when using o200k_harmony models" do
      models = ["o200k_harmony", "gpt-oss-20b", "gpt-oss-120b"]

      it_verifies_token_count(
        models: models,
        text: SIMPLE_TEXT,
        expected_count: 2,
        description: "with simple text"
      )
    end

    context "when using cl100k_base models" do
      models = [
        "cl100k_base", "gpt-4", "gpt-3.5-turbo", "text-embedding-ada-002",
        "gpt-4-32k-0613", "gpt-3.5-turbo-instruct",
        "ft:gpt-3.5-turbo-xyz", "ft:gpt-4:org:model:123", "ft:gpt-4-turbo",
        "ft:gpt-4"
      ]

      it_verifies_token_count(
        models: models,
        text: SIMPLE_TEXT,
        expected_count: 2,
        description: "with simple text"
      )

      it_verifies_token_count(
        models: models,
        text: COMPLEX_TEXT,
        expected_count: 13,
        description: "with complex text including emoji"
      )
    end

    context "when using p50k_base models" do
      models = ["p50k_base", "text-davinci-003", "code-davinci-002"]
      it_verifies_token_count(models: models, text: SIMPLE_TEXT, expected_count: 2)
    end

    context "when using r50k_base models" do
      models = ["r50k_base", "gpt2", "davinci", "text-ada-001"]
      it_verifies_token_count(models: models, text: SIMPLE_TEXT, expected_count: 2)
    end

    context "when using p50k_edit models" do
      models = ["p50k_edit", "text-davinci-edit-001"]
      it_verifies_token_count(models: models, text: SIMPLE_TEXT, expected_count: 2)
    end

    context "fine-tuned model tokenizer verification" do
      it "uses o200k_base for ft:gpt-4o models, not cl100k_base" do
        o200k_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "gpt-4o")
        ft_4o_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-4o")

        expect(ft_4o_count).to eq(o200k_count),
          "ft:gpt-4o should use same tokenizer as gpt-4o (o200k_base)"
      end

      it "uses cl100k_base for ft:gpt-4 models" do
        cl100k_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "gpt-4")
        ft_4_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-4:org:model:123")

        expect(ft_4_count).to eq(cl100k_count),
          "ft:gpt-4 should use same tokenizer as gpt-4 (cl100k_base)"
      end

      it "distinguishes between ft:gpt-4 and ft:gpt-4o models" do
        ft_4_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-4:org:model:123")
        ft_4o_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-4o:org:model:123")

        expect(ft_4_count).not_to eq(ft_4o_count),
          "ft:gpt-4 and ft:gpt-4o should use different tokenizers"
      end

      it "uses o200k_base for ft:gpt-5 models" do
        gpt5_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "gpt-5")
        ft_5_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-5:org:model:abc")

        expect(ft_5_count).to eq(gpt5_count),
          "ft:gpt-5 should use same tokenizer as gpt-5 (o200k_base)"
      end
    end

    context "model mapping synced with upstream tiktoken 0.14.0" do
      # tiktoken-rs 0.11 mapped bare "o4" / "o4-*" itself; OpenAI tiktoken only ever maps
      # o4-mini, and tiktoken-rs 0.12 dropped the extras to match it.
      ["o4", "o4-pro"].each do |model|
        it "raises an ArgumentError for '#{model}'" do
          expect { JRRToken::Tokenizer.count(SIMPLE_TEXT, model: model) }
            .to raise_error(ArgumentError, "Model '#{model}' not supported.")
        end
      end
    end

    context "special tokens" do
      it "counts <|endoftext|> as plain text by default" do
        expect(JRRToken::Tokenizer.count("<|endoftext|>", model: "gpt-4o")).to eq(7)
        expect(JRRToken::Tokenizer.count("<|endoftext|>", model: "gpt-4")).to eq(7)
      end

      it "counts <|endoftext|> as a single special token with special_tokens: :allow" do
        expect(JRRToken::Tokenizer.count("<|endoftext|>", model: "gpt-4o", special_tokens: :allow)).to eq(1)
        expect(JRRToken::Tokenizer.count("<|endoftext|>", model: "gpt-4", special_tokens: :allow)).to eq(1)
      end

      it "counts o200k_harmony special tokens as single tokens with special_tokens: :allow" do
        expect(JRRToken::Tokenizer.count("<|start|>", model: "gpt-oss-20b")).to eq(5)
        expect(JRRToken::Tokenizer.count("<|start|>", model: "gpt-oss-20b", special_tokens: :allow)).to eq(1)
      end
    end

    context "long repetitive input" do
      # Regression guard for upstream's large-piece BPE merge (tiktoken-rs 0.12):
      # with the old quadratic merge, 200 KB of "a" took ~15 s.
      it "counts a 200 KB single-character run" do
        expect(JRRToken::Tokenizer.count("a" * 200_000, model: "gpt-4o")).to eq(25_000)
      end

      it "counts a 200 KB two-character run" do
        expect(JRRToken::Tokenizer.count("ab" * 100_000, model: "r50k_base")).to eq(100_000)
      end
    end

    context "tokenizer caching" do
      it "returns stable counts across repeated calls and interleaved encodings" do
        models = ["gpt-4o", "gpt-4", "text-davinci-003", "gpt-oss-20b", "gpt2"]
        expected = models.to_h { |m| [m, JRRToken::Tokenizer.count(COMPLEX_TEXT, model: m)] }

        3.times do
          models.each do |model|
            expect(JRRToken::Tokenizer.count(COMPLEX_TEXT, model: model)).to eq(expected[model])
          end
        end
      end

      # Smoke test: the GVL serializes calls into the extension, so this can't catch a data
      # race (that's guaranteed by CoreBPE: Sync). Expected counts are hardcoded so the
      # threads, not the main thread, trigger any first-time tokenizer builds.
      it "returns correct counts when called concurrently from multiple threads" do
        expected = {
          "gpt-4o" => 12, "gpt-4" => 13, "text-davinci-003" => 13,
          "p50k_edit" => 13, "r50k_base" => 13, "o200k_harmony" => 12
        }
        models = expected.keys

        results = 8.times.map do |i|
          Thread.new do
            20.times.map do |j|
              model = models[(i + j) % models.size]
              [model, JRRToken::Tokenizer.count(COMPLEX_TEXT, model: model)]
            end
          end
        end.flat_map(&:value)

        results.each do |model, count|
          expect(count).to eq(expected[model]), "#{model} returned #{count}, expected #{expected[model]}"
        end
      end
    end

    context "with invalid inputs and edge cases" do
      it "raises an ArgumentError for a completely unsupported model" do
        unsupported_model = "my-favorite-model-99"
        expect { JRRToken::Tokenizer.count(SIMPLE_TEXT, model: unsupported_model) }
          .to raise_error(ArgumentError, "Model '#{unsupported_model}' not supported.")
      end

      it "handles empty strings gracefully" do
        expect(JRRToken::Tokenizer.count("", model: "gpt-4o")).to eq(0)
      end

      it "handles non-string text input by calling .to_s" do
        expect(JRRToken::Tokenizer.count(123, model: "gpt-4")).to eq(1)
      end

      # A ~1M-character whitespace run followed by text exceeds fancy-regex's stack limit.
      # Before tiktoken-rs 0.12 this panicked and killed the process with an uncatchable
      # `fatal`; it must now surface as a regular, rescuable RuntimeError.
      it "raises a RuntimeError (not fatal) when the tokenizer regex fails" do
        expect { JRRToken::Tokenizer.count(" " * 1_000_000 + "x", model: "gpt-4o") }
          .to raise_error(RuntimeError, /Could not encode string/)
      end
    end
  end
end
