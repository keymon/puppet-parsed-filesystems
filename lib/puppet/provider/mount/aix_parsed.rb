require 'puppet/provider/parsedfile'
require 'puppet/provider/mount'

filesystems_file = "/tmp/filesystems"

Puppet::Type.type(:mount).provide(
  :aix_parsed,
  :parent => Puppet::Provider::ParsedFile,
  :default_target => fstab,
  :filetype => :flat
) do

#/home:
#        dev             = /dev/hd1
#        vfs             = jfs2
#        log             = /dev/hd8
#        mount           = true
#        check           = true
#        vol             = /home
#        free            = false
#        quota           = userquota,groupquota


  include Puppet::Provider::Mount
  #confine :exists => fstab

  commands :mountcmd => "mount", :umount => "umount"

  @platform = Facter["operatingsystem"].value
  case @platform
  when "Solaris"
    @fields = [:device, :fstype, :log, :mount_at_boot, :check, :vol, :free, :atboot, :options]
  else
    @fields = [:device, :name, :fstype, :options, :dump, :pass]
    @fielddefaults = [ nil ] * 4 + [ "0", "2" ]
  end

  text_line :comment, :match => /^\s*#/
  text_line :blank, :match => /^\s*\n\s*\n\s*$/

  optional_fields  = @fields - [:device, :name, :blockdevice]
  mandatory_fields = @fields - optional_fields

  # fstab will ignore lines that have fewer than the mandatory number of columns,
  # so we should, too.
  field_pattern = '(\s*(?>\S+))'
  text_line :incomplete, :match => /^(?!#{field_pattern}{#{mandatory_fields.length}})/

  record_line self.name, :fields => @fields, :separator => /\n\s+/, :joiner => "\t", :optional => optional_fields

end



hash={}
stanza_key=nil
s.split("\n").each { |line| 
 if line =~ /^\s*\*/ or line =~ /^\s*$/
   next # Ignore comments and empty lines
 elsif m = line.match( /\s*([^:]*)\s*:/ )
  stanza_key = m[1]
  hash[stanza_key] = {}
 elsif m = line.match(/\s*([^\s]*)\s*=\s*(.*)/)
  hash[stanza_key][m[1]] = m[2] if stanza_key
 end 
}

name="/srv/mnt/dsk/cgxora101"
new_str="/srv/mnt/dsk/cgxora101:\n\tdev\t\t= /dev/cgxora10balblalblslalala1lv\n\tvfs\t\t= jfs2\n\tlog\t\t= /dev/loglv00\n\tmount\t\t= true\n\toptions\t\t= rw\n\taccount\t\t= true"
print s.gsub(/^\s*#{name}\s*:\s*\n(.*=.*\n)*/, "\n#{new_str}\n")
