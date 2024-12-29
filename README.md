this is a simple bootloader written in x86 assembly.

The bootloader initializes in real mode and sets up the stack, then it reads
the fat12 root directory from the disk to locate the kernel file(kernel.bin).
using bios interrupt, the bootloader reads the kernel file from the disk and
loads it into memory. control is transferred to the kernel by jumping to the kernel
file which start execution from its entry point
(by getting the message: "our os has booted" you know the bootloader successfully located
the kernel file and was able to jump to it and execute it.)

in the Makefile, we are using mkfs.fat to create a disk image and format it
in a fat12 file system. then the boot sector is copied into the first sector of the disk 
and the kernel.bin file is in the root directory. 


to run the bootloader:
make all
or
./setup.sh

for documentation of fat12 file system: https://www.eit.lth.se/fileadmin/eit/courses/eitn50/Literature/fat12_description.pdf

