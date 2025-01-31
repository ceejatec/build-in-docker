#!/bin/bash

# Make sure we're being run as a container entrypoint, so we don't
# destroy stuff
if [ "$1" != "unlikely-argument" ]; then
  echo "This script is intended to be used as an entrypoint for a container."
  echo "Do not run interactively."
  exit 1
fi

# Ensure uid and gid 1000 are available
USER1000=$(getent passwd 1000 | cut -d: -f1)
if [ -n "${USER1000}" ]; then
  userdel --remove ${USER1000}
fi
GROUP1000=$(getent group 1000 | cut -d: -f1)
if [ -n "${GROUP1000}" ]; then
  groupdel ${GROUP1000}
fi

# Create the `couchbase` user with UID 1000 and GID 1000
groupadd --gid 1000 couchbase
useradd couchbase -u 1000 -g couchbase -m -d /home/couchbase -s /bin/bash

# Set password, and add to sudoers if available
echo 'couchbase:couchbase' | chpasswd
if [ -d /etc/sudoers.d ]; then
  echo 'couchbase ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/couchbase
fi

# If docker.sock is available, ensure there's a group for it with the
# correct GID and that the couchbase user is in that group
if [ -e /var/run/docker.sock ]; then
  sock_gid=$(stat --format=%g /var/run/docker.sock)
  SOCK_GROUP=$(getent group ${sock_gid} | cut -d: -f1)
  if [ -z "${SOCK_GROUP}" ]; then
    SOCK_GROUP="docker$sock_gid"
    groupadd --gid ${sock_gid} ${SOCK_GROUP}
  fi

  usermod -a -G ${SOCK_GROUP} couchbase
fi

# Copy in the host user's SSH keys
mkdir -p /home/couchbase/.ssh
if [ -d "${HOSTHOME}/.ssh" ]; then
  cp -a "${HOSTHOME}/.ssh/"* /home/couchbase/.ssh
fi
chown -R couchbase:couchbase /home/couchbase/.ssh

# Copy in the host user's .gitconfig
if [ -e "${HOSTHOME}/.gitconfig" ]; then
  cp "${HOSTHOME}/.gitconfig" /home/couchbase/.gitconfig
  chown couchbase:couchbase /home/couchbase/.gitconfig
fi

exec sleep 1000000
