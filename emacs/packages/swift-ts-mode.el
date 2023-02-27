;;; swift-ts-mode.el --- tree-sitter support for Swift  -*- lexical-binding: t; -*-

;; Stater guide: https://archive.casouri.cc/note/2023/tree-sitter-starter-guide/index.html
;; tree-sitter-swift: https://github.com/alex-pinkus/tree-sitter-swift
;;
;; Todos:
;; - [ ] font-lock (syntax highlight)
;; - [x] indentation
;; - [x] Imenu
;; - [x] defun navigation

(require 'treesit)
(require 'c-ts-common) ; For comment indent and filling.

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-end "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-parent "treesit.c")
(declare-function treesit-query-compile "treesit.c")

(defcustom swift-ts-mode-indent-offset 4
  "Number of spaces for each indentation step in `swift-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'swift)

(defvar swift-ts-mode--indent-rules
  `((swift
     ((parent-is "source_file") point-min 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is ">") parent-bol 0)
     ((node-is "}") (and parent parent-bol) 0)
     ((and (parent-is "comment") c-ts-common-looking-at-star)
      c-ts-common-comment-start-after-first-star -1)
     ((parent-is "comment") prev-adaptive-prefix 0)
     ((parent-is "statements") parent-bol 0)
     ((parent-is "switch_statement") parent-bol 0)
     ((parent-is "guard_statement") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "protocol_body") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "switch_entry") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "lambda_literal") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "catch_block") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "do_statement") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "if_statement") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "for_statement") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "while_statement") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "tuple_type") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "function_body") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "function_declaration") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "lambda_function_type_parameters") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "tuple_expression") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "class_body") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_setter") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "enum_type_parameters") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "type_parameters") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "value_arguments") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "array_literal") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "dictionary_literal") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_getter") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_property") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "property_declaration") parent-bol 0)
     ((parent-is "modifiers") parent-bol 0)
     ((parent-is "navigation_expression") parent-bol swift-ts-mode-indent-offset)))
  "Tree-sitter indent rules for `swift-ts-mode'.")

;; TODO: Figure out what a syntax table does and how it should be for Swift.
(defvar swift-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?+   "."      table)
    (modify-syntax-entry ?-   "."      table)
    (modify-syntax-entry ?=   "."      table)
    (modify-syntax-entry ?%   "."      table)
    (modify-syntax-entry ?&   "."      table)
    (modify-syntax-entry ?|   "."      table)
    (modify-syntax-entry ?^   "."      table)
    (modify-syntax-entry ?!   "."      table)
    (modify-syntax-entry ?@   "."      table)
    (modify-syntax-entry ?~   "."      table)
    (modify-syntax-entry ?<   "."      table)
    (modify-syntax-entry ?>   "."      table)
    (modify-syntax-entry ?/   ". 124b" table)
    (modify-syntax-entry ?*   ". 23"   table)
    (modify-syntax-entry ?\n  "> b"    table)
    (modify-syntax-entry ?\^m "> b"    table)
    table)
  "Syntax table for `swift-ts-mode'.")

;; Replace with 'conditional? https://github.com/alex-pinkus/tree-sitter-swift/blob/main/queries/highlights.scm#L85
(defvar swift-ts-mode--keywords
  '("typealias" "struct" "class" "actor" "enum" "protocol" "extension"
    "indirect" "nonisolated" "override" "convenience" "required" "some"
    "func" "import" "let" "var" "guard" "if" "switch" "case" "do"
    "fallthrough" "return" "async" "await" "try" "try?" "try!" "nil"
    (throw_keyword) (catch_keyword) (else) (default_keyword) (throws) (where_keyword)
    (visibility_modifier) (member_modifier) (function_modifier)
    (property_modifier) (parameter_modifier) (inheritance_modifier)
    (getter_specifier) (setter_specifier) (modify_specifier))
  "Swift keywords for tree-sitter font-locking.") 

;; TODO: Why is break not a keyword? And do we need a separate feature for loops?
(defvar swift-ts-mode--loops
  '("while" "repeat" "continue" "break")
  "Swift loops for tree-sitter font-locking.")

(defvar swift-ts-mode--brackets
  '("(" ")" "[" "]" "{" "}")
  "Swift brackets for tree-sitter font-locking.")

(defvar swift-ts-mode--operators
  '("!" "+" "-" "*" "/" "%" "=" "+=" "-=" "*=" "/="
    "<" ">" "<=" ">=" "++" "--" "&" "~" "%=" "!=" "!==" "==" "===" "??"
    "->" "..<" "...")
  "Swift operators for tree-sitter font-locking.")

