#!/bin/bash -

source functions

cat > $HISTFILE <<EOF
echo "This is a Tech Talk PSE example"
EOF

exec $TERMINAL
