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
        "o200k_base", "gpt-4o", "gpt-4.1", "chatgpt-4o-latest",
        "gpt-4o-2024-05-13",
        "ft:gpt-4o-abcdef",
        "ft:gpt-4o",
        "o1-preview", "o3-mini"
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

    context "when using cl100k_base models" do
      models = [
        "cl100k_base", "gpt-4", "gpt-3.5-turbo", "text-embedding-ada-002",
        "gpt-4-32k-0613", "gpt-3.5-turbo-instruct",
        "ft:gpt-3.5-turbo-xyz", "ft:gpt-4:custom"
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
        ft_4_count = JRRToken::Tokenizer.count(COMPLEX_TEXT, model: "ft:gpt-4:custom")

        expect(ft_4_count).to eq(cl100k_count),
          "ft:gpt-4 should use same tokenizer as gpt-4 (cl100k_base)"
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
    end
  end
end
