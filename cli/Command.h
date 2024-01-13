#import <Foundation/Foundation.h>
#import "../libhfs/hfs.h"

NS_ASSUME_NONNULL_BEGIN

@protocol Command <NSObject>

- (NSString *)name;
- (NSString *)usage;
- (int)mountMode;
- (BOOL)executeOnVolume:(hfsvol *)vol withArgs:(NSArray<NSString *> *)args;

@end

NS_ASSUME_NONNULL_END
