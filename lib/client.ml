type package_request = { package_name : string; version : string }

let base_url = "https://docs-data.ocaml.org/live/p"

let get_status_url pkg_req =
  Printf.sprintf "%s/%s/%s/status.json" base_url pkg_req.package_name
    pkg_req.version

let get_index_url pkg_req =
  Printf.sprintf "%s/%s/%s/index.js" base_url pkg_req.package_name
    pkg_req.version

(* TODO: Switch to cohttp-eio  *)
let fetch_url url =
  let cmd = Printf.sprintf "curl -s \"%s\"" url in
  let ic = Unix.open_process_in cmd in
  let content = ref "" in
  try
    let buffer = Bytes.create 4096 in
    let rec read () =
      let n = input ic buffer 0 4096 in
      if n > 0 then (
        content := !content ^ Bytes.sub_string buffer 0 n;
        read ())
    in
    read ();
    ignore (Unix.close_process_in ic);
    !content
  with e ->
    ignore (Unix.close_process_in ic);
    raise e

let fetch_status ~env ~net pkg_req =
  let url = get_status_url pkg_req in
  try
    let body_str = fetch_url url in
    Ok (Yojson.Safe.from_string body_str |> Types.status_of_yojson)
  with exn -> Error (Printexc.to_string exn)

let fetch_package_info ~env ~net pkg_req =
  let url = get_index_url pkg_req in
  try
    let js_content = fetch_url url in
    let package_info =
      Types.
        {
          name = pkg_req.package_name;
          version = pkg_req.version;
          description = Some "Package documentation";
          modules =
            [
              {
                (* 
                TODO: Hack because package info is available as an index.js file.
                Because I don't want to parse this, I'll just return content. 
                *)
                name = "Raw";
                doc = Some js_content;
                path = url;
                type_declarations = [];
                values = [];
                submodules = [];
              };
            ];
        }
    in
    Ok (Ok package_info)
  with exn -> Error (Printexc.to_string exn)
