#!/usr/bin/ruby
require_relative '../../../../../../lib/objects/local_string_generator.rb'
require 'erb'
require 'fileutils'
require 'redcarpet'
require 'nokogiri'

class HackerbotConfigGenerator < StringGenerator
  attr_accessor :accounts
  attr_accessor :flags
  attr_accessor :root_password
  LOCAL_DIR = File.expand_path('../../',__FILE__)
  TEMPLATE_PATH = "#{LOCAL_DIR}/templates/integrity_lab.xml.erb"

  def initialize
    super
    self.module_name = 'Hackerbot Config Generator'
    self.accounts = []
    self.flags = []
    self.root_password = ''
  end

  def get_options_array
    super + [['--root_password', GetoptLong::REQUIRED_ARGUMENT],
             ['--accounts', GetoptLong::REQUIRED_ARGUMENT],
             ['--flags', GetoptLong::REQUIRED_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
      when '--root_password'
        self.root_password << arg;
      when '--accounts'
        self.accounts << arg;
      when '--flags'
        self.flags << arg;
    end
  end

  def generate_lab_sheet(xml_config)
    # parsed = Nori.new.parse(xml_config)
    # Print.debug parsed.to_s
    # lab_sheet = parsed['tutorial']['introduction']
    # Print.debug lab_sheet
    lab_sheet = ''
    begin
      doc = Nokogiri::XML(xml_config)
    rescue
      Print.err "Failed to process hackerbot config"
      exit
    end
    # remove xml namespaces for ease of processing
    doc.remove_namespaces!
    # for each element in the vulnerability
    # Print.debug doc.to_s
    hackerbot = doc.xpath("/hackerbot")
    name = hackerbot.xpath("name").first.content
    lab_sheet += hackerbot.xpath("tutorial_info/tutorial").first.content + "\n"

    doc.xpath("//attack").each_with_index do |attack, index|
      attack.xpath("tutorial").each do |tutorial_snippet|
        lab_sheet += tutorial_snippet.content + "\n"
      end

      lab_sheet += "#### #{name} Attack ##{index + 1}\n"
      lab_sheet += "Use what you have learned to complete the bot's challenge. You can skip the bot to here, by saying '**goto #{index + 1}**'\n\n"
      lab_sheet += "> #{name}: \"#{attack.xpath('prompt').first.content}\" \n\n"
      lab_sheet += "Do any necessary preparation, then when you are ready for the bot to complete the action/attack, say '**ready**'\n\n"
      if attack.xpath("quiz").size > 0
        lab_sheet += "There is a quiz to complete. Once Hackerbot asks you the question you can '**answer YOURANSWER**'\n\n"
      end

    end
    lab_sheet += hackerbot.xpath("tutorial_info/footer").first.content + "\n"

    lab_sheet
  end

  def generate

    # Print.debug self.accounts.to_s
    template_out = ERB.new(File.read(TEMPLATE_PATH), 0, '<>-')
    xml_config = template_out.result(self.get_binding)
    lab_sheet_markdown = generate_lab_sheet(xml_config)

    redcarpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(render_options = {}), extensions = {})
    lab_sheet_html = redcarpet.render(lab_sheet_markdown).force_encoding('UTF-8')

    self.outputs << {'xml_config' => xml_config, 'lab_sheet_html'=>lab_sheet_html}
  end

  # Returns binding for erb files (access to variables in this classes scope)
  # @return binding
  def get_binding
    binding
  end
end


HackerbotConfigGenerator.new.run