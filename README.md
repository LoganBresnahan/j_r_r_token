RuToken
RuToken provides a high-performance, native Ruby interface for counting tokens using the powerful tiktoken-rs library. It leverages the speed of Rust to offer a fast and efficient way to calculate token counts for various OpenAI models, without requiring users to have a Rust toolchain installed.

Features
High Performance: Uses native Rust code for fast tokenization.

No User-Side Compilation: Ships with pre-compiled binaries for major platforms (Linux, macOS, Windows) and Ruby versions (2.7+).

Simple API: A clean and straightforward interface for counting tokens.

Multiple Model Support: Includes tokenizers for several popular OpenAI models.

Installation
Add this line to your application's Gemfile:

gem 'ru_token'

And then execute:

$ bundle install

Or install it yourself as:

$ gem install ru_token

Usage
The primary interface is the RuToken::Tokenizer.count method.

require 'ru_token'

# Count tokens using the default model ('o200k_base')
token_count = RuToken::Tokenizer.count("Hello world, this is a test!")
# => 6

# Count tokens using a specific model
token_count = RuToken::Tokenizer.count("Hello world, this is a test!", model: "p50k_base")
# => 6

Supported Models
You can specify any of the following models for tokenization:

o200k_base (Used by newer GPT-4 models)

cl100k_base (Default, used by gpt-4 and gpt-3.5-turbo)

p50k_base (Used by text-davinci-002, text-davinci-003)

r50k_base (Used by gpt2)

If you provide an unsupported model name, the gem will raise an ArgumentError.

Development
After checking out the repo, run bundle install to install dependencies.

To compile the Rust extension for local development, run:

$ bundle exec rake compile

To run tests or experiment with the code, you can open an interactive console:

$ bin/console

Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/LoganBresnahan/ru_token. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

License
The gem is available as open source under the terms of the GNU General Public License v3.0.
