#!/usr/bin/env ruby
################################################################################
#  Copyright 2007-2008 Codehaus Foundation
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
################################################################################
#
# NOTE: This script does NOT make any changes to your repository; it just creates the script to do so!
#
# When svndumpfilter is used to filter revisions from a Subversion dump,
# the placeholder revisions have no date or time
#
# To be able to do date ranged queries, you need the date to be set (as subversion
# does a binary search of revisions; hitting a null-dated revision breaks it)
#
# This script reads an svn log script (XML format), then creates a script that contains
# appropriate property setting commands. It will be slow.
#
# You will need to ensure that:
# a) the post-revprop-change script does not send email! (it will spam users)
# b) the pre-revprop-change script allows changes to svn:date properties
#    #!/bin/sh
#    exit 0
#
#


require 'rexml/document'


def feedback(msg)
  STDERR.write(msg)
  STDERR.write("\n")
end

def read_log(url)
  feedback("Scanning repository")
  cmd = "svn log --xml #{url}"
  feedback("  " + cmd)
  output = `#{cmd}`
end

def parse_log(xml)
  # extract event information
  feedback "Parsing log"
  doc = REXML::Document.new(xml)

  feedback "Sorting revisions"
  last_date = nil
  revisions = []
  logentries = {}
  doc.elements.each('/log/logentry') do |logentry|
    revision = logentry.attributes['revision'].to_i

    author = logentry.elements['author']
    author = author.text if author

    date = logentry.elements['date']
    date = date.text if date

    revisions << revision
    logentries[revision.to_i] = {
      :revision => revision,
      :author => author,
      :date => date
    }
  end
  
  return revisions.sort.collect { |revision| logentries[revision] }
end

def generate_propsets(logentries)
  feedback "Navigating revisions"
  last_date = nil
  propsets = []
  logentries.each { |logentry|
    revision = logentry[:revision]
    date = logentry[:date]

    if not date
      propsets << "svn propset --revprop -r #{revision} svn:date #{last_date} #{URL}"
    else
      last_date = date
    end
  }
  
  return propsets
end

if ARGV.length < 1
  feedback "Usage:"
  feedback " set-svn-date <svn url>"
  feedback ""
  feedback "NOTE: This script does NOT make any changes to your repository; it just creates the script to do so!"
  exit -1
end

URL = ARGV[0]
url = ARGV[0]

# get the XML data as a string
xml = read_log(url)

logentries = parse_log(xml)

propsets = generate_propsets(logentries)

if propsets.empty?
  feedback "No un-dated revisions found"
else
  puts "#!/bin/sh"
  for propset in propsets
    puts propset
  end
end

