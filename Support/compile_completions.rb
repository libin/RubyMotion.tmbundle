##!/usr/bin/env ruby -wKU

require 'rexml/document'
require 'pp'

# RubyMotion Bridgesupport default path
RubyMotionPath = "/Library/RubyMotion/data/6.1/BridgeSupport/"

class RubyMotionCompletion

  # Compile the RubyMotion completion plist
  def compile
    # Load the directory entries
    if File.exists? RubyMotionPath

      # This will hold the dict fragments
      fragment = []

      Dir.foreach(RubyMotionPath) do |x|

        if x[0,1] != '.'

          file = File.open( "" << RubyMotionPath << x )
          doc = REXML::Document.new( file )

          if doc.root.has_elements?

            puts "Compiling: %s" % x

            doc.root.each_element do |node|

              case node.name

                when "class"
                  self.parse_class( node, fragment )

                when "informal_protocol"
                  self.parse_class( node, fragment )
                
                when "function"
                  self.parse_function( node, fragment )
                
                when "constant"
                  self.parse_constant( node, fragment )
                
                when "enum"
                  self.parse_enum( node, fragment )

              end

            end

          end

        end

      end
      
      # Sort the fragment
      fragment.sort! do | a, b |
        # Get the display string
        a_name = a[1].text.gsub( /[:\.]/, "" ).gsub( /^(.*?)\s\(.*/, "\\1" )
        b_name = b[1].text.gsub( /[:\.]/, "" ).gsub( /^(.*?)\s\(.*/, "\\1" )

        a_name <=> b_name
      end
      
      # Remove duplicates, not sure if this really works
      fragment.uniq!

      # Output results
      plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><array>%s</array></plist>"  % fragment.to_s.gsub( /\>\</, ">\n<" )
      
      return plist
    end

  end
  
  # Creates a dict element
  def create_dict( display, insert=nil, match=nil )
    elem_dict = REXML::Element.new( "dict" )

    # Display
    elem_display = REXML::Element.new( "key", elem_dict ).add_text( "display" )
    elem_string = REXML::Element.new( "string", elem_dict ).add_text( display )

    # Insert
    if insert != nil
      elem_display = REXML::Element.new( "key", elem_dict ).add_text( "insert" )
      elem_string = REXML::Element.new( "string", elem_dict ).add_text( insert )
    end
    
    # Match
    if match != nil
      elem_display = REXML::Element.new( "key", elem_dict ).add_text( "match" )
      elem_string = REXML::Element.new( "string", elem_dict ).add_text( match )
    else
      elem_display = REXML::Element.new( "key", elem_dict ).add_text( "match" )
      elem_string = REXML::Element.new( "string", elem_dict ).add_text( display.chomp( ":" ) )
    end

    return elem_dict
  end
  
  # Create an argument string
  def create_insert( method_name, method )
    i = 0
    idx = 1
    insert = ""
    prefixes = []
    arguments = []

    # Create the prefixes array
    if method.get_elements( "arg" ).length > 1
      prefixes = method_name.split( ":" )
      prefixes[0] = nil
    end
    
    # Create the arguments array
    method.each_element( "arg" ) do |param|
      prefix = ""

      # Construct prefix
      prefix = prefixes[i] + ":" if prefixes[i] != nil

      # Add argument to the array
      arguments << "%s${%d:%s %s}" % [ prefix, idx, param.attribute( "declared_type" ).to_s, param.attribute( "name" ).to_s ]

      # Increase counters
      i += 1
      idx += 1
    end
    
    # Construct insert string
    insert = arguments.join( ", " )
    insert = "(%s)" % insert unless insert == ""
    
    return insert
  end

  # Returns a valid class definition
  def parse_class( node, fragment )
    class_name = node.attribute( "name" ).to_s

    # Add the main class to the fragment
    fragment << create_dict( class_name )

    # Traverse class methods
    node.each_element( "method" ) do |method|
      
      # Prepend method name with class name if this is a class method
      method_name = method.attribute( "selector" ).to_s
      method_name = "%s.%s" % [ class_name, method_name ] if method.attribute( "class_method" )

      # Check for the number of arguments
      case method.get_elements( "arg" ).length
        
        # No arguments so strip the ':' if there is one
        when 0
          fragment << create_dict( method_name )
        
        # A single argument
        when 1
          fragment << create_dict( method_name, self.create_insert( method_name, method ) )

        else
          method_match = method_name.slice( 0, method_name.index( ":" ) )
          fragment << create_dict( method_name, self.create_insert( method_name, method ), method_match )

      end

    end
    
    return fragment
  end

  # Returns a valid class definition
  def parse_function( node, fragment )
    function_name = node.attribute( "name" ).to_s

    # Check for the number of arguments
    case node.get_elements( "arg" ).length
      
      # No arguments so strip the ':' if there is one
      when 0
        fragment << create_dict( function_name )
      
      # More than one argument
      else
        fragment << create_dict( function_name, self.create_insert( function_name, node ) )

    end

    return fragment

  end

  # Returns a valid constant definition
  def parse_constant( node, fragment )
    const_match = node.attribute( "name" ).to_s
    const_type = node.attribute( "declared_type" ).to_s

    # Make sure the first letter is always uppercase, for RubyMotion
    const_match = "%s%s" % [ const_match[0,1].upcase, const_match[1..-1] ]

    const_display = "%s (%s)" % [ const_match, const_type ]

    # Add the element
    fragment << create_dict( const_display, nil, const_match )
    
    return fragment
  end

  # Returns a valid enum definition
  def parse_enum( node, fragment )
    enum_match = node.attribute( "name" ).to_s
    enum_val = node.attribute( "value" ).to_s

    # Make sure the first letter is always uppercase, for RubyMotion
    enum_match = "%s%s" % [ enum_match[0,1].upcase, enum_match[1..-1] ]

    enum_display = "%s (%s)" % [ enum_match, enum_val ]

    # Add the element
    fragment << create_dict( enum_display, nil, enum_match )
    
    return fragment
  end

end

# Compile the completion tags
# RubyMotionCompletion.new().compile

