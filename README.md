# RuToken 🚀
RuToken provides a high-performance, native Ruby interface for counting tokens using the powerful tiktoken-rs library. It leverages the speed of Rust to offer a fast and efficient way to calculate token counts for various OpenAI models.

The gem ships with pre-compiled native extensions (except Windows), so your end-users don't need a Rust toolchain installed.

Features
High Performance ⚡️: Uses a native Rust implementation for blazing-fast tokenization.

Simple API: A clean and straightforward interface for counting tokens.

Extensive Model Support: Includes tokenizers for all modern and legacy OpenAI models, recognizing dozens of model aliases automatically.

Pre-compiled: Ships with binaries for major platforms (Linux, macOS, Windows) and Ruby versions, removing the need for local compilation in production.

Installation
Add this line to your application's Gemfile:

Ruby

gem 'ru_token'
And then execute:

Bash

$ bundle install
Or install it yourself as:

Bash

$ gem install ru_token
Usage
The primary interface is the RuToken::Tokenizer.count method. The model keyword argument is required.

Ruby

require 'ru_token'

text = "RuToken is a fast and simple way to count tokens."

## Count tokens for a specific model (the `model` keyword is required)
count = RuToken::Tokenizer.count(text, model: "gpt-4o")
### => 13

## The gem recognizes many aliases, including older models
count = RuToken::Tokenizer.count(text, model: "text-davinci-003")
### => 13
If you provide an unsupported model name, the gem will raise an ArgumentError.

Supported Models
The gem automatically maps dozens of model names and prefixes to the correct underlying tokenizer. You don't need to know the tokenizer's base name (e.g., cl100k_base); just use the model name you're working with.

o200k_base Models (e.g., GPT-4o)
cl100k_base Models (e.g., GPT-4, GPT-3.5)
p50k_base Models (e.g., text-davinci-003)
r50k_base Models (e.g., GPT-2)
p50k_edit Models
Development
After checking out the repo, set up your environment:

Bash

## Install Ruby and Rust dependencies
bundle install

## Compile the Rust extension and run tests
bundle exec rake
To just compile the extension without running tests, use bundle exec rake compile. You can also open an interactive console for experimentation with bin/console.

Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/LoganBresnahan/ru_token. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

License
The gem is available as open source under the terms of the GNU General Public License v3.0.
