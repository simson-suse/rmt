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

    if generate_static_options(command: super_command).include? sub_command
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

  def generate_static_options(command: @previous_word)
    submodule = command.slice(0, 1).capitalize + command.slice(1, command.length).downcase
    options = []

    # exceptions:
    if command == 'rmt-cli' || command =='help' then submodule = 'Main' end
    if command == 'repo' then submodule = 'Repos' end
    if command == 'product' then submodule = 'Products' end
    if command == 'custom' then submodule = 'ReposCustom' end
    if command == 'rmt-cli' then options.append('help') end

    begin
      options.concat RMT::CLI.module_eval(submodule).commands.keys
    rescue NameError
    end

    return options
  end

  def generate_dynamic_options
    require 'active_record'
    require_relative '../../../app/models/application_record'
    db_config = RMT::Config.db_config
    ActiveRecord::Base.establish_connection(db_config)

    dynamic_identifier = (@cli_words & @@dynamic_commands)[0]

    case dynamic_identifier

    when 'enable', 'disable'
      super_command = @cli_words[1]
      custom = (@cli_words[2] == 'custom')

      list_of_(what: super_command, enabled_or_disabled: dynamic_identifier, custom: custom)

    when 'export', 'import'
      if @cli_words.length = 3
        generate_static_options
      elsif @cli_words.length = 4
        puts "PATH"
      end

    when 'attach'

    when 'detach'

    when 'remove'


    end
  end

  def generate_completions
    completions = []
    static_options = generate_static_options
    dynamic_options = generate_dynamic_options

    static_options.each do |option|
      if option.start_with?(@current_word)
        completions.append(option)
      end
    end

    return completions
  end

  def list_of_(what: nil, enabled_or_disabled: nil, custom: false)
    case what
    when 'products'
      require_relative '../../../app/models/product'
      products = RMT::CLI::Products
      require 'pry'
      binding.pry
    when 'repos'
    end
  end

  def complete
    completions = generate_completions

    print completions.join("\n")
  end

end
