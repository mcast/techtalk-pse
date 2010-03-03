#!/bin/bash -

source functions
add_history guestfish -a vm1.img
add_history guestfish -a vm2.img -m /dev/sda1
terminal
