require File.expand_path('../../common', __FILE__)
require File.join(File.expand_path('../', __FILE__), 'virgo.rb')

class VirgoPlugin < StagingPlugin

  def framework
    'virgo'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Virgo.prepare(destination_directory)
      services = environment[:services] if environment
      copy_service_drivers(webapp_root, services)
      copy_source_files(webapp_root)
      setup_autostaging(webapp_root)
      create_startup_script
      create_stop_script
    end
  end

  def setup_autostaging webapp_root
    Virgo.prepare_stager webapp_root
  end

   def copy_service_drivers webapp_root, services
    
    Virgo.copy_service_drivers(services, webapp_root) if services
  end
  
  def copy_source_files(dest = nil)
    extension = Virgo.detect_file_extension(source_directory)
    dest ||= File.join(destination_directory, "app.#{extension}")
    if extension === "plan"
      system "cp -a #{File.join(source_directory, "*")} #{dest}"
      system "cp -rf #{File.join(dest, Virgo.repository, "*")} #{File.join(dest, "..", Virgo.repository,"usr")}"
      
      # Copy the plan file to pickup
      plan =''
      Dir.chdir(source_directory) do
        plan = Dir.glob("*.plan")[0]       
      end
      system "cp -a #{File.join(source_directory, plan)} #{File.join(dest, "..", "pickup")}"
      system "rm -rf #{File.join(dest, Virgo.repository)}"
    elsif extension == "parpacked"
      # cases where par file is created;dependencies are inside par-provided folder; maven plugin
      parfile =''
      Dir.chdir(source_directory) do
        parfile = Dir.glob("*.par")[0]       
      end
      system "cp -a #{File.join(source_directory, parfile)} #{File.join(dest, "..", "pickup")}"
      system "cp -a #{File.join(source_directory,"par-provided", "*")} #{File.join(dest, "..", Virgo.repository,"usr")}"
    else
      output = %x[cd #{source_directory}; zip -r #{File.join(dest, File.basename(source_directory) + ".#{extension}")} *]
      raise "Could not pack Virgo application: #{output}" unless $? == 0
    end
  end

  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  # The Virgo start script runs from the root of the staged application.
  def change_directory_for_start
    "cd virgo"
  end

  # We redefine this here because Virgo doesn't want to be passed the cmdline
  # args that were given to the 'start' script.
  def start_command
    "./bin/dmk.sh start -jmxport $(($PORT + 1))"
  end

  def configure_memory_opts
    # We want to set this to what the user requests, *not* set a minum bar
    "-Xms#{application_memory}m -Xmx#{application_memory}m"
  end

  private

  def startup_script
    vars = environment_hash
    vars['JAVA_OPTS'] = configure_memory_opts
    vars['JAVA_HOME'] = (ENV['JAVA_HOME'].nil? && '/usr/lib/jvm/java-6-sun') || ENV['JAVA_HOME']
    generate_startup_script(vars) do
      <<-VIRGO
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
      VIRGO
    end
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end
end
