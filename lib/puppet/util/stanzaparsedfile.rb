require 'puppet'
require 'puppet/provider'
require 'puppet/util/filetype'
require 'puppet/util/fileparsing'

# 
# Implements an API to manage stanza based configuration files, with the format:
#
# stanza_name:
#  key1 = value1
#  key1 = value2
#
# This configuration is common in AIX systems.
# 
class  Puppet::Util::StanzaParsedFile

  include Enumerable

  # Target file where configuration is stored
  attr_accessor :backend
  # Hash of stanzas
  attr_accessor :target_hash
  # String with serialized content.
  attr_accessor :target_content

  # Configuration Backend. Default: Puppet filetype
  class ConfigBackend
    # Read content from file
    def read()
      @target_file.read()
    end
    def write(content)
      @target_file.backup()
      @target_file.write(content)
    end
    def initialize(filename)
      @target_file = Puppet::Util::FileType.filetype(:flat).new(filename)
    end
    
  end

  # Class representing an Stanza
  class Stanza
    include Enumerable

    # Stanza key or name
    attr_accessor :key

    # Hash with all keys and values
    attr_reader :hash
    
    # If this stanza is modified or new
    attr_accessor :is_modified

    # Check if this stanza is modified
    def modified?
      self.is_modified
    end
    
    # Key is included if included and it is not nil.
    def include?(param)
      @hash.include? param and not @hash[param].nil?
    end
    
    def [](param)
      @hash[param]
    end

    def set(param, value, modified = true)
      @hash[param] = value
      self.is_modified = true if modified 
    end
  
    def []=(param, value)
      self.set(param, value)
    end

    
    # Iterate over each param/value pair, as required for Enumerable, except
    # in nil values.
    def each
      @hash.each { |p,v| yield p, v unless v.nil? }
    end

    def clone
      self.class.new(@key, @hash, @modified)
    end

    # Merge this stanza with new values
    def merge(stanza)
      # Whe use the **stanza.hash.each**, so nil values (deleted values)
      # are also copied. 
      stanza.hash.each { |k, v|
        self[k] = v if @hash[k] and @hash[k] != v 
      }
    end

    def to_s
      max_tabs = 2
      self.each { |key, val|
        max_tabs = (key.to_s.size/8+1) if key and max_tabs < (key.to_s.size/8+1)
      }

      str = "#{@key}:"
      self.each { |key, val|
        tabs_str = "\t" * (max_tabs - key.to_s.size/8) 
        str += "\n\t#{key.to_s}#{tabs_str}= #{val}"
      }
      str
    end
    
    def initialize(key, hash = {}, modified = false)
      @key = key
      @hash = hash.clone
      @modified = modified
    end
   
  end

  # Get modified stanzas... 
  def modified
    @target_hash.find { |k,v| not v.nil? and v.modified?  }
  end

  # Get deleted stanzas... (nil value)
  def deleted
    @target_hash.find { |k,v| v.nil? }
  end
  
  # Check if this file is modified: There are modified or deleted stanzas
  def modified?
    not self.modified.empty? or not self.deleted.empty?
  end
  
  # Key is included if included and it is not nil.
  def include?(param)
    @target_hash.include? param and not @target_hash[param].nil?
  end
  
  # Get a stanza
  def [](param)
    @target_hash[param]
  end

  # Set an stanza. If given value is a "Stanza", clone it,
  # if is a Hash create a new stanza.
  # Set to nil to delete it.
  def set(param, value, modified)
    if value.nil?
      @target_hash[param] = nil
    elsif value.class == Stanza
      @target_hash[param] = value.clone
      @target_hash[param].is_modified = modified
      @target_hash[param].key = param
    elsif value.class == Hash
      @target_hash[param] = Stanza.new(param, value, modified)
    end
  end

  # Set a parameter. Set to nil to delete it.
  def []=(param, value)
    self.set(param, value, true)
  end
  
  # Add an stanza
  def add(param, value = nil)
    value = Stanza.new(param, {}, true) if value.nil?
    @target_hash[param] = value.clone
  end
  
  # Iterate over each param/value pair, as required for Enumerable.
  # Do not iterate on nil values (deleted values)
  def each
    @target_hash.each { |p,v| yield p, v unless v.nil? }
  end
   
  # Read the file content as an string.
  # Set refresh=true to force reload
  def content(refresh = false)
    if @target_content.nil? or refresh 
      @target_content = self.backend.read()
    end
    @target_content 
  end
  
  # Update the target file with hash data.
  # It will reload the data from disk and update only the modified values
  def flush()
    if self.update_content()
      self.backend.write(self.content())
    end
    self.content()
  end

  # Update the target file with hash data.
  # It will reload the data from disk and update only the modified values
  def update_content()
    # Read again the content
    new_content = self.backend.read()
    new_hash = self.class.parse_configuration(new_content)
        
    content_updated = false
    
    # For each stanza (Hash.each, not StanzaParsedFile.each)... nil values
    # are also considered
    self.target_hash.each { |stanza_key, stanza|
      # If stanza is nil, the stanza must be deleted
      if stanza.nil?
        new_content = self.class.delete_stanza(stanza_key, new_content)
        content_updated  = true
        next
      end
      
      # if stanza is not currently present, add it
      if not new_hash[stanza_key]
        new_hash[stanza_key] = stanza
        new_hash[stanza_key].is_modified = true
      else
        # Update modified values
        new_hash[stanza_key].merge(stanza)
      end
      
      if new_hash[stanza_key].modified?
        new_content = self.class.update_stanza(stanza_key, new_hash[stanza_key].to_s, new_content)
        content_updated  = true
      end
    }
    
    # Write it to disk
    if content_updated
      @target_content = new_content
    end
    
    content_updated
  end

  # Update an stanza in a configuration
  def self.update_stanza(stanza_key, new_hash, content)
    if content.match(/^\s*#{stanza_key}\s*:/)
      content.gsub(/^\s*#{stanza_key}\s*:\s*\n(.*=.*\n)*/, "\n#{new_hash}\n")
    else
      content.rstrip + "\n\n#{new_hash}\n\n"
    end
  end

  # Delete an stanza in a configuration
  def self.delete_stanza(stanza_key, content)
    if content.match(/^\s*#{stanza_key}\s*:/)
      content = content.gsub(/^\s*#{stanza_key}\s*:\s*\n(.*=.*\n)*/, "\n")
    end
    content
  end

  # Parse a stanza based file. It returns a hashmap where each key is the
  # stanza key and its value a Stanza of keys=value.
  def self.parse_configuration(config_content)
    hash = {}
    stanza_key = nil
    
    config_content.split("\n").each { |line|
      if line =~ /^\s*\*/
        next # Ignore comments
      elsif line =~ /^\s*$/
        next # Ignore empty lines
      elsif m = line.match( /\s*([^:]*)\s*:\s*$/ )
        stanza_key = m[1]
        hash[stanza_key] = Stanza.new(stanza_key)
      elsif m = line.match(/\s*([^\s]*)\s*=\s*"?(.*)"?/)
        hash[stanza_key].set(m[1].to_sym, m[2], false) if stanza_key
      else
        next # Incorrect line
      end 
    }
    hash
  end 

  def to_s
    str = ""
    self.each { |key, val|
      str += "\n#{val.to_s}\n"
    }
    str
  end

  def initialize(backend_instance)
    # Open the configuration file and load it.
    if backend_instance.class == ConfigBackend
      @backend = backend_instance
    elsif backend_instance.class == String
      @backend = ConfigBackend.new(backend_instance)
    else
      raise ArgumentError, "Must be a file path or a #{self.class}::ConfigBackend", backend_instance
    end 
    @target_hash = self.class.parse_configuration(self.content(true))
  end

end

