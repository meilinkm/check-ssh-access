# check-ssh-access
Bash script to test root SSH access

This script can be run on any Linux / UNIX system that has bash installed/available.

Please run the script as user "root".

The script will attempt to discover hostnames on the system, and will probe for SSH access to other hosts, as user root.
The script can be used to check if the proper SSH keys have been set up for user root. And it can be used to discover to which other hosts the root user will have access, and as such can be used to test the system security. Please remove any SSH keys for user root, if remote access is not required.
