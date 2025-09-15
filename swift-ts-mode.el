;;; swift-ts-mode.el --- Major mode for Swift based on tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Martin Rechsteiner

;; Author           : Martin Rechsteiner
;; Version          : 0.1
;; Created          : February 2023
;; Homepage         : https://github.com/rechsteiner/swift-ts-mode
;; Keywords         : swift languages tree-sitter
;; Package-Requires : ((emacs "29.1"))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package defines swift-ts-mode which is a major mode for Swift.

;;; Code:

(require 'treesit)
(require 'c-ts-common)

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

(defun swift-ts-mode--treesit-last-child (node)
  "Gets the last child of the given treesit NODE."
  (if (treesit-node-children node)
      (treesit-node-child node (- (treesit-node-child-count node) 1))
    node))

(defun swift-ts-mode--value-arguments-indent (node parent bol &rest _)
  "Return indentation for the given value argument NODE."
  (if (treesit-node-prev-sibling node t)
      (treesit-node-start (treesit-node-prev-sibling node t))
    (save-excursion
      (goto-char (treesit-node-start parent))
      (back-to-indentation)
      (+ (point) swift-ts-mode-indent-offset))))

(defun swift-ts-mode--navigation-expression-indent (node parent &rest _)
  "Handles indentation for the given navigation expression NODE."
  (let* ((prev-node
          (swift-ts-mode--treesit-last-child
           (treesit-node-child-by-field-name parent "target")))
         
         (min-point
          (save-excursion
            (goto-char (treesit-node-start prev-node))
            (back-to-indentation)
            (point)))
         
         (max-point
          (save-excursion
            (goto-char (treesit-node-end prev-node))
            (back-to-indentation)
            (point))))

    (cond
     ;; If the previous line starts with a dot, use the same
     ;; indentation as that line.
     ((equal "." (treesit-node-text (treesit-node-at min-point))) min-point)
     
     ;; If the previous node does not start with a dot, we
     ;; compare the start and end point of that node to see if
     ;; the "value_arguments" or "lambda_literals" wrap on
     ;; multiple lines or not. This ensures that we only indent
     ;; the current node for code like this:
     ;;
     ;; SomeView()
     ;;     .padding()
     ;;
     ;; ContentView {}
     ;;     .padding()
     ((eq min-point max-point) (+ min-point swift-ts-mode-indent-offset))
     
     ;; Default to using the same indentation as the previous
     ;; node. This ensures that we don't indent the current node
     ;; when wrapping literals on it's own line like this:
     ;;
     ;; ContentView {
     ;; 
     ;; }
     ;; .padding()
     (t min-point))))

(defun swift-ts-mode--default-indent (_n parent bol &rest _)
  (if parent
      (save-excursion
        (goto-char (treesit-node-start parent))
        (back-to-indentation)
        (point))
    (save-excursion
      (goto-char bol)
      (line-beginning-position))))

(defvar swift-ts-mode--indent-rules
  `((swift
     ((parent-is "source_file") column-0 0)
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
     ((parent-is "lambda_function_type_parameters") parent-bol 0)
     ((parent-is "lambda_function_type") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "tuple_expression") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "class_body") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_setter") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "enum_type_parameters") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "type_parameters") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "value_arguments") swift-ts-mode--value-arguments-indent 0)
     ((parent-is "array_literal") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "dictionary_literal") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_getter") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "computed_property") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "willset_didset_block") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "didset_clause") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "willset_clause") parent-bol swift-ts-mode-indent-offset)
     ((parent-is "property_declaration") parent-bol 0)
     ((parent-is "modifiers") parent-bol 0)
     (no-node swift-ts-mode--default-indent 0)
     ((parent-is "navigation_expression") swift-ts-mode--navigation-expression-indent 0)))
  "Tree-sitter indent rules for `swift-ts-mode'.")

(defvar swift-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_   "_"      table)
    (modify-syntax-entry ?$   "_"      table)
    (modify-syntax-entry ?@   "_"      table)
    (modify-syntax-entry ?#   "_"      table)
    (modify-syntax-entry ?+   "."      table)
    (modify-syntax-entry ?-   "."      table)
    (modify-syntax-entry ?=   "."      table)
    (modify-syntax-entry ?%   "."      table)
    (modify-syntax-entry ?&   "."      table)
    (modify-syntax-entry ?|   "."      table)
    (modify-syntax-entry ?^   "."      table)
    (modify-syntax-entry ?!   "."      table)
    (modify-syntax-entry ?~   "."      table)
    (modify-syntax-entry ?<   "."      table)
    (modify-syntax-entry ?>   "."      table)
    (modify-syntax-entry ?/   ". 124b" table)
    (modify-syntax-entry ?*   ". 23"   table)
    (modify-syntax-entry ?\n  "> b"    table)
    (modify-syntax-entry ?\^m "> b"    table)
    table)
  "Syntax table for `swift-ts-mode'.")

;; TODO: Handle try separately from try! and try?
(defvar swift-ts-mode--keywords
  '("typealias" "struct" "class" "actor" "enum" "protocol" "extension"
    "indirect" "nonisolated" "override" "convenience" "required" "some"
    "func" "import" "let" "var" "guard" "if" "switch" "case" "do"
    "fallthrough" "return" "async" "await" "try" "nil" "unowned"
    "while" "repeat" "continue" "break" "lazy" "weak" "didSet" "willSet" "init"
    "deinit" "as" "as?" "as!" "any" "mutating" "nonmutating"
    (throw_keyword) (catch_keyword) (else) (default_keyword) (throws) (where_keyword)
    (visibility_modifier) (member_modifier) (function_modifier) (property_modifier)
    (parameter_modifier) (inheritance_modifier) (getter_specifier) (setter_specifier)
    (modify_specifier))
  "Swift keywords for tree-sitter font-locking.")

(defvar swift-ts-mode--brackets
  '("(" ")" "[" "]" "{" "}")
  "Swift brackets for tree-sitter font-locking.")

(defvar swift-ts-mode--operators
  '("+" "-" "*" "/" "%" "=" "+=" "-=" "*=" "/="
    "<" ">" "<=" ">=" "++" "--" "&" "~" "%=" "!=" "!==" "==" "===" "??"
    "->" "..<" "..." (bang))
  "Swift operators for tree-sitter font-locking.")

