#!/usr/bin/env ruby

require 'rdbi/driver/mock'

# -- this class is _not_ defined in rdbi-driver-....rb, as is commonly done

class RDBI::Driver::StringSubdirCached < RDBI::Driver::Mock; end
