// Copyright (c) 2017, Alexei Eleusis Díaz Vera. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// TODO: Put public facing types in this file.

void substituteRecursive() {
  var n = 0;

  while (n > 0) {
    do {
      if (1 > 0) {
        n--;
      } else {
        break;
      }
    } while (n > 0);
  }
}

/// Checks if you are awesome. Spoiler: you are.
class Awesome {
  /// Flag indicating if you are awesome!
  bool get isAwesome => true;
}

abstract class Base {
  int get foo;
}

class Derived extends Base {
  String whyNull = null;

  int get foo => 0;
}
