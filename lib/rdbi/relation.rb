RDBI::Relation = Struct.new(
  :columns,
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
  :table,
  :primary_key
)

#
# RDBI::Relation is the metadata representation of a single relational
# "object", such as a table or view, or the attribute tuple queried
# against during RDBI::Statement execution.
#
# RDBI::Relation is the foundation for type management via RDBI::Type, and as a
# result an incomplete relation will lead to type inconsistency. As a result,
# it is *critical* that driver authors implement RDBI::Relation properly.
#
# RDBI::Relation is a core Struct underneath the hood and will respond
# accordingly.
#
class RDBI::Relation
  ## :attr_reader: columns
  #
  # Array of RDBI::Column objects associated with this relation.
  #

  def tables
    warn "RDBI::Relation#tables is deprecated; query the constituent #columns results insead"
    columns.collect { |col| col.table }.any?.uniq rescue []
  end

  ##
  # :attr_reader: type 
  #
  # In some instances, the type (freeform, String) may be provided as an
  # optional hint as to what kind of relation this is.
  #
end

#
# RDBI::Column is the metadata representation of a single table column. You
# will typically access this via RDBI::Relation.
#
# In tables, columns can represent the columns of the schema. In queries,
# columns can represent anything that identifies the column of a result set.
# This includes aggregates, other functions, dynamic queries, etc.
#
class RDBI::Column
  ##
  # :attr_reader: name 
  #
  # The name of the column, as symbol.
  
  ##
  # :attr_reader: type
  #
  # The database-specific type, as symbol.
  
  ##
  # :attr_reader: ruby_type
  #
  # The ruby target type, as symbol. This is used by RDBI::Type to convert data
  # in rows. 
  
  ##
  # :attr_reader: precision
  #
  # The precision of the type. This is typically the first number in an
  # extended type form, such as +NUMBER(1)+.
  #
  # Precisions are not always *really* precision and this depends on the type.
  # Consult your database documentation for more information.
  #
 
  ##
  # :attr_reader: scale
  #
  # The scale of the type. This is typically the second number in an extended
  # type form, such as +NUMBER(10,2)+.
  #
  # As with precision, this may not *really* be scale and it is recommended you
  # consult your database documentation for specific, especially non-numeric,
  # types.
  #
  
  ##
  # :attr_reader: nullable
  #
  # Boolean: does this column accept null?
  
  ##
  # :attr_reader: metadata 
  #
  # Free-form field for driver authors to provide data that lives outside of
  # this specification.

  ##
  # :attr_reader: default
  #
  # The value provided to the column when it is not specified but requested for
  # use, such as in +INSERT+ statements.
  #
  
  ##
  # :attr_reader: table
  #
  # The table this column belongs to, if known, as symbol.
  #
  
  ##
  # :attr_reader: primary_key
  #
  # Is this column a primary key?
  #
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
