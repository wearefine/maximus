module ConfigHelper

  def create_config(contents = '', location = '.maximus.yml')
    File.write(location, contents)
    config_contents = contents.blank? ? {} : { config_file: location }
    described_class.new(config_contents)
  end

  def destroy_config(location = '.maximus.yml')
    FileUtils.rm(location) if File.exist?(location)
  end

end
