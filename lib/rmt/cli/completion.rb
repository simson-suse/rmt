class RMT::CLI::Completion
  @@dynamic_commands = %W(enable disable export import attach detach remove)

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

  def static_completion_possible?(index: 1, words: @cli_words[0..@cli_words.length - 2])

    if words.length < 3
      return true
    end

    sub_command = words[index]
    super_command = words[index - 1]

    if words.length == index
      return true
    end

    if generate_static_options(super_command).include? sub_command
      return static_completion_possible?(index: index + 1, words: words)
    end

    return false
  end

  def dynamic_completion_possible?

    dynamic_identifier = @cli_words & @@dynamic_commands

    if dynamic_identifier.length != 1
      return false
    end

    dynamic_identifier = dynamic_identifier[0]
    index = @cli_words.find_index(dynamic_identifier)

    if !static_completion_possible?(index: 1, words: @cli_words[0..index])
      return false
    end

    return true
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