(defvar swift-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'swift
   :feature 'property
   '(
     (attribute
      ["@" @font-lock-type-face
       (user_type (type_identifier) @font-lock-type-face)])

     ;; TODO: Match on any level of switch patterns
     (switch_pattern (pattern (simple_identifier) @font-lock-property-use-face))
     (switch_pattern (pattern (pattern (simple_identifier) @font-lock-property-use-face)))
     (switch_pattern (pattern (pattern (pattern (simple_identifier) @font-lock-property-use-face))))
     (switch_pattern (pattern (pattern (pattern (pattern (simple_identifier) @font-lock-property-use-face)))))
     (switch_pattern (pattern (pattern (pattern (pattern (pattern (simple_identifier) @font-lock-property-use-face))))))
     (switch_pattern (pattern (pattern (pattern (pattern (pattern (pattern (simple_identifier) @font-lock-property-use-face)))))))
     
     (class_body
      (property_declaration (pattern (simple_identifier)) @font-lock-property-name-face))
     
     (enum_entry (simple_identifier) @font-lock-property-name-face))
   
   :language 'swift
   :feature 'comment
   '(((comment) @font-lock-comment-face)
     ((multiline_comment) @font-lock-comment-face))

   :language 'swift
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)

   :language 'swift
   :feature 'string
   '([
      "\"" "\"\"\""
      (line_str_text)
      (str_escaped_char)
      (multi_line_str_text)
      (raw_str_part)
      (raw_str_end_part)
      (raw_str_interpolation_start)
      (regex_literal)] @font-lock-string-face)

   :language 'swift
   :feature 'definition
   '(
     (function_declaration (simple_identifier) @font-lock-function-name-face)
     ;; TODO: Use custom font face with fallback on default for parameters.
         (value_argument_label (simple_identifier) @font-lock-property-use-face)
     (parameter external_name: (simple_identifier) @font-lock-variable-name-face)
     (parameter name: (simple_identifier) @font-lock-variable-name-face)
     (tuple_type_item name: (simple_identifier) @font-lock-variable-name-face)
     (type_parameter (type_identifier) @font-lock-variable-name-face)
     (inheritance_constraint (identifier (simple_identifier)) @font-lock-variable-name-face)
     (equality_constraint (identifier (simple_identifier)) @font-lock-variable-name-face)
         (lambda_parameter (simple_identifier) @font-lock-variable-name-face)
         (protocol_function_declaration name: (simple_identifier) @font-lock-function-name-face))

   :language 'swift
   :feature 'function
   '((call_expression
      (navigation_expression
       suffix: (navigation_suffix suffix: (simple_identifier) @font-lock-function-call-face)))

     ((directive) @font-lock-preprocessor-face)
         ;; distinguish from dictionary-access which has exact same syntax-tree
         ;; except [ braces ] inside value_arguments.
         (call_expression
          (simple_identifier) @font-lock-function-call-face
          (call_suffix
           (value_arguments
            ["("] @open-paren
            (_) *
            [")"])))
         (macro_invocation (simple_identifier) @font-lock-preprocessor-face))

   :language 'swift
   :feature 'type
   `(((type_identifier) @font-lock-type-face)
     (class_declaration (type_identifier) @font-lock-type-face)
     (inheritance_specifier (user_type (type_identifier)) @font-lock-type-face)
     ((navigation_expression (simple_identifier) @font-lock-type-face)
      (:match "^[A-Z]" @font-lock-type-face)))

   :language 'swift
   :feature 'keyword
   `([,@swift-ts-mode--keywords] @font-lock-keyword-face
     (try_operator "!" @font-lock-keyword-face)
     (try_operator "?" @font-lock-keyword-face)
     (super_expression "super" @font-lock-keyword-face)
     (availability_condition "#" @font-lock-keyword-face)
     (availability_condition "available" @font-lock-keyword-face)
     (availability_condition "unavailable" @font-lock-keyword-face)
     (selector_expression "selector" @font-lock-keyword-face)
     (selector_expression "#" @font-lock-keyword-face)
     (playground_literal "colorLiteral" @font-lock-keyword-face)
     (playground_literal "fileLiteral" @font-lock-keyword-face)
     (playground_literal "imageLiteral" @font-lock-keyword-face)
     (playground_literal "#" @font-lock-keyword-face)
     (key_path_string_expression "#" @font-lock-keyword-face)
     (key_path_string_expression "keyPath" @font-lock-keyword-face)
     (macro_invocation "#" @font-lock-preprocessor-facee)
     (macro_invocation (simple_identifier) @font-lock-preprocessor-face)
     (lambda_literal "in" @font-lock-keyword-face)
     (for_statement "in" @font-lock-keyword-face)
     (for_statement "for" @font-lock-keyword-face)
     ((self_expression) @font-lock-keyword-face)
     ((simple_identifier) @font-lock-keyword-face
      (:match "^\\(:?self\\)$" @font-lock-keyword-face)))

   :language 'swift
   :feature 'operator
   `([,@swift-ts-mode--operators] @font-lock-operator-face
     (ternary_expression "?" @font-lock-operator-face)
     (ternary_expression ":" @font-lock-operator-face))

   :language 'swift
   :feature 'variable
       `((property_declaration
          (value_binding_pattern)
          name: (pattern
                 bound_identifier: (simple_identifier) @font-lock-variable-name-face))
         (if_statement bound_identifier: (simple_identifier) @font-lock-variable-name-face)
         (guard_statement bound_identifier: (simple_identifier) @font-lock-variable-name-face)
         (simple_identifier) @font-lock-variable-use-face)

   :language 'swift
   :feature 'constant
   `((boolean_literal) @font-lock-constant-face)

   :language 'swift
   :feature 'number
   '([(integer_literal) (real_literal) (hex_literal) (oct_literal) (bin_literal)] @font-lock-number-face)
      
   ;; Putting 'bracket and 'delimiter last to that it doesn't override
   ;; cases like private(set) and \.keyPaths.
   :language 'swift
   :feature 'bracket
   `([,@swift-ts-mode--brackets] @font-lock-bracket-face)

   :language 'swift
   :feature 'delimiter
   '((["." ";" ":" ","]) @font-lock-delimiter-face))
  
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

