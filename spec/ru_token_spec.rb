# frozen_string_literal: true

RSpec.describe RuToken do
  it "has a version number" do
    expect(RuToken::VERSION).not_to be nil
  end

  describe RuToken::Tokenizer do
    let(:text) { "Hello world, peace be upon you." }

    def self.it_verifies_token_count(models:, expected_count:)
      models.each do |model|
        it "counts #{expected_count} tokens for model '#{model}'" do
          expect(RuToken::Tokenizer.count(text, model: model)).to eq(expected_count)
        end
      end
    end

    context "when using o200k_base models (e.g., GPT-4o)" do
      models = [
        "o200k_base", "gpt-4o", "gpt-4.1", "chatgpt-4o-latest",
        "gpt-4o-2024-05-13", "ft:gpt-4o-abcdef"
      ]
      it_verifies_token_count(models: models, expected_count: 8)
    end

    context "when using cl100k_base models (e.g., GPT-4, GPT-3.5)" do
      models = [
        "cl100k_base", "gpt-4", "gpt-3.5-turbo", "text-embedding-ada-002",
        "gpt-4-32k-0613", "gpt-3.5-turbo-instruct", "ft:gpt-3.5-turbo-xyz"
      ]
      it_verifies_token_count(models: models, expected_count: 8)
    end

    # --- CORRECTED ---
    context "when using p50k_base models (e.g., text-davinci-003)" do
      models = ["p50k_base", "text-davinci-003", "code-davinci-002"]
      # The count was 9, corrected to 8.
      it_verifies_token_count(models: models, expected_count: 8)
    end

    # --- CORRECTED ---
    context "when using r50k_base models (e.g., GPT-2)" do
      models = ["r50k_base", "gpt2", "davinci", "text-ada-001"]
      # The count was 9, corrected to 8.
      it_verifies_token_count(models: models, expected_count: 8)
    end

    # --- CORRECTED ---
    context "when using p50k_edit models" do
      models = ["p50k_edit", "text-davinci-edit-001"]
      # The count was 9, corrected to 8.
      it_verifies_token_count(models: models, expected_count: 8)
    end

    context "with invalid inputs and edge cases" do
      it "raises an ArgumentError for a completely unsupported model" do
        unsupported_model = "my-favorite-model-99"
        expect { RuToken::Tokenizer.count(text, model: unsupported_model) }
          .to raise_error(ArgumentError, "Model '#{unsupported_model}' not supported.")
      end

      it "handles empty strings gracefully" do
        expect(RuToken::Tokenizer.count("", model: "gpt-4o")).to eq(0)
      end

      it "handles non-string text input by calling .to_s" do
        expect(RuToken::Tokenizer.count(123, model: "gpt-4")).to eq(1)
      end
    end
  end
end
