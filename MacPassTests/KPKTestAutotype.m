//
//  KPKTestAutotypeNormalization.m
//  MacPass
//
//  Created by Michael Starke on 18.02.14.
//  Copyright (c) 2014 HicknHack Software GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Carbon/Carbon.h>

#import "NSString+Commands.h"
#import "MPAutotypeCommand.h"
#import "MPAutotypeContext.h"
#import "MPAutotypePaste.h"
#import "MPAutotypeKeyPress.h"

#import "MPKeyMapper.h"

#import "KPKEntry.h"
#import "KPKAttribute.h"
#import "KPKAutotype.h"
#import "KPKWindowAssociation.h"

@interface KPKTestAutotype : XCTestCase

@end

@implementation KPKTestAutotype

- (void)testSimpleNormalization {
  NSString *normalized = [@"Whoo %{%}{^}{SHIFT}+ {SPACE}{ENTER}^V%V~T" normalizedAutotypeSequence];
  XCTAssertTrue([normalized isEqualToString:@"Whoo{SPACE}{ALT}{%}{^}{SHIFT}{SHIFT}{SPACE}{SPACE}{ENTER}{CONTROL}V{ALT}V{ENTER}T"]);
}

- (void)testCommandRepetition {
  NSString *normalized = [@"Whoo %{% 2}{^}{SHIFT 5}+ {SPACE}{ENTER}^V%V~T" normalizedAutotypeSequence];
  XCTAssertTrue([normalized isEqualToString:@"Whoo{SPACE}{ALT}{%}{%}{^}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SPACE}{SPACE}{ENTER}{CONTROL}V{ALT}V{ENTER}T"]);
  normalized = [@"{TAB 5}TAB{TAB}{SHIFT}{SHIFT 10}ENTER{ENTER}{%%}" normalizedAutotypeSequence];
  XCTAssertTrue([normalized isEqualToString:@"{TAB}{TAB}{TAB}{TAB}{TAB}TAB{TAB}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}{SHIFT}ENTER{ENTER}{%%}"]);
}

- (void)testeBracketValidation {
  XCTAssertFalse([@"{BOOO}NO-COMMAND{TAB}{WHOO}{WHOO}{SPACE}!!!thisIsFun{{MISMATCH!!!}" validateCommmand]);
  XCTAssertFalse([@"{{}}}}" validateCommmand]);
  XCTAssertFalse([@"{}{}{{{}{{{{{{}}" validateCommmand]);
  XCTAssertTrue([@"{}{}{}{}{}{      }ThisIsValid{}{STOP}" validateCommmand]);
}

- (void)testCaseInsenstivieKeyPress {
  KPKEntry *entry = [[KPKEntry alloc] init];
  entry.title = @"Title";
  entry.url = @"www.myurl.com";
  entry.username = @"Username";
  entry.password = @"Password";
  
  /* Command 1 */
  MPAutotypeContext *context = [[MPAutotypeContext alloc] initWithEntry:entry andSequence:@"{TAB}{ENTER}~{tAb}{ShIfT}{enter}"];
  NSArray *commands = [MPAutotypeCommand commandsForContext:context];
  
  XCTAssertTrue(commands.count == 5);
  /* {TAB} */
  MPAutotypeKeyPress *keyPress = commands[0];
  XCTAssertEqual(keyPress.keyCode, kVK_Tab);
  XCTAssertEqual(keyPress.modifierMask, 0);
  
  /* {ENTER} */
  keyPress = commands[1];
  XCTAssertEqual(keyPress.keyCode, kVK_Return);
  XCTAssertEqual(keyPress.modifierMask, 0);

  /* ~ -> Enter */
  keyPress = commands[2];
  XCTAssertEqual(keyPress.keyCode, kVK_Return);
  XCTAssertEqual(keyPress.modifierMask, 0);
  
  /* {tAb} */
  keyPress = commands[3];
  XCTAssertEqual(keyPress.keyCode, kVK_Tab);
  XCTAssertEqual(keyPress.modifierMask, 0);
  
  /* {ShIfT}{enter}*/
  keyPress = commands[4];
  XCTAssertEqual(keyPress.keyCode, kVK_Return);
  XCTAssertEqual(keyPress.modifierMask, kCGEventFlagMaskShift);
}

