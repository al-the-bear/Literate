mkdir source
# use with cygwin or some other linux shell on windows
# check markdown first into the right location in the project
# git clone https://github.com/zyedidia/dmarkdown lit/markdown; 
bin/tangle -odir source lit/*.lit
dub build --build=release