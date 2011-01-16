#
# **DEPRECATED** RDBI::Schema is the deprecated name for RDBI::Relation.
#

require 'rdbi/relation'

warn "WARNING: deprecated class RDBI::Schema is an alias for preferred RDBI::Relation"

::RDBI::Schema = ::RDBI::Relation
