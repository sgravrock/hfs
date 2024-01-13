#import "errors.h"
#import "../libhfs/hfs.h"

void hfs_perror(const char *prefix) {
    if (hfs_error) {
        fprintf(stderr, "%s: %s\n", prefix, hfs_error);
    } else {
        perror(prefix);
    }
}
