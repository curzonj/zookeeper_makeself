This builds a self contained zookeeper + exhibitor tarball with a script wrapped around
it. The script unpacks the tarball, sets up the environment and then chroots into it.
Runit is used to supervise exhibitor and exhibitor configures and launches zookeeper.

It should be able to run in just about any environment, all it's dependencies are inside
the tarball. The inside of the chroot is based on ubuntu core: https://wiki.ubuntu.com/Core

# Building

    ./chroot.sh

# Running

You can find more exhibitor commandline options here: https://github.com/Netflix/exhibitor/wiki/Running-Exhibitor

    sudo ./package.bin -- -c file --fsconfigdir /opt/exhibitor_run

The package.bin script will pass all the commandline options after the -- to exhibitor.
The path for --s3credentials needs to be an absolute path due to the fact that the script
that receives the commandline options will be not be running at the current path and also
can't resolve the `~` tilde home directory reference.

