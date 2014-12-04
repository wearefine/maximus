require 'thor'

class Maximus::CLI < Thor
  include Thor::Actions
  desc "hello", 'say something nice'
  def hello
    puts "hello"
  end
end
