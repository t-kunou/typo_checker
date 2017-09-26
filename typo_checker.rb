# frozen_string_literal: true

require 'thor'
require 'ripper'
require 'pp'
require 'active_support'
require 'active_support/core_ext'

class TypoChecker < Thor
  desc 'check', 'Check typo'
  option :path, required: true
  # TODO
  # option :ignore_path, required: false
  def check
    target_files = Dir.glob(root_path.join('**').join('*.rb'))

    @words = []

    target_files.each do |target_file|
      File.open(target_file) do |file|
        syntax_tree = Ripper.sexp(file)

        # puts target_file
        # pp syntax_tree

        find_keywords(syntax_tree)
      end
    end

    candidate_words = @words.group_by(&:itself).map {|k,v|
      [k,v.count]
    }.reject {|_, count|
      count > 20
    }.reject {|word, _|
      word.size < 3
    }.reject {|word, _|
      /\A[0-9]+\z/.match? word
    }.map {|word, count|
      [word.gsub(/[0-9]+\z/, ''), count]
    }.sort_by {|word, _|
      [word.size, word]
    }.reverse.map(&:first)

    dictionary_words = File.readlines('./dictionary').map {|word| word.gsub("\n", '')}

    puts candidate_words - dictionary_words
  end

  private

  def root_path
    @root_path ||= Pathname(options[:path])
  end

  def find_keywords(syntax_tree)
    if token? syntax_tree[0]
      puts 'mmm' if syntax_tree.size != 3

      words = split_words(syntax_tree)

      # pp syntax_tree
      # p [syntax_tree[0], words]

      @words += words
    else
      syntax_tree.each {|node|
        find_keywords(node) if node.is_a?(Array)
      }
    end
  end

  # check token
  # @ident
  # @const
  # @ivar
  # @label
  #
  # TODO
  # @tstring_content
  def token?(node)
    %i(@ident @const @ivar @label).include?(node)
  end

  def split_words(node)
    convert_to_snake_if_need(node).gsub(/[\?!@:=]/, '').split(/[_-]/)
  end

  def convert_to_snake_if_need(node)
    node.yield_self {|type, value, _|
      value.underscore
    }
  end
end

TypoChecker.start
