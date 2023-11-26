# swift-ts-mode

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A tree-sitter based major-mode for the [Swift](https://swift.org) programming language.

Built using the following tree-sitter grammar: [github.com/alex-pinkus/tree-sitter-swift](https://github.com/alex-pinkus/tree-sitter-swift)

## Installing

This package is available on [Melpa](https://melpa.org) and can be installed like this:

```
(use-package swift-ts-mode
    :ensure t)
```

Or using the package manager of your choice. Alternatively, just copy the `swift-ts-mode.el` file directly into your config.

You also need to install the [tree-sitter-swift](https://github.com/alex-pinkus/tree-sitter-swift) language grammar.
