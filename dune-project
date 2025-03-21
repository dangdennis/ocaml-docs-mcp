(lang dune 3.17)

(name ocaml_mcp)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name ocaml_mcp)
 (synopsis "Model Context Protocol server for OCaml.org documentation")
 (description "A server and SDK for providing OCaml library documentation to Model Context Protocol clients")
 (depends 
  ocaml 
  ocamlformat 
  ocaml-lsp-server
  eio
  eio_main
  httpun
  httpun-eio
  yojson
  logs
  ppx_deriving_yojson)
 (tags
  ("documentation" "model-context-protocol" "language-server")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
