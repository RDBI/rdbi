# FIXME Methlab, maybe?

RDBI::Schema = Struct.new(
  :columns,
  :tables
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

# vim: syntax=ruby ts=2 et sw=2 sts=2
