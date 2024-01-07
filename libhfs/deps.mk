block.o: block.c config.h libhfs.h hfs.h apple.h volume.h block.h os.h
btree.o: btree.c libhfs.h hfs.h apple.h btree.h data.h file.h block.h \
  node.h
data.o: data.c data.h
file.o: file.c libhfs.h hfs.h apple.h file.h btree.h record.h volume.h
hfs.o: hfs.c libhfs.h hfs.h apple.h data.h block.h medium.h file.h \
  btree.h node.h record.h volume.h
low.o: low.c libhfs.h hfs.h apple.h low.h data.h block.h file.h
medium.o: medium.c libhfs.h hfs.h apple.h block.h low.h medium.h
memcmp.o: memcmp.c
node.o: node.c libhfs.h hfs.h apple.h node.h data.h btree.h
os.o: os.c libhfs.h hfs.h apple.h os.h
record.o: record.c libhfs.h hfs.h apple.h record.h data.h
version.o: version.c version.h
volume.o: volume.c config.h libhfs.h hfs.h apple.h volume.h data.h \
  block.h low.h medium.h file.h btree.h record.h os.h
