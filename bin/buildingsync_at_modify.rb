require 'rexml/document'
require 'tempfile'

# return line index of element
def line_index(file, list)
  tag = Hash.new

  # find line number of <auc:Address> and </auc:Ownership>
  File.foreach(file).with_index(1) do |line, index|
    (0...list.size).each { |i|
      if line.include?list[i]
        tag[list[i]] = index
      end
    }
  end
  return tag
end

# modify a generated bs file:
def modify_existing_bs_file()

  outdir = './bs_output/'
  if(File.exist?(outdir))
    Dir.glob(File.join(outdir, "*.xml")).each do |file|
      puts file
      content = ""

      # find line number of <auc:Address> and </auc:Ownership>
      list = ["<auc:Address>", "</auc:Ownership>"]
      index_list = line_index(file, list)
      
      addr_index = index_list["<auc:Address>"]
      ownership_index = index_list["</auc:Ownership>"]
      if(ownership_index == addr_index) 
        puts "WARNING: BuildingSync file missing important elements!"  
        exit()
      end

      remove = ownership_index - addr_index + 1
      (addr_index..ownership_index).each {|line| content += File.readlines(file)[line - 1]
      }

      filename = file.split(outdir)[1]
      id = filename.split('.xml')[0]

      # remove lines from <auc:Address> to </auc:Ownership>
      tmp = Tempfile.open(filename, outdir) do |fp|
        File.foreach(file) do |line|
          if $. >= addr_index and remove > 0
            remove -= 1
          else
            fp.puts line
          end
        end
        fp
      end
      FileUtils.copy(tmp.path, file)
      tmp.unlink

      # insert lines from <auc:Address> to </auc:Pwnership> before <auc:FloorsAboveGrade>
      i_index = line_index(file, ["<auc:FloorsAboveGrade>"])["<auc:FloorsAboveGrade>"] - 1
      tmp = Tempfile.open(filename, outdir) do |fp|
        File.readlines(file).insert(i_index, content).each do |line|
          fp.puts line
        end
        fp
      end
      FileUtils.copy(tmp.path, file)
      tmp.unlink

      # insert new properties before </auc:Report>
      xml = REXML::Document.new File.new(file)
      if (REXML::XPath.first(xml, "//auc:LinkedPremisesOrSystem")).nil?
        building_id = REXML::XPath.first(xml, "//auc:LinkedBuildingID").attributes["IDref"]
        fields = "          <auc:LinkedPremisesOrSystem>
            <auc:Building>
            <auc:LinkedBuildingID IDref='#{building_id}'/>
            </auc:Building>
          </auc:LinkedPremisesOrSystem>
          <auc:UserDefinedFields>
            <auc:UserDefinedField>
              <auc:FieldName>Audit Template Report Type</auc:FieldName>
              <auc:FieldValue>San Francisco Report</auc:FieldValue>
            </auc:UserDefinedField>
          </auc:UserDefinedFields>"

        l_index = line_index(file, ["</auc:Report>"])["</auc:Report>"] - 1 
        tmp = Tempfile.open(filename, outdir) do |fp|
          File.readlines(file).insert(l_index, fields).each do |line|
            fp.puts line
          end
          fp
        end
        FileUtils.copy(tmp.path, file)
        tmp.unlink
      end

      # Remove all start and end timestamp. Standard xml for JSON
      doc = REXML::Document.new File.new(file)
      doc.elements.delete_all("//auc:StartTimeStamp")
      doc.elements.delete_all("//auc:EndTimeStamp")
      doc.context[:attribute_quote] = :quote
      doc.write(File.open(file, "w"))
    end
  end
end

modify_existing_bs_file()