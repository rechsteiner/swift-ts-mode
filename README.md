# swift-ts-mode

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A tree-sitter based major-mode for [Swift](https://swift.org), with support for font-locking, imenu and indentation. 
Compatible with the following [tree-sitter-swift](https://github.com/alex-pinkus/tree-sitter-swift) grammar.

![Screenshot of swift-ts-mode in Emacs](https://github.com/rechsteiner/swift-ts-mode/assets/1238984/9cadacb8-3708-4d69-9035-5ae967689219)

## Installing

This package is available on [Melpa](https://melpa.org):

```
(use-package swift-ts-mode
    :ensure t)
```

For manual installation:

```
(load "path/to/swift-ts-mode.el")
```

## Requirements

- Emacs 29.1 or above with tree-sitter support (see [tree-sitter starter guide](https://git.savannah.gnu.org/cgit/emacs.git/tree/admin/notes/tree-sitter/starter-guide?h=emacs-29))
- Tree-sitter grammar: [github.com/alex-pinkus/tree-sitter-swift](https://github.com/alex-pinkus/tree-sitter-swift)
