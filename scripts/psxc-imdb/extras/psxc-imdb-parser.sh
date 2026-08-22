#!/bin/bash

# Bash is very limited in formatting output. You'd do better in perl or some
# other "real" language. But since this is just an example, I'll do this in
# what most people manages to read. The script in itself is not important -
# the variables are, since I expect you to experiment a bit with this..
# If you manage to create a decent script which formats in a generic way,
# and don't mind spreading the wealth, please send it to me so I can include
# it.
#
VERSION=3.2

# Source shared library for API functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/psxc-imdb-lib.sh"

# Parse IMDB positional arguments using shared function from psxc-imdb-lib.sh
parse_imdb_args "$@"

#########################################################################
# From here on you should just paste/format the output to your liking.

#
# enter your code here....
#

#
#########################################################################
# You should always exit with a 0 - the parent won't give a crap anyway,
# but just to make sure...
exit 0

