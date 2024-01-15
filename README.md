# hfs: copy files to and from HFS volumes on OS X

This program copies files between HFS and HFS+/APFS filesystems on OS X,
including resource forks. It is particularly helpful for transferring files to
an old Macintosh when the necessary unarchivers/decoders for formats like
Stuffit, MacBinary, Disk Copy 4.2, etc are not present on the target machine.
It can also convert text files in both directions.

The heavy lifting is done by Robert Leslie's libhfs, which is included in the
`libhfs` directory.

## Why use this instead of hfsutils?

hfsutils can't read and write actual resource forks on the non-HFS side, even
when the filesystem supports them. The best it can do is MacBinary and BinHex
encoding.

The hfsutils CLI is a bit idiosyncratic. I think its design makes more sense
for doing ongoing work with a set of multiple HFS volumes than for the quick
one-off transfer tasks I need to do.

## Why use hfsutils instead of this?

hfsutils provides a much more complete set of file operations. Also, because
it has BinHex and MacBinary support, it can transfer any file to or from any
filesystem.

## Building

You'll need Xcode. Version 14.2 on Monterey is known to work.

First, cd to `libhfs` and run `make`. Then open `hfs.xcodeproj` in Xcode and
build it (cmd-b or Product-&gt;Build). To find the resulting `hfs` binary,
select Product-&gt;Show Build Folder in Finder.

## Usage

To list files: `hfs [hfs-path]`.

To copy a file out of the HFS volume: `hfs get hfs-path local-path [--text]`

To copy a file into the HFS volume: `put local-path hfs-path type creator [--text | --type type:creator]`

HFS paths use a colon (:) as the directory separator and are considered to be
absolute regardless of whether or not they have a leading colon. The volume
name should not be included in the path.

If the `--text` flag is used, the `get` and `put` commands will convert the
contents of the data fork between Unicode and Mac OS Roman and between Unix
and Macintosh line endings.

## Support, or lack thereof

This software is a
[home-cooked meal](https://www.robinsloan.com/notes/home-cooked-app/).
I made it for me. If you find it useful, that's a happy side effect. I'm making
it available with **absolutely no warranty whatsoever** and no promise of
support, bug fixes, or future development of any kind. Use it at your own
risk. You should make sure you have a backup copy of any volume you use this
software on.

## Planned improvements

* Replace the CLI with a GUI

## Known limitations

* File paths and text file contents on HFS volumes are assumed to be in the
  Mac OS Roman encoding. Other encodings are not supported.
* File paths and text file contents on the local (non-HFS) side are assumed to
  be in UTF-8. Other encodings are not supported.
* File paths containing the null character are not supported.
* OSes other than OS X are not supported. Windows users can use CiderPress.
  Users of Linux/BSD/other Unix systems can use hfsutils.