- (void)testCaseSensitiveCustomAttributeLookup {
  KPKEntry *entry = [[KPKEntry alloc] init];
  entry.title = @"Title";
  entry.url = @"www.myurl.com";
  entry.username = @"Username";
  entry.password = @"Password";
  
  KPKAttribute *lowerCaseAttribute = [[KPKAttribute alloc] initWithKey:@"custom" value:@"value"];
  KPKAttribute *upperCaseAttribute = [[KPKAttribute alloc] initWithKey:@"CUSTOM" value:@"VALUE"];
  KPKAttribute *mixedCaseAttribute = [[KPKAttribute alloc] initWithKey:@"CuStOm" value:@"VaLuE"];
  KPKAttribute *randomCase = [[KPKAttribute alloc] initWithKey:@"custoM" value:@"valuE"];
  [entry addCustomAttribute:lowerCaseAttribute];
  [entry addCustomAttribute:upperCaseAttribute];
  [entry addCustomAttribute:mixedCaseAttribute];
  [entry addCustomAttribute:randomCase];
  
  entry.autotype.defaultKeystrokeSequence = [[NSString alloc] initWithFormat:@"{USERNAME}{s:%@}{S:%@}{s:%@}", lowerCaseAttribute.key, mixedCaseAttribute.key, upperCaseAttribute.key];
  
  MPAutotypeContext *context = [[MPAutotypeContext alloc] initWithDefaultSequenceForEntry:entry];
  NSString *result = [[NSString alloc] initWithFormat:@"%@%@%@%@", entry.username, lowerCaseAttribute.value, mixedCaseAttribute.value, upperCaseAttribute.value];
  XCTAssertTrue([[context evaluatedCommand] isEqualToString:result]);
}

- (void)testCommandCreation {
  KPKEntry *entry = [[KPKEntry alloc] init];
  entry.title = @"Title";
  entry.url = @"www.myurl.com";
  entry.username = @"{{User{name}}}";
  entry.password = @"Pass{word}";
  
  /* Command 1 */
  MPAutotypeContext *context = [[MPAutotypeContext alloc] initWithEntry:entry andSequence:@"{USERNAME}{TAB}{PASSWORD}{ENTER}"];
  NSArray *commands = [MPAutotypeCommand commandsForContext:context];
  
  XCTAssertTrue(commands.count == 4);
  XCTAssertTrue([commands[0] isKindOfClass:[MPAutotypePaste class]]);
  XCTAssertTrue([commands[1] isKindOfClass:[MPAutotypeKeyPress class]]);
  XCTAssertTrue([commands[2] isKindOfClass:[MPAutotypePaste class]]);
  XCTAssertTrue([commands[3] isKindOfClass:[MPAutotypeKeyPress class]]);
  
  /* {USERNAME} */
  MPAutotypePaste *paste = commands[0];
  XCTAssertTrue([paste.pasteData isEqualToString:entry.username]);
  
  /* {TAB} */
  MPAutotypeKeyPress *keyPress = commands[1];
  XCTAssertEqual(keyPress.keyCode, kVK_Tab); // Tab is a fixed key, no mapping needed
  XCTAssertEqual(keyPress.modifierMask, 0);
  
  /* {PASSWORD} */
  paste = commands[2];
  XCTAssertTrue([entry.password isEqualToString:paste.pasteData]);
  
  /* {ENTER} */
  keyPress = commands[3];
  XCTAssertEqual(keyPress.keyCode, kVK_Return);
  
  /* Command 2 */
  context = [[MPAutotypeContext alloc] initWithEntry:entry andSequence:@"^T{USERNAME}%+^{TAB}Whoo{PASSWORD}{ENTER}"];
  commands = [MPAutotypeCommand commandsForContext:context];
  XCTAssertTrue(commands.count == 5);
  XCTAssertTrue([commands[0] isKindOfClass:[MPAutotypeKeyPress class]]);
  XCTAssertTrue([commands[1] isKindOfClass:[MPAutotypePaste class]]);
  XCTAssertTrue([commands[2] isKindOfClass:[MPAutotypeKeyPress class]]);
  XCTAssertTrue([commands[3] isKindOfClass:[MPAutotypePaste class]]);
  XCTAssertTrue([commands[4] isKindOfClass:[MPAutotypeKeyPress class]]);
  
  /* ^T */
  keyPress = commands[0];
  /* Lower case is ok, since we only need the key, not the sequence to reproduce the string */
  XCTAssertTrue([@"t" isEqualToString:[MPKeyMapper stringForKey:keyPress.keyCode]]);
  XCTAssertEqual(keyPress.modifierMask, kCGEventFlagMaskCommand);
  
  /* {USERNAME} */
  paste = commands[1];
  XCTAssertTrue([paste.pasteData isEqualToString:entry.username]);
  
  /* %+^{TAB} */
  keyPress = commands[2];
  XCTAssertEqual(keyPress.keyCode, kVK_Tab); // Tab is a fixed key, no mapping needed
  XCTAssertEqual(keyPress.modifierMask, (kCGEventFlagMaskCommand | kCGEventFlagMaskShift | kCGEventFlagMaskAlternate));
  
  /* Whoo{PASSWORD} */
  paste = commands[3];
  NSString *pasteString = [[NSString alloc] initWithFormat:@"%@%@", @"Whoo", entry.password];
  XCTAssertTrue([pasteString isEqualToString:paste.pasteData]);
  
  /* {ENTER} */
  keyPress = commands[4];
  XCTAssertEqual(keyPress.keyCode, kVK_Return);
  XCTAssertEqual(keyPress.modifierMask, 0);
}
@end