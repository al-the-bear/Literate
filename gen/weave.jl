title = ""
block_locations = Dict{String, Array{Int, 1}}()
block_use_locations = Dict{String, Array{Int, 1}}()

function get_locations(source)
    lines = readlines(IOBuffer(source))
    sectionnum = 0   # Which section is currently being parsed
    in_codeblock = false   # Whether we are parsing a codeblock or not

    for line_num = 1:length(lines)
        line = lines[line_num] |> chomp # Use chomp to remove the \n

        if startswith(line, "@title")
global title = strip(line[7:end])

        elseif startswith(line, "@s")
            sectionnum += 1
        elseif startswith(line, "---")
in_codeblock = true
if ismatch(r"^---$", line)
    in_codeblock = false
    continue
end
block_name = line[4:end] |> strip # Remove the ---

if contains(block_name, "+=")
    plus_index = search(block_name, "+")[end] # Get the index of the "+" (the [end] is to get the last occurrence)
    block_name = block_name[1:plus_index-1] |> strip # Remove the "+=" and strip any whitespace
end

if !haskey(block_locations, block_name) # If this block has not been defined in the dict yet
    block_locations[block_name] = [sectionnum] # Create a new slot for it and add the current paragraph num
elseif !(sectionnum in block_locations[block_name]) # If the current paragraph num isn't already in the array
    push!(block_locations[block_name], sectionnum) # Add it
end


        elseif in_codeblock && startswith(strip(line), "@{")
line = strip(line)
block_name = line[3:end-1] # Substring to just get the block name

# Pretty much the same as before
if !haskey(block_use_locations, block_name)
    block_use_locations[block_name] = [sectionnum]
elseif !(sectionnum in block_use_locations[block_name])
    push!(block_use_locations[block_name], sectionnum)
end

        end
    end
end

function write_markdown(markdown, out)
    if markdown != ""
        html = Markdown.parse(markdown) |> Markdown.html
        # Here is where we replace \(escaped character code) to what it should be in HTML
        html = replace(html, "\\&lt;", "<")
        html = replace(html, "\\&gt;", ">")
        html = replace(html, "\\&#61;", "=")
        html = replace(html, "\\&quot;", "\"")
        html = replace(html, "&#36;", "\$")
        html = replace(html, "\\\$", "&#36;")
        write(out, "$html\n")
    end
end

function weave(inputstream, outputstream)
    out = outputstream

    input = readall(inputstream)
    get_locations(input)
    lines = readlines(IOBuffer(input))

start_codeblock = "<pre class=\"prettyprint\">\n"
end_codeblock = "</pre>\n"

scripts = """<script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js"></script>
             <script src='https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML'></script>
             <script type="text/x-mathjax-config"> MathJax.Hub.Config({tex2jax: {inlineMath: [['\$','\$']]}}); </script>"""

css = ""
files = readdir(pwd()) # All the files in the current directory
if "default.css" in files
    css = readall("$(pwd())/default.css") # Read the user's default.css
else
    css = readall("$gen/default.css") # Use the default css
end

if "colorscheme.css" in files
    css *= readall("$(pwd())/colorscheme.css") # Read the user's colorscheme.css
else
    css *= readall("$gen/colorscheme.css") # Use the default colorscheme
end


base_html = """<!doctype html>
               <html>
               <head>
               <meta charset="utf-8">
               <title>$title</title>
               $scripts
               <style>
               $css
               </style>
               </head>
               <body>
               """

write(out, base_html)

sectionnum = 0 # Which section number we are currently parsing
in_codeblock = false # Whether or not we are parsing a some code
in_prose = false # Whether or not we are parsing prose
markdown = "" # This variable holds the current markdown that needs to be transformed to html

cur_codeblock_name = "" # The name of the current codeblock begin parsed


    for line_num = 1:length(lines)
        line = lines[line_num] |> chomp

        if startswith(line, "@codetype")
            continue
        end

if line == ""
    # This was a blank line
    markdown *= "\n" # Tell markdown this was a blank line
    continue
end

if startswith(line, "codetype") # Ignore this line
    continue
end

if ismatch(r"^---.+$", line) # Codeblock began
# A code block just began
in_prose = false
in_codeblock = true
# Write the current markdown
write_markdown(markdown, out)
# Reset the markdown
markdown = ""

write(out, "<div class=\"codeblock\">\n")
name = strip(line[4:end]) # The codeblock name

file = false # Whether or not this name is a file name
adding = false # Whether or not this block is a +=

if contains(name, "+=")
    name = strip(name[1:search(name, "+")[end]-1]) # Remove the += from the name
    adding = true