(defun swift-ts-mode--parameter-name (node)
  "Return the parameter name of the given parameter NODE."
  (when (string-equal "parameter" (treesit-node-type node))
    (let ((parameter-name
           (treesit-node-text
            (or (treesit-node-child-by-field-name node "external_name")
                (treesit-node-child-by-field-name node "name")))))
      (if parameter-name
          (substring-no-properties parameter-name)
        parameter-name))))

(defun swift-ts-mode--function-name (node)
  "Return the name including parameters of the given NODE."
  (let ((name
         (treesit-node-text
          (treesit-node-child-by-field-name node "name") t))
        (parameter-names
         (remq nil (mapcar #'swift-ts-mode--parameter-name (treesit-node-children node)))))
    (if (null parameter-names)
        (concat name "()")
      (concat name "(" (mapconcat 'identity parameter-names ":") ":)"))))

(defun swift-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("init_declaration"
     (swift-ts-mode--function-name node))
    ("function_declaration"
     (swift-ts-mode--function-name node))
    ("class_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("protocol_declaration"
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))))

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
    (setq-local treesit-font-lock-feature-list
                '((comment definition)
                  (keyword string)
                  (constant number type function property)
                  (bracket delimiter error operator variable)))

    ;; Navigation.
    (setq-local treesit-defun-type-regexp
                (regexp-opt '("class_declaration"
                              "function_declaration"
                              "protocol_declaration")))
    (setq-local treesit-defun-name-function #'swift-ts-mode--defun-name)

    ;; Imenu.
    (setq-local treesit-simple-imenu-settings
                `(("init" "\\init_declaration\\'" nil nil)
                  ("func" "\\function_declaration\\'" nil nil)
                  ("enum" "\\class_declaration\\'" swift-ts-mode--enum-node-p nil)
                  ("class" "\\class_declaration\\'" swift-ts-mode--class-node-p nil)
                  ("struct" "\\class_declaration\\'" swift-ts-mode--struct-node-p nil)
                  ("protocol" "\\protocol_declaration\\'" swift-ts-mode--protocol-node-p nil)
                  ("actor" "\\class_declaration\\'" swift-ts-mode--actor-node-p nil)))

    ;; Indentation
    (setq-local indent-tabs-mode nil
                treesit-simple-indent-rules swift-ts-mode--indent-rules)

    (setq-local electric-indent-chars (append electric-indent-chars '(?.)))

    (treesit-major-mode-setup)))

(if (treesit-ready-p 'swift)
    (add-to-list 'auto-mode-alist '("\\.swift\\'" . swift-ts-mode)))

(provide 'swift-ts-mode)

;;; swift-ts-mode.el ends here
