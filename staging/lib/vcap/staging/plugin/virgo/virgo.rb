require 'fileutils'
require 'yaml'

class Virgo
  AUTOSTAGING_JAR = 'osgi.autostager-1.0.0.PTYP.jar'
  AUTOSTAGING_DEP =['com.springsource.org.codehaus.jackson-1.4.3.jar','com.springsource.org.codehaus.jackson.mapper-1.4.3.jar',
                     'com.springsource.org.joda.time-1.5.2.jar' ]
  SERVICE_DRIVER_HASH = {
      "mysql-5.1" => 'com.springsource.com.mysql.jdbc-5.1.6.jar',
      "postgresql-9.0" => 'com.springsource.org.postgresql.jdbc4-8.3.604.jar',
      "maxdb-7.8" => 'com.sap.dbtech.jdbc-7.6.06.jar'
  }

  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.repository
    "repository"
  end

  def self.prepare(dir)
    FileUtils.cp_r(resource_dir, dir)
    output = %x[cd #{dir}; unzip -q resources/virgo.zip]
    raise "Could not unpack Virgo: #{output}" unless $? == 0
    webapp_path = File.join(dir, "virgo", "artifacts")
    server_xml = File.join(dir, "virgo", "config", "tomcat-server.xml")
    FileUtils.rm_f(server_xml)
    FileUtils.rm(File.join(dir, "resources", "virgo.zip"))
    FileUtils.mv(File.join(dir, "resources", "droplet.yaml"), File.join(dir, "droplet.yaml"))
    FileUtils.mkdir_p(webapp_path)
    webapp_path
  end
  
  def self.copy_jar(jar, dest)    
    jar_path = File.join(File.dirname(__FILE__), 'resources', jar)
    FileUtils.mkdir_p dest
    FileUtils.cp(jar_path, dest)
  end
  
  def self.copy_service_drivers(services, webapp_root)
    drivers = services.select { |svc|
      SERVICE_DRIVER_HASH.has_key?(svc[:label])
    }
    drivers.each { |driver|      
      driver_dest = File.join(webapp_root, "..", Virgo.repository,"usr")
      copy_jar SERVICE_DRIVER_HASH[driver[:label]], driver_dest
    } if drivers
  end
  
  def self.prepare_stager(webapp_root)
    dest = File.join(webapp_root, "..", Virgo.repository,"usr")
     copy_jar AUTOSTAGING_JAR , dest
     AUTOSTAGING_DEP.each{ |jar|
        copy_jar jar , dest
       }
  end
  
  def self.detect_file_extension(webapppath)
    Dir.chdir(webapppath) do
      if !Dir.glob("*.plan").empty?
        return "plan"
      elsif !Dir.glob("*.par").empty?
        return "parpacked"
      end
    end

    manifest_mf = File.join(webapppath, "META-INF/MANIFEST.MF")
    if File.file? manifest_mf
      manifest = YAML.load_file(manifest_mf)
      return "jar" if manifest["Bundle-SymbolicName"]
      return "par" if manifest["Application-SymbolicName"]
    end

    "war"
  end

end
