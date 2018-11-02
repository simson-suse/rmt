class RMT::CLI::Completion
  @cli_words = []
  @current_word = ''
  @previous_word = ''

  def initialize
    split_cli_feed
    determine_current_word
    determine_previous_word
  end

  def split_cli_feed
    @cli_words = ENV['COMP_LINE'].split(' ')
    if ENV['COMP_LINE'][-1] == ' '
      @cli_words.append('')
    end
  end

  def correct_capitalization?
    @cli_words.join == @cli_words.join.downcase
  end

  def static_completion_possible?(index = 1)
    if index > 3
      return false
    elsif index >= @cli_words.length - 1
      return true
    else
      word_to_verify = @cli_words[index]
      previous_word = @cli_words[index - 1]
      if generate_static_options(previous_word).include? word_to_verify
        return static_completion_possible?(index + 1)
      end
    end
    return false
  end

  def determine_current_word
    @current_word = @cli_words.last
  end

  def determine_previous_word
    if @cli_words.length > 1
      @previous_word = @cli_words[@cli_words.length - 2]
    else
      @previous_word = ''
    end
  end

  def generate_static_options(previous_word)
    submodule = previous_word.slice(0,1).capitalize + previous_word.slice(1, previous_word.length).downcase
    options = []

    # exceptions:
    if previous_word == 'rmt-cli' || previous_word =='help' then submodule = 'Main' end
    if previous_word == 'repo' then submodule = 'Repos' end
    if previous_word == 'product' then submodule = 'Products' end
    if previous_word == 'custom' then submodule = 'ReposCustom' end
    if previous_word == 'rmt-cli' then options.append('help') end

    begin
      options.concat RMT::CLI.module_eval(submodule).commands.keys
    rescue NameError
    end

    return options
  end

  def generate_completions
    completions = []
    static_options = generate_static_options(@previous_word)

    static_options.each do |option|
      if option.start_with?(@current_word)
        completions.append(option)
      end
    end

    return completions
  end

  def complete
    completions = generate_completions

    print completions.join("\n")
  end

end