(defvar swift-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'swift
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'swift
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)

   :language 'swift
   :feature 'delimiter
   '((["." ";" ":" ","]) @font-lock-delimiter-face)

   :language 'swift
   :feature 'definition
   '(
     (function_declaration (simple_identifier) @font-lock-function-name-face)
     (call_expression (simple_identifier) @font-lock-type-face)
     (parameter external_name: (simple_identifier) @font-lock-bracket-face)
     (parameter name: (simple_identifier) @font-lock-bracket-face)
     (type_parameter (type_identifier) @font-lock-bracket-face)
     (inheritance_constraint (identifier (simple_identifier)) @font-lock-bracket-face)
     (equality_constraint (identifier (simple_identifier)) @font-lock-bracket-face)

     ;; TODO: Decide on face
     (prefix_expression (simple_identifier) @font-lock-function-call-face)
     (call_expression (simple_identifier) @font-lock-function-call-face)
     
     ;; TODO: Find correct faces
     (navigation_suffix suffix: (simple_identifier) @font-lock-function-call-face)
     ;; TODO: Highlight Types
     ;;(navigation_expression
     ;; (simple_identifier) @type) ; SomeType.method(): highlight SomeType as a type
     ;; (#match? @type "^[A-Z]")
     ;; (call_expression (navigation_expression (navigation_suffix (simple_identifier))) @font-lock-function-call-face)

     ;; TODO: Find better face (@font-lock-type-face is maybe more
     ;; correct but doesn't give enough contrast with the types).
     (value_argument name: (simple_identifier) @font-lock-property-name-face)

     ;; TODO: Move into property feature?
     (enum_entry (simple_identifier) @font-lock-property-name-face)
     (property_declaration (pattern (simple_identifier)) @font-lock-property-name-face)
     ((attribute) @font-lock-type-face)

     ((self_expression) @font-lock-keyword-face)

     ;; TODO: Move into different feature?
     ((directive) @font-lock-preprocessor-face)
     
     (function_declaration "init" @font-lock-keyword-face)
     (class_declaration (type_identifier) @font-lock-type-face)
     (inheritance_specifier (user_type (type_identifier)) @font-lock-type-face)
     )

   :language 'swift
   :feature 'string
   '([
      "\"" "\"\"\""
      (line_str_text)
      (str_escaped_char)
      (multi_line_str_text)
      (raw_str_part)
      (raw_str_end_part)
      (raw_str_interpolation_start)] @font-lock-string-face)
   
   :language 'swift
   :feature 'type
   `((type_identifier) @font-lock-type-face)

   :language 'swift
   :feature 'variable
   `(((simple_identifier) @font-lock-variable-name-face)
     (lambda_parameter (simple_identifier) @font-lock-variable-name-face))

   ;; Must before bracket so private(set) etc. is marked as keywords.
   :language 'swift
   :feature 'keyword
   `([,@swift-ts-mode--keywords] @font-lock-keyword-face
     (lambda_literal "in" @font-lock-operator-face))

   :language 'swift
   :feature 'bracket
   `([,@swift-ts-mode--brackets] @font-lock-bracket-face)

   :language 'swift
   :feature 'operator
   `(
     [,@swift-ts-mode--operators] @font-lock-operator-face
     (ternary_expression "?" @font-lock-operator-face)
     (ternary_expression ":" @font-lock-operator-face))

   :language 'swift
   :feature 'loops
   `([,@swift-ts-mode--loops] @font-lock-keyword-face
     (for_statement "for" @font-lock-keyword-face)
     (for_statement "in" @font-lock-keyword-face))

   :language 'swift
   :feature 'constant
   `((boolean_literal) @font-lock-constant-face
      ;; (:match "^[A-Z][A-Z\\d_]*$" @font-lock-constant-face)
      )

   ;; TODO: Add regex literals
   ;; (regex_literal) @string.regex

   :language 'swift
   :feature 'number
   '([(integer_literal) (real_literal) (hex_literal) (oct_literal) (bin_literal)] @font-lock-number-face))
  "Tree-sitter font-lock settings for `swift-ts-mode'.")

