#!/usr/bin/ruby -w

###############################################################################
# Copyright (C) 2006, 2007 by Tassilo Horn
#
# Author: Tassilo Horn <tassilo@member.fsf.org>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program ; see the file COPYING.  If not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
###############################################################################

require 'optparse' # Command line option parsing
require 'dbm'      # DBM database interface

##
# A RDictCcEntry contains a Hash
#
#     phrase => [translation1, ..., translationN]
#
# and is heavily used while importing the Dict.cc CSV-file. The String returned
# by to_s() encodes a RDictCcEntry as string, which becomes the value of some
# keyword in the DBM database. After importing the Dict.cc CSV-file to DBM
# database files the only method used is the static format_str(str), which
# takes a string encoded RDictCcEntry (DBM-value) and formats them
# userfriendly.
class RDictCcEntry

  @@output_format = :normal

  def self.set_output_format( format )
    @@output_format = format
  end

  def initialize
    @value_hash = {}
  end

  ##
  # Append 'phrase' and 'translation'. If this 'phrase' already exists as key,
  # then simply append 'translation' to the value array.
  def append(phrase, translation)
    phrase.strip!
    translation.strip!
    if @value_hash[phrase].nil?
      @value_hash[phrase] = [translation]
    else
      @value_hash[phrase] << translation
    end
  end

  ##
  # Encodes this RDictCcEntry as string which is used to store entries as
  # values of the DBM database.
  def to_s
    s = ""
    # The results should be listed from shortest (exact) to longest match. So
    # we store it that way.
    ary = @value_hash.sort { |a, b| a[0].size <=> b[0].size }
    ary.each do |elem|
      s << "#{elem[0]}=<>"
      elem[1].each do |val|
        s << "#{val}:<>:"
      end
      s.gsub!(/:<>:$/, '#<>#')
    end
    s << "\n"
    s
  end

  ##
  # Given a string-encoded (with to_s()) RDictCcEntry formats it in a readable,
  # userfriendly way.
  def RDictCcEntry.format_str( str)
    parts = str.strip!.split(/#<>#/)
    s = ""
    parts.each do |part|
      subparts = part.split(/=<>/)
      if @@output_format == :compact
        s << "- " + subparts[0] + ": "
      else
        s << subparts[0] + ":\n"
      end
      subparts[1].split(/:<>:/).each do |trans|
        if @@output_format == :compact
          s << trans + " / "
        else
          s << "    - " + trans + "\n"
        end
      end
      if @@output_format == :compact
        s << "\n"
      end
    end
    s
  end
end

##
# When the '-i | --import' is given this class builds the DBM files out of the
# textual dict file you can download at http://www.dict.cc
class RDictCcDatabaseBuilder
  ##
  # Creates a new DatabaseBuilder, initializes it with the textual dict file
  # and creates the ~/.rdictcc directory.
  def initialize( import_file )
    @import_file = import_file
    if !File.exists? $dict_dir
      Dir.mkdir $dict_dir
    end
  end

  ##
  # Imports the dict.cc file given in the constructor and builds/writes the
  # database files.
  def import
    # German => English
    read_dict_file(:de)
    write_database(:de)
    # English => German
    read_dict_file(:en)
    write_database(:en)
  end

  ##
  # Below go the private things...
  private

  ##
  # Writes the contents of '@dict' to DBM file DICT_FILE_DE if sym == :de or
  # to DICT_FILE_EN otherwise.
  def write_database( sym )
    if sym == :de
      db_file = DICT_FILE_DE
    else
      db_file = DICT_FILE_EN
    end

    if File.exists?(db_file)
      puts "** Going to delete old database #{db_file}"
      File.delete(db_file)
      puts "** Deleted old database #{db_file}"
    end
    # Write to db
    puts "** writing DBM database file..."
    DBM.open(db_file, 0644, DBM::NEWDB) do |dbm|
      i = 0
      @dict.each_pair do |keyword, value|
        dbm[keyword] = value.to_s
        i += 1
        puts "Stored #{i} / #{@dict.size} values" if i % 1000 == 0
      end
    end

    # Now @dict is useless, so get rid of it
    @dict = nil
    GC.start
    puts "** Database building done!"
  end

  ##
  # Builds the '@dict' Hash from 'dict_file'. If symbol 'sym' is :de, the
  # DE-EN-Dictionary will be build, else the EN-DE is build.
  def read_dict_file( sym )
    @dict = {}
    # No queries allowed until reading finishes
    puts "** Reading dict file (#{sym})"
    IO.foreach(@import_file) do |line|
      line.strip!
      # skip empty lines and comments
      next if line =~ /^#/ or line =~ /^\s$/ or line.empty?

      # add the line to the dict
      add_line(line, sym)
    end
    puts "** built dict with #{@dict.size} entries"
  end

  ##
  # Add the line 'str' to '@dict'.
  def add_line( str, sym )
    # split the line
    if sym == :de
      phrase, translation = str.split('::')
    else
      translation, phrase = str.split('::')
    end
    word = extract_word(phrase)

    ## debug
    # puts word
    ## debug

    # Add another entry
    if !word.nil?
      @dict[word] ||= RDictCcEntry.new
      @dict[word].append(phrase, translation)
    end
  end

  ##
  # Cause the CSV-file contains phrases we cannot be sure what is the most
  # important word. This method strikes out everything between parenthesis, and
  # if multiple words stay over, simply takes the longes one.
  def extract_word( phrase )
    w = phrase.gsub(/(\([^(]*\)|\{[^{]*\}|\[[^\[]*\])/, '').strip.downcase
    return nil if w.empty? # No empty strings
    # Now return the longest word, hoping that it's the most important, too
    ary = w.gsub(/[^üäöß\w\s-]/, '').split # öäüß are no word chars currently!
    ary.sort!{ |x,y| y.length <=> x.length }
    ary[0] # The longest element is the first
  end
end

class RDictCcQueryEvaluator

  def initialize
    if !File.exists? $dict_dir
      puts "There's no "+ $dict_dir +
        " directory! You have to import an dict.cc\n" +
        "database file first. See\n" +
        "  $ rdictcc.rb --help\n" +
        "for more information."
      exit
    end
  end

  ##
  # Opens each database and yields the given block, handing over the data base
  # handle.
  def read_db
    for file in [DICT_FILE_DE, DICT_FILE_EN] do
      if file == DICT_FILE_DE
        puts "{DE-EN}"
      else
        puts "\n{EN-DE}"
      end

      DBM.open(file, nil, DBM::READER) do |dbm|
        yield dbm
      end
    end
  end

  ##
  # Delegates queries according to query type.
  def query( query )
    query.downcase!
    case query
    when /^:r:/ then query_regexp query.gsub(/^:r:/, '')
    when /^:f:/ then query_fulltext_regexp query.gsub(/^:f:/, '')
    else query_simple query
    end
  end

  ##
  # Simple hash lookup. Complexity: O(1)
  def query_simple( query )
    read_db do |dbm|
      puts RDictCcEntry.format_str(dbm[query]) if !dbm[query].nil?
    end
  end

  ##
  # Regexp lookup. Complexity: O(n)
  def query_regexp( query )
    read_db do |dbm|
      dbm.each_key do |key|
        puts RDictCcEntry.format_str(dbm[key]) if key =~ /#{query}/
      end
    end
  end

  ##
  # Fulltext regexp lookup. Complexity: O(n)
  def query_fulltext_regexp( query )
    read_db do |dbm|
      dbm.each_value do |raw_val|
        val = RDictCcEntry.format_str(raw_val)
        match_line_found = false
        val.each_line do |line|
          if line =~ /^\s+/
            if match_line_found
              puts line
            else
              # Skip lines starting with blanks, because these are already
              # translations and they don't belong to the matching line.
              next
            end
          else
            match_line_found = false
          end
          if line.downcase =~ /#{query}/
            puts line
            match_line_found = true
          end
        end
      end
    end
  end

  def show_db_sizes
    read_db do |dbm|
      i = 0
      # That's probably faster and less memory consuming than
      # dbm.entries.size...
      dbm.each { |e| i += 1 }
      puts "Database has #{i} entries"
    end
  end
end

def interactive_mode
  puts "Welcome to rdictcc's interactive mode. This mode will read from stdin\n" +
    "and print the translations until it reads ^Q (literally, not Ctrl-Q)."
  evaluator = RDictCcQueryEvaluator.new
  print "=> "
  while word = gets.chomp
    puts
    if word == "^Q" then break end
    evaluator.query word
    puts "--------------------------------------------------------------------------------"
    print "=> "
  end
  puts "Bye."
  exit 0
end

##
# Here we go...
$dict_dir = File.expand_path '~/.rdictcc'
$query_str = ""
options = OptionParser.new do |opts|
  opts.banner = "Usage: rdictcc.rb [database_import_options]\n" +
    "       rdictcc.rb [misc_options]\n" +
    "       rdictcc.rb [query_option] QUERY\n" +
    "       rdictcc.rb\n"

  opts.separator ""
  opts.separator "If no option nor QUERY is given, you'll enter rdictcc's interactive mode."

  opts.separator ""
  opts.separator "Database building options:"
  opts.on("-i", "--import DICTCC_FILE",
          "Import the dict file from dict.cc") do |file|
    db_builder = RDictCcDatabaseBuilder.new(file)
    db_builder.import
    exit 0
  end

  opts.separator ""
  opts.separator "Misc options:"
  opts.on("-v", "--version", "Show rdictcc.rb's version") do
    # TODO: Set version after changes!
    puts "<2008-03-05 Wed 09:29>"
    exit 0
  end

  opts.on("-S", "--size", "Show the number of entries in the databases") do
    RDictCcQueryEvaluator.new.show_db_sizes
    exit 0
  end

  opts.on("-d", "--directory PATH",
          "Use PATH instead of ~/.rdictcc/") do |path|
    $dict_dir = File.expand_path path
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit 0
  end

  opts.separator ""
  opts.separator "Format options:"
  opts.on("-c", "--compact", "Use compact output format") do
    RDictCcEntry.set_output_format :compact
  end


  opts.separator ""
  opts.separator "Query option:"
  opts.on("-s", "--simple", "Translate the word given as QUERY (default)") do
    # No need to do anything...
  end

  opts.on("-r", "--regexp", "Translate all words matching the regexp QUERY") do
    $query_str = ":r:"
  end

  opts.on("-f", "--fulltext", "Translate all sentences matching the regexp QUERY") do
    $query_str = ":f:"
  end
end.parse!

# catch queries without QUERY
if ARGV.join(" ").empty?
  interactive_mode
end

DICT_FILE_DE = $dict_dir + '/' + 'dict_de'
DICT_FILE_EN = $dict_dir + '/' + 'dict_en'

evaluator = RDictCcQueryEvaluator.new
evaluator.query($query_str.concat(ARGV.join(" ")))
