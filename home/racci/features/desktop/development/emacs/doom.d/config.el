;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-


(setq user-full-name "James Draycott"
      user-mail-address "me@racci.dev")

(setq auth-sources '("~/.")
      auth-source-cache-expiry nil)

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 16 :style 'regular)
      doom-big-font (font-spec :family "JetBrainsMono Nerd Font" :size 22 :style 'regular)
      doom-variable-pitch-font (font-spec :family "Roboto" :size 20 :style 'regular))

(setq doom-theme 'doom-vibrant)

(setq which-key-idle-delay 0) ;; i need the help, i really do


;; (use-package! copilot
;;   :hook (prog-mode . copilot-mode)
;;   :bind (("C-TAB" . 'copilot-accept-completion-by-word)
;;          ("C-<tab>" . 'copilot-accept-completion-by-word)
;;          ;; Clear the accept menu on alt key and escape
;;          ("M-]" . 'copilot-next-completion)
;;          ("M-[" . 'copilot-prev-completion)
;;          ("C-<escape>" . 'copilot-clear-overlay)
;;          ("C-SPC" . 'copilot-complete)
;;          :map company-active-map
;;          ("<tab>" . 'my-tab)
;;          ("TAB" . 'my-tab)
;;          :map company-mode-map
;;          ("<tab>" . 'my-tab)
;;          ("TAB" . 'my-tab)))

(after! lsp-ui
  (setq lsp-ui-sideline-show-diagnostics t
        lsp-ui-sideline-show-hover t
        lsp-ui-sideline-show-code-actions t
        lsp-ui-sideline-update-mode 'line
        lsp-ui-sideline-delay '0.1
        lsp-ui-doc-enable t
        lsp-ui-doc-delay '0.1))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