end

cur_codeblock_name = name
file = ismatch(r"^.+\w\.\w+$", name)

definition_location = block_locations[name][1]
output = "$name <a href=\"#$definition_location\">$definition_location</a>" # Add the link to the definition location
output = "{$output} $(adding ? "+" : "")≡" # Add the = or +=

if file
    output = "<strong>$output</strong>" # If the name is a file, make it bold
end

write(out, "<p class=\"notp\" id=\"$name$sectionnum\"><span class=\"codeblock_name\">$output</span></p>\n")
# We can now begin pretty printing the code that comes next
write(out, start_codeblock)

elseif ismatch(r"^---$", line) # Codeblock ended
# A code block just ended
in_prose = true
in_codeblock = false

# First start by ending the pretty printing
write(out, end_codeblock)
# This was stored when the code block began
name = cur_codeblock_name

locations = block_locations[name]
if length(locations) > 1
    links = "" # This will hold the html for the links
    loopnum = 0
    for i = 2:length(locations)
        location = locations[i]
        if location != sectionnum
            loopnum += 1
            punc = "" # We might need a comma or 'and'
            if loopnum > 1 && loopnum < length(locations)-1
                punc = ","
            elseif loopnum == length(locations)-1 && loopnum > 1
                punc = "and"
            end
            links *= "$punc <a href=\"#$location\">$location</a>"
        end
    end
    if loopnum > 0
        write(out, "<p class=\"seealso\">See also section$(loopnum > 1 ? "s" : "") $links.</p>\n")
    end
end

# Top level codeblocks such as files are never used, so we have to check here
if haskey(block_use_locations, name)
    locations = block_use_locations[name]
    output = "<p class=\"seealso\">This code is used in section$(length(locations) > 1 ? "s" : "")"
    for i in 1:length(locations)
        location = locations[i]
        punc = ""
        if i > 1 && i < length(locations)
            punc = ","
        elseif i == length(locations) && i != 1
            punc = " and"
        end
        output *= "$punc <a href=\"#$location\">$location</a>"
    end
    output *= ".</p>\n"
    write(out, output)
end

# Close the "codeblock" div
write(out, "</div>\n")

elseif startswith(line, "@s") && !in_codeblock # Section began
if sectionnum != 1
    # Every section is part of a div. Here we close the last one, and open a new one
    write(out, "</div>")
end
write(out, "<div class=\"section\">\n")

# Write the markdown. It is possible that the last section had no code and was only prose.
write_markdown(markdown, out)
# Reset the markdown
markdown = ""

in_section = true
sectionnum += 1
heading_title = strip(line[3:end])
write(out, "<p class=\"notp\" id=\"$sectionnum\"><h4 $(heading_title == "" ? "class=\"noheading\"" : "")>$sectionnum. $heading_title</h4></p>\n")

elseif startswith(line, "@title") # Title created
write(out, "<h1>$(strip(line[7:end]))</h1>\n")

else
    if in_codeblock
line = replace(line, "&", "&amp;")
line = replace(line, "<", "&lt;")
line = replace(line, ">", "&gt;")
while ismatch(r"@{.*?}", line)
    if !startswith(strip(line), "@{") && in_codeblock
        break
    end
    m = match(r"@{.*?}", line)
    name = line[m.offset + 2:m.offset + length(m.match)-2] # Get the name in curly brackets
    location = block_locations[name][1]
    if in_codeblock
        anchor = " <a href=\"#$location\">$location</a>"
        links = "<span class=\"nocode\">{$name$anchor}</span>" # The nocode is so that this is not pretty printed
        line = replace(line, m.match, links)
    else
        anchor = "[$location](#$location)"
        links = "{$name$anchor}"
        line = replace(line, m.match, links)
    end
end

write(out, "$line\n")

    else
while ismatch(r"@{.*?}", line)
    if !startswith(strip(line), "@{") && in_codeblock
        break
    end
    m = match(r"@{.*?}", line)
    name = line[m.offset + 2:m.offset + length(m.match)-2] # Get the name in curly brackets
    location = block_locations[name][1]
    if in_codeblock
        anchor = " <a href=\"#$location\">$location</a>"
        links = "<span class=\"nocode\">{$name$anchor}</span>" # The nocode is so that this is not pretty printed
        line = replace(line, m.match, links)
    else
        anchor = "[$location](#$location)"
        links = "{$name$anchor}"
        line = replace(line, m.match, links)
    end
end

markdown *= line * "\n"

    end
end

    end

write_markdown(markdown, out)
write(out, "</body>\n</html>\n")

end