(defun swift-ts-mode--protocol-node-p (node)
  "Return t if NODE is a protocol."
  (and 
   (string-equal "protocol_declaration" (treesit-node-type node))
   (string-equal "protocol"
                 (treesit-node-text
                  (treesit-node-child-by-field-name node "declaration_kind") t))))

(defun swift-ts-mode--class-declaration-node-p (name node)
  "Return t if NODE is matches the given NAME."
  (and 
   (string-equal "class_declaration" (treesit-node-type node))
   (string-equal name
                 (treesit-node-text
                  (treesit-node-child-by-field-name node "declaration_kind") t))))

(defun swift-ts-mode--enum-node-p (node)
  "Return t if NODE is an enum."
  (swift-ts-mode--class-declaration-node-p "enum" node))

(defun swift-ts-mode--class-node-p (node)
  "Return t if NODE is a class."
  (swift-ts-mode--class-declaration-node-p "class" node))

(defun swift-ts-mode--actor-node-p (node)
  "Return t if NODE is an actor."
  (swift-ts-mode--class-declaration-node-p "actor" node))

(defun swift-ts-mode--struct-node-p (node)
  "Return t if NODE is a struct."
  (swift-ts-mode--class-declaration-node-p "struct" node))

(defun swift-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("class_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("function_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("protocol_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ))

;;;###autoload
(define-derived-mode swift-ts-mode prog-mode "Swift"
  "Major mode for editing Swift, powered by tree-sitter."
  :group 'swift
  :syntax-table swift-ts-mode--syntax-table

  (when (treesit-ready-p 'swift)
    (treesit-parser-create 'swift)
    
    ;; Comments
    (c-ts-common-comment-setup)

    ;; Font-lock
    (setq-local treesit-font-lock-settings swift-ts-mode--font-lock-settings)
    ;; TODO: Split features into different levels
    (setq-local treesit-font-lock-feature-list
                '((number type variable definition string comment keyword operator loops bracket error delimiter constant)))

    ;; Navigation.
    (setq-local treesit-defun-type-regexp
                (regexp-opt '("class_declaration"
                              "function_declaration"
                              "protocol_declaration")))
    (setq-local treesit-defun-name-function #'swift-ts-mode--defun-name)

    ;; Imenu.
    (setq-local treesit-simple-imenu-settings
                `(("Enum" "\\class_declaration\\'" swift-ts-mode--enum-node-p nil)
                  ("Class" "\\class_declaration\\'" swift-ts-mode--class-node-p nil)
                  ("Struct" "\\class_declaration\\'" swift-ts-mode--struct-node-p nil)
                  ("Protocol" "\\protocol_declaration\\'" swift-ts-mode--protocol-node-p nil)
                  ("Func" "\\function_declaration\\'" nil nil)
                  ("Actor" "\\class_declaration\\'" swift-ts-mode--actor-node-p nil)))

    ;; Indentation
    (setq-local indent-tabs-mode nil
                treesit-simple-indent-rules swift-ts-mode--indent-rules)

    (treesit-major-mode-setup)))

(if (treesit-ready-p 'swift)
    (add-to-list 'auto-mode-alist '("\\.swift\\'" . swift-ts-mode)))

(provide 'swift-ts-mode)

;;; swift-ts-mode.el ends here
