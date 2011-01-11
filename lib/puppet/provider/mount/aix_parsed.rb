#
# AIX mount provider. This solution modifies the /etc/filesystems
#
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
#  
require 'puppet/util/stanzaparsedfile'
require 'puppet/provider/mount'

aix_filesystems_configfile = "/tmp/filesystems"

class Puppet::Provider::Mount::Aix_Parsed < Puppet::Provider
  desc ""

  # Mount functionality from puppet
  include Puppet::Provider::Mount

  # The config file
  def self.stanza_config
    @stanza_config ||= Puppet::Util::StanzaParsedFile.new(aix_filesystems_configfile)
  end
  
  #-------------
  # Provider API
  # ------------

  # Return all existing instances  
  # The method for returning a list of provider instances.  Note that it returns
  # providers, preferably with values already filled in, not resources.
  def self.instances
    self.stanza_config.each { |stanza_key, stanza|
      objects << new({name => stanza_key})
    }
    objects
  end
 
  # Check that the user exists
  def exists?
    self.class.stanza_config.include? @resource[:name]
  end

  # Retrieve the current state from disk.
  def prefetch
    raise Puppet::DevError, "Somehow got told to prefetch with no resource set" unless @resource
    @property_hash = self.stanza_to_properties(self.class.stanza_config[@resource[:name]])
  end
  
  def create
    if self.exists?
      info "already exists"
      # The object already exists
      return nil
    end
    self.class.stanza_config[@resource.name] = self.properties_to_stanza(@resource)
  end 

  # Clear out the cached values.
  def flush
    self.class.stanza_config[@resource.name] = self.properties_to_stanza(@property_hash)
    self.class.stanza_config.flush()
    @property_hash.clear if @property_hash
  end

  # Delete the entry
  def delete
    unless exists?
      info "already absent"
      # the object already doesn't exist
      return nil
    end

    self.class.stanza_config[@resource.name] = nil
    self.flush()
  end

  ##--------------------------------
  def properties_to_stanza(hash) 
    stanza = Puppet::Util::StanzaParsedFile::Stanza.new(@resource.name)
    hash.each { |key, val|
      case key
        when :ensure then
        when :name then
        when :atboot then
          if val == true or val == "true" or val == 1 then
            stanza[:mount] = "true"
          elsif val == false or val == "false" or val == 0 then
            stanza[:mount] = "false"
          elsif val == "readonly" and val == "automatic" and val == "removable" then
            stanza[:mount] = val
          end
        when :blockdevice then
          Puppet.debug "Param not valid in this provider '#{key.to_s}=#{val.to_s}' in  #{@resource.class.name} #{@resource.name}."
        when :options then
          stanza[:options] = val
        when :device then
          if 
          end
          stanza[:options] = val
        when :dump then
          true
        when :pass then
          true
        when :fstype then
          true
        else         
          Puppet.debug "Unknown param '#{key.to_s}=#{val.to_s}' in  #{@resource.class.name} #{@resource.name}."
      end
    }
  end

  def stanza_to_properties(properties) 
    #....
  end

  ##--------------------------------
  ## Call this method when the object is initialized, 
  ## create getter/setter methods for each property our resource type supports.
  ## If setter or getter already defined it will not be overwritten
  #def self.mk_resource_methods
  #  [resource_type.validproperties, resource_type.parameters].flatten.each do |prop|
  #    next if prop == :ensure
  #    define_method(prop) { get(prop) || :absent} unless public_method_defined?(prop)
  #    define_method(prop.to_s + "=") { |*vals| set(prop, *vals) } unless public_method_defined?(prop.to_s + "=")
  #  end
  #end
  #
  ## Define the needed getters and setters as soon as we know the resource type
  #def self.resource_type=(resource_type)
  #  super
  #  mk_resource_methods
  #end
  #
  ## Retrieve a specific value by name.
  #def get(param)
  #  @property_hash[symbolize(param)] 
  #end
  #
  ## Set a property.
  #def set(param, value)
  #  @property_hash[symbolize(param)] = value
  #  self.modified = true
  #end
  #
  #def initialize(resource)
  #  super
  #end  
 
end


