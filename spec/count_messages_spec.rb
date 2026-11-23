# frozen_string_literal: true

RSpec.describe "JRRToken.count_messages" do
  # Expected values were computed with tiktoken-rs 0.12.1's num_tokens_from_messages (via
  # its async-openai adapter, which takes OpenAI-shaped messages) on the same JSON, so these
  # specs pin parity with upstream. Re-verify them when bumping tiktoken-rs.
  let(:conversation) do
    [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", name: "bob", content: "What is 2+2?" },
      { role: "assistant", tool_calls: [{ id: "c1", type: "function", function: { name: "calc", arguments: '{"x":"2+2"}' } }] },
      { role: "tool", tool_call_id: "c1", content: "4" },
      { role: "assistant", function_call: { name: "f", arguments: "{}" } },
      { role: "assistant", refusal: "no" },
      { "role" => "user", "content" => "日本語 and emoji 🚀 here" }
    ]
  end

  { "gpt-4o" => 70, "gpt-4" => 73, "gpt-oss-20b" => 70, "gpt-3.5-turbo-0301" => 76 }.each do |model, expected|
    it "matches tiktoken-rs for #{model}" do
      expect(JRRToken.count_messages(conversation, model: model)).to eq(expected)
    end
  end

  it "counts a single message with framing and reply priming" do
    expect(JRRToken.count_messages([{ role: "user", content: "Hello!" }], model: "gpt-4o")).to eq(9)
  end

  it "counts only reply priming for an empty list" do
    expect(JRRToken.count_messages([], model: "gpt-4o")).to eq(3)
  end

  it "accepts String and Symbol keys interchangeably" do
    symbol_keys = [{ role: "user", name: "bob", content: "hi" }]
    string_keys = [{ "role" => "user", "name" => "bob", "content" => "hi" }]
    expect(JRRToken.count_messages(string_keys, model: "gpt-4o")).to eq(JRRToken.count_messages(symbol_keys, model: "gpt-4o"))
  end

  it "accepts flat tool calls as well as the OpenAI {function: {...}} shape" do
    nested = [{ role: "assistant", tool_calls: [{ function: { name: "calc", arguments: "{}" } }] }]
    flat = [{ role: "assistant", tool_calls: [{ name: "calc", arguments: "{}" }] }]
    expect(JRRToken.count_messages(flat, model: "gpt-4o")).to eq(JRRToken.count_messages(nested, model: "gpt-4o"))
  end

  describe "parity with tiktoken-rs's handling of OpenAI-shaped messages" do
    {
      "refusal content parts" => [[{ role: "assistant", content: [{ type: "refusal", refusal: "no" }] }], 8, 8],
      "refusal parts over the refusal field" => [
        [{ role: "assistant", content: [{ type: "text", text: "hi" }, { type: "refusal", refusal: "I can't" }], refusal: "ignored field" }], 10, 11
      ],
      "custom tool calls" => [[{ role: "assistant", tool_calls: [{ id: "x", type: "custom", custom: { name: "grep", input: "foo" } }] }], 10, 10],
      "text parts joined before counting" => [[{ role: "user", content: [{ type: "text", text: "hel" }, { type: "text", text: "lo" }] }], 8, 8],
      "joined parts across a newline boundary" => [[{ role: "user", content: [{ type: "text", text: "a\n" }, { type: "text", text: "\nb" }] }], 10, 10],
      "tool_call_id counted as the tool message's name" => [[{ role: "tool", tool_call_id: "call_abc123", content: "4" }], 13, 13],
      "tool message text parts" => [[{ role: "tool", tool_call_id: "t1", content: [{ type: "text", text: "x" }, { type: "text", text: "y" }] }], 11, 11],
      "a mixed conversation" => [
        [
          { role: "system", content: "You are helpful." },
          { role: "developer", content: [{ type: "text", text: "Be brief." }] },
          { role: "user", name: "bob", content: "What is 2+2?" },
          { role: "assistant", content: nil, tool_calls: [{ id: "c1", type: "function", function: { name: "calc", arguments: '{"x":"2+2"}' } }] },
          { role: "tool", tool_call_id: "c1", content: "4" },
          { role: "assistant", content: "It is 4. 🚀" }
        ], 63, 64
      ]
    }.each do |description, (messages, o200k, cl100k)|
      it "matches for #{description}" do
        expect(JRRToken.count_messages(messages, model: "gpt-4o")).to eq(o200k)
        expect(JRRToken.count_messages(messages, model: "gpt-4")).to eq(cl100k)
      end
    end
  end

  it "skips image, audio and file content parts" do
    text_only = [{ role: "user", content: [{ type: "text", text: "What is this?" }] }]
    with_media = [{ role: "user", content: [
      { type: "text", text: "What is this?" },
      { type: "image_url", image_url: { url: "https://example.com/a.png" } },
      { type: "input_audio", input_audio: { data: "...", format: "wav" } },
      { type: "file", file: { file_id: "file-123" } }
    ] }]
    expect(JRRToken.count_messages(with_media, model: "gpt-4o")).to eq(JRRToken.count_messages(text_only, model: "gpt-4o"))
  end

  it "ignores keys it doesn't count" do
    with_extra = [{ role: "user", content: "4", metadata: { "a" => 1 } }]
    without = [{ role: "user", content: "4" }]
    expect(JRRToken.count_messages(with_extra, model: "gpt-4o")).to eq(JRRToken.count_messages(without, model: "gpt-4o"))
  end

  describe "special_tokens:" do
    let(:messages) { [{ role: "user", content: "<|endoftext|>" }] }

    it "treats special-token strings as text by default" do
      expect(JRRToken.count_messages(messages, model: "gpt-4o")).to eq(3 + 3 + 1 + 7)
    end

    it "honors :allow and :raise" do
      expect(JRRToken.count_messages(messages, model: "gpt-4o", special_tokens: :allow)).to eq(3 + 3 + 1 + 1)
      expect { JRRToken.count_messages(messages, model: "gpt-4o", special_tokens: :raise) }
        .to raise_error(JRRToken::SpecialTokenError)
    end
  end

  describe "errors" do
    it "rejects models whose encoding isn't used by chat models" do
      expect { JRRToken.count_messages([], model: "text-davinci-003") }
        .to raise_error(ArgumentError, /supports chat models.*p50k_base/)
    end

    it "rejects unsupported models" do
      expect { JRRToken.count_messages([], model: "my-favorite-model-99") }.to raise_error(ArgumentError, /not supported/)
    end

    it "requires an Array of Hashes" do
      expect { JRRToken.count_messages("x", model: "gpt-4o") }.to raise_error(TypeError, /must be an Array, got String/)
      expect { JRRToken.count_messages(["x"], model: "gpt-4o") }.to raise_error(TypeError, /message 0 must be a Hash, got String/)
    end

    it "names the actual class of malformed nested values" do
      {
        [{ role: "user", content: ["x"] }] => /content part 0 must be a Hash, got String/,
        [{ role: "assistant", tool_calls: "x" }] => /"tool_calls" must be an Array, got String/,
        [{ role: "assistant", tool_calls: ["x"] }] => /tool_calls\[0\] must be a Hash, got String/,
        [{ role: "assistant", function_call: "x" }] => /function_call must be a Hash, got String/,
        [{ role: "assistant", tool_calls: [{ type: "custom", custom: "x" }] }] => /tool_calls\[0\].custom must be a Hash, got String/
      }.each do |messages, message|
        expect { JRRToken.count_messages(messages, model: "gpt-4o") }.to raise_error(TypeError, message)
      end
    end

    it "requires a role" do
      expect { JRRToken.count_messages([{ content: "x" }], model: "gpt-4o") }
        .to raise_error(ArgumentError, /message 0 is missing "role"/)
    end

    it "rejects non-String fields" do
      expect { JRRToken.count_messages([{ role: "user", content: 5 }], model: "gpt-4o") }
        .to raise_error(TypeError, /"content" must be a String, Array or nil/)
      expect { JRRToken.count_messages([{ role: "user", name: :bob }], model: "gpt-4o") }
        .to raise_error(TypeError, /"name" must be a String/)
    end

    it "rejects unknown content part types" do
      typo = [{ role: "user", content: [{ type: "txet", text: "hi" }] }]
      expect { JRRToken.count_messages(typo, model: "gpt-4o") }
        .to raise_error(ArgumentError, /unknown type "txet"/)
    end

    it "requires name and arguments on function and tool calls" do
      expect { JRRToken.count_messages([{ role: "assistant", function_call: { name: "f" } }], model: "gpt-4o") }
        .to raise_error(ArgumentError, /function_call.arguments/)
      expect { JRRToken.count_messages([{ role: "assistant", tool_calls: [{ function: { arguments: "{}" } }] }], model: "gpt-4o") }
        .to raise_error(ArgumentError, /tool_calls\[0\].function.name/)
      expect { JRRToken.count_messages([{ role: "assistant", tool_calls: [{ type: "custom", custom: { name: "g" } }] }], model: "gpt-4o") }
        .to raise_error(ArgumentError, /tool_calls\[0\].custom.input/)
    end
  end

  it "keeps its message reader private" do
    expect { JRRToken::MessageFields }.to raise_error(NameError)
  end
end
