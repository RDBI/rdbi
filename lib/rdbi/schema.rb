RDBI::Schema = Struct.new(
  :columns,
  :tables,
  :type
)

RDBI::Column = Struct.new(
  :name,
  :type,
  :ruby_type,
  :precision,
  :scale,
  :nullable,
  :metadata,
  :default,
  :table
)

#
# RDBI::Schema is the metadata representation of a single schema "object", such
# as a single table or the data queried against during RDBI::Statement
# execution.
#
# FIXME stub docs -- elaborate
#
class RDBI::Schema
  ##
  # :attr_reader: columns
  #
  # FIXME

  ##
  # :attr_reader: tables
  #
  # FIXME

  ##
  # :attr_reader: type 
  #
  # FIXME
end

#
# RDBI::Column is the metadata representation of a single table column. You
# will typically access this via RDBI::Schema.
#
# FIXME stub docs -- elaborate
#
class RDBI::Column
  ##
  # :attr_reader: name 
  #
  # FIXME
  
  ##
  # :attr_reader: type
  #
  # FIXME
  
  ##
  # :attr_reader: ruby_type
  #
  # FIXME
  
  ##
  # :attr_reader: precision
  #
  # FIXME
 
  ##
  # :attr_reader: scale
  #
  # FIXME
  
  ##
  # :attr_reader: nullable
  #
  # FIXME
  
  ##
  # :attr_reader: metadata 
  #
  # FIXME

  ##
  # :attr_reader: default
  #
  # FIXME
  
  ##
  # :attr_reader: table
  #
  # FIXME
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
