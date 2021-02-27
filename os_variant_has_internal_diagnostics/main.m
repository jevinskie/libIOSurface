//
//  main.m
//  os_variant_has_internal_diagnostics
//
//  Created by Jevin Sweval on 2/27/21.
//

#import <Foundation/Foundation.h>

extern int os_variant_has_internal_diagnostics(const char *cat);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSString *cat = @(argv[1]);
        NSLog(@"os_variant_has_internal_diagnostics(%@) = %d", cat, os_variant_has_internal_diagnostics(argv[1]));

    }
    return 0;
}
