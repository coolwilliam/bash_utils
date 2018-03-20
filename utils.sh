#!/bin/bash

if [ "$utils" ]; then
        return
fi

export utils="utils.sh"

# trim(str)
# remove blank space in both side
trim()
{
    echo $*
}